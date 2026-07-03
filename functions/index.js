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
const admin = require("firebase-admin");
const { RtcTokenBuilder, RtcRole } = require("agora-access-token");

// const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}
// admin.initializeApp() is presumably already called in your existing file.
// If not, uncomment:
// admin.initializeApp();

const AGORA_APP_ID = process.env.AGORA_APP_ID || "0e25036fcf0c4892a1b0c1b834a4ca31";
const AGORA_APP_CERTIFICATE =
  process.env.AGORA_APP_CERTIFICATE || "10f415a51e3641cdb7a2a57dc041188c";
const TOKEN_TTL = 3600;

// ── 1. Real Agora token (called by AgoraConfig.getToken) ──────────────────
exports.getAgoraToken = onCall((request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const channelName = request.data.channelName;
  const uid = Number(request.data.uid) || 0; // matches AgoraConfig.resolveUid
  if (!channelName) {
    throw new HttpsError("invalid-argument", "channelName required.");
  }
  const token = RtcTokenBuilder.buildTokenWithUid(
    AGORA_APP_ID,
    AGORA_APP_CERTIFICATE,
    channelName,
    uid,
    RtcRole.PUBLISHER,
    TOKEN_TTL,
    TOKEN_TTL
  );
  return { token, uid, channelName };
});

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