/**
 * functions/index.js  (additions for calling)
 *
 * Add these three exports to your existing functions file. They fix:
 *   - DEFECT 1: real Agora RTC tokens (getAgoraToken)
 *   - iOS killed-state: VoIP push on the sos_queue trigger
 *   - the "stuck in accepted forever" gap: expireStaleCalls sweep
 *
 * Install deps inside functions/:
 *   npm i agora-token
 *
 * Set your Agora creds (don't hardcode in source for release):
 *   AGORA_APP_ID, AGORA_APP_CERTIFICATE as environment params/secrets.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
const Razorpay = require("razorpay");
const { RtcTokenBuilder, RtcRole } = require("agora-access-token");

// const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}
// admin.initializeApp() is presumably already called in your existing file.
// If not, uncomment:
// admin.initializeApp();


const AGORA_APP_CERTIFICATE_SECRET = defineSecret("AGORA_APP_CERTIFICATE");
const AGORA_APP_ID = "0e25036fcf0c4892a1b0c1b834a4ca31"; // not secret — public identifier, safe as-is
const TOKEN_TTL = 3600;

// ── 1. Real Agora token (called by AgoraConfig.getToken) ──────────────────
exports.getAgoraToken = onCall(
  { secrets: [AGORA_APP_CERTIFICATE_SECRET] },
  (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const channelName = request.data.channelName;
    const uid = Number(request.data.uid) || 0;
    if (!channelName) {
      throw new HttpsError("invalid-argument", "channelName required.");
    }
    const token = RtcTokenBuilder.buildTokenWithUid(
      AGORA_APP_ID,
      AGORA_APP_CERTIFICATE_SECRET.value(),
      channelName,
      uid,
      RtcRole.PUBLISHER,
      TOKEN_TTL,
      TOKEN_TTL
    );
    return { token, uid, channelName };
  }
);

// ── 2. sos_queue → wake-the-device push ───────────────────────────────────
// Your SosNotificationService writes to sos_queue. THIS sends the push.
// (If your existing function already does this, merge the apns VoIP block in.)
//
// For reliable iOS killed-state ringing you MUST:
//   - store the receiver's platform on their user doc (toPlatform)
//   - upload a VoIP cert/key to Firebase (Project Settings → Cloud Messaging)
//   - set apns-topic to "<yourBundleId>.voip"
exports.sendEmergencyCall = onDocumentCreated(
  "sos_queue/{docId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const d = snap.data();
    if (d.sent === true) return;
    if (!d.toToken) {
      await snap.ref.update({ sent: false, error: "missing token" });
      return;
    }

    const data = {
      type: "emergency_call",
      callId: String(d.callId || ""),
      callerName: String(d.callerName || "Vitanex"),
      callerRole: String(d.callerRole || "child"),
      agoraChannel: String(d.agoraChannel || ""),
      agoraToken: String(d.agoraToken || ""),
    };

    const isIos = String(d.toPlatform || "").toLowerCase() === "ios";

    const message = {
      token: d.toToken,
      data,
      android: { priority: "high" }, // REQUIRED to wake a killed Android app
      apns: isIos
        ? {
            headers: {
              "apns-push-type": "voip", // wakes a killed iOS app via PushKit
              "apns-priority": "10",
              "apns-topic": "com.straventisglobal.vitanex.voip", // ← your bundleId + .voip
            },
            payload: { aps: {}, ...data },
          }
        : undefined,
    };

    try {
      const id = await admin.messaging().send(message);
      await snap.ref.update({
        sent: true,
        messageId: id,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      await snap.ref.update({ sent: false, error: String(err) });
    }
  }
);

// ── 3. Missed-call sweep (calls stuck "accepted" with no answer) ──────────
exports.expireStaleCalls = onSchedule("every 1 minutes", async () => {
  const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 60 * 1000);
  const q = await admin
    .firestore()
    .collection("emergency_calls")
    .where("status", "==", "accepted")
    .where("answeredAt", "==", null)
    .where("createdAt", "<", cutoff)
    .get();
  const batch = admin.firestore().batch();
  q.forEach((doc) => batch.update(doc.ref, { status: "missed" }));
  if (!q.empty) await batch.commit();
});
// ═══════════════════════════════════════════════════════════════
// SUBSCRIPTION PAYMENTS
// ═══════════════════════════════════════════════════════════════

const RAZORPAY_KEY_ID = defineSecret("RAZORPAY_KEY_ID");
const RAZORPAY_KEY_SECRET = defineSecret("RAZORPAY_KEY_SECRET");

const EARLY_BIRD_LIMIT = 1000;
const EARLY_BIRD_BASE_PAISE = 19900; // ₹199
const REGULAR_BASE_PAISE = 29900;    // ₹299
const GST_RATE = 0.18;

async function getPaidSubscriberCount() {
  const snap = await admin.firestore()
    .collection("subscriptions")
    .where("isPremium", "==", true)
    .count()
    .get();
  return snap.data().count;
}

async function validateCoupon(code) {
  if (!code) return { discountType: null, discountValue: 0, durationDays: null };

  const ref = admin.firestore().collection("coupons").doc(code.trim().toUpperCase());
  const doc = await ref.get();

  if (!doc.exists) throw new HttpsError("not-found", "Invalid coupon code.");
  const data = doc.data();

  if (data.active === false) {
    throw new HttpsError("failed-precondition", "This coupon is no longer active.");
  }
  if (data.expiresAt && data.expiresAt.toDate() < new Date()) {
    throw new HttpsError("failed-precondition", "This coupon has expired.");
  }
  if (data.usageLimit != null && (data.usedCount || 0) >= data.usageLimit) {
    throw new HttpsError("resource-exhausted", "This coupon has reached its usage limit.");
  }

  return {
    discountType: data.discountType,
    discountValue: data.discountValue,
    durationDays: data.durationDays || null,
  };
}

function computeAmounts(basePaise, discountType, discountValue) {
  let discountedBase = basePaise;
  if (discountType === "percent") {
    discountedBase = Math.round(basePaise * (1 - discountValue / 100));
  } else if (discountType === "flat") {
    discountedBase = Math.max(0, basePaise - Math.round(discountValue * 100));
  }
  const gstPaise = discountedBase > 0 ? Math.round(discountedBase * GST_RATE) : 0;
  return { basePaise, discountedBase, gstPaise, totalPaise: discountedBase + gstPaise };
}

// ── 1. Create order: computes tier + coupon + GST, returns order + public key ──
exports.createSubscriptionOrder = onCall(
  { secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

    const couponCode = request.data?.couponCode || null;
    const subscriberCount = await getPaidSubscriberCount();
    const isEarlyBird = subscriberCount < EARLY_BIRD_LIMIT;
    const basePaise = isEarlyBird ? EARLY_BIRD_BASE_PAISE : REGULAR_BASE_PAISE;

    const coupon = await validateCoupon(couponCode);
    const amounts = computeAmounts(basePaise, coupon.discountType, coupon.discountValue);

    if (amounts.totalPaise <= 0) {
      return { isFree: true, isEarlyBird, ...amounts, durationDays: coupon.durationDays };
    }

    const razorpay = new Razorpay({
      key_id: RAZORPAY_KEY_ID.value(),
      key_secret: RAZORPAY_KEY_SECRET.value(),
    });

    const order = await razorpay.orders.create({
      amount: amounts.totalPaise,
      currency: "INR",
      notes: {
        uid: request.auth.uid,
        couponCode: couponCode || "",
        tier: isEarlyBird ? "early_bird_199" : "regular_299",
      },
    });

    return { isFree: false, orderId: order.id, keyId: RAZORPAY_KEY_ID.value(), isEarlyBird, ...amounts };
  }
);

// ── 2. Verify payment signature, redeem coupon, write subscription ──
exports.verifySubscriptionPayment = onCall(
  { secrets: [RAZORPAY_KEY_SECRET] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

    const { orderId, paymentId, signature, couponCode } = request.data || {};
    if (!orderId || !paymentId || !signature) {
      throw new HttpsError("invalid-argument", "Missing payment details.");
    }

    const expectedSignature = crypto
      .createHmac("sha256", RAZORPAY_KEY_SECRET.value())
      .update(`${orderId}|${paymentId}`)
      .digest("hex");

    if (expectedSignature !== signature) {
      throw new HttpsError("permission-denied", "Payment signature verification failed.");
    }

    const db = admin.firestore();
    const uid = request.auth.uid;
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) throw new HttpsError("not-found", "User not found.");

    const userData = userDoc.data();
    const role = userData.role || "parent";
    const targetParentId = role === "parent" ? uid : (userData.parentId || "");
    if (!targetParentId) throw new HttpsError("failed-precondition", "No linked parent account.");

    const now = admin.firestore.Timestamp.now();
    const validUntil = admin.firestore.Timestamp.fromMillis(now.toMillis() + 365 * 24 * 60 * 60 * 1000);

    await db.collection("subscriptions").doc(targetParentId).set({
      parentId: targetParentId,
      isPremium: true,
      activatedByUid: uid,
      activatedByRole: role,
      dateOfSubscriptionTaken: now,
      subscriptionType: "annual",
      validUntil,
      razorpayOrderId: orderId,
      razorpayPaymentId: paymentId,
      updatedAt: now,
    }, { merge: true });

    await db.collection("users").doc(uid).update({
      hasTakenSubscription: true,
      subscriptionExpiresAt: validUntil,
      dateOfSubscriptionTaken: now,
    });

    if (couponCode) {
      const couponRef = db.collection("coupons").doc(couponCode.trim().toUpperCase());
      await db.runTransaction(async (tx) => {
        const doc = await tx.get(couponRef);
        if (doc.exists) tx.update(couponRef, { usedCount: admin.firestore.FieldValue.increment(1) });
      });
    }

    return { success: true, validUntil: validUntil.toMillis() };
  }
);

// ── 3. Free (100%-off) coupon redemption — bypasses Razorpay entirely ──
exports.redeemFreeCoupon = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

  const couponCode = request.data?.couponCode;
  if (!couponCode) throw new HttpsError("invalid-argument", "Coupon code required.");

  const subscriberCount = await getPaidSubscriberCount();
  const isEarlyBird = subscriberCount < EARLY_BIRD_LIMIT;
  const basePaise = isEarlyBird ? EARLY_BIRD_BASE_PAISE : REGULAR_BASE_PAISE;

  const coupon = await validateCoupon(couponCode);
  const amounts = computeAmounts(basePaise, coupon.discountType, coupon.discountValue);

  if (amounts.totalPaise > 0) {
    throw new HttpsError("failed-precondition", "This coupon does not grant free access.");
  }

  const db = admin.firestore();
  const uid = request.auth.uid;
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) throw new HttpsError("not-found", "User not found.");

  const userData = userDoc.data();
  const role = userData.role || "parent";
  const targetParentId = role === "parent" ? uid : (userData.parentId || "");
  if (!targetParentId) throw new HttpsError("failed-precondition", "No linked parent account.");

  const durationDays = coupon.durationDays || 365;
  const now = admin.firestore.Timestamp.now();
  const validUntil = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + durationDays * 24 * 60 * 60 * 1000
  );

  await db.collection("subscriptions").doc(targetParentId).set({
    parentId: targetParentId,
    isPremium: true,
    activatedByUid: uid,
    activatedByRole: role,
    dateOfSubscriptionTaken: now,
    subscriptionType: durationDays === 365 ? "annual" : `promo_${durationDays}d`,
    validUntil,
    couponCode: couponCode.trim().toUpperCase(),
    updatedAt: now,
  }, { merge: true });

  await db.collection("users").doc(uid).update({
    hasTakenSubscription: true,
    subscriptionExpiresAt: validUntil,
    dateOfSubscriptionTaken: now,
  });

  const couponRef = db.collection("coupons").doc(couponCode.trim().toUpperCase());
  await db.runTransaction(async (tx) => {
    const doc = await tx.get(couponRef);
    if (doc.exists) tx.update(couponRef, { usedCount: admin.firestore.FieldValue.increment(1) });
  });

  return { success: true, validUntil: validUntil.toMillis() };
});

// ── 4. Daily sweep: flip expired subscriptions to inactive ──
exports.expireSubscriptions = onSchedule("every 24 hours", async () => {
  const now = admin.firestore.Timestamp.now();
  const db = admin.firestore();

  const snap = await db.collection("subscriptions")
    .where("isPremium", "==", true)
    .where("validUntil", "<", now)
    .get();

  const batch = db.batch();
  snap.forEach((doc) => {
    batch.update(doc.ref, { isPremium: false, expiredAt: now });
  });
  if (!snap.empty) await batch.commit();
});