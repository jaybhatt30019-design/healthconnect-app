// functions/index.js

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// ── Existing: medicine/appointment notifications ───────
exports.sendFcmFromQueue = onDocumentCreated(
  "fcm_queue/{docId}",
  async (event) => {
    const data = event.data.data();
    if (!data || data.sent) return;

    try {
      await admin.messaging().send({
        token: data.token,
        notification: {
          title: data.title,
          body: data.body,
        },
        data: {
          type: data.type || "",
          ...(data.data || {}),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "health_alerts",
            priority: "high",
            defaultSound: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      });

      await event.data.ref.update({ sent: true });
      console.log(
        "FCM sent:",
        data.title,
        "→",
        data.token.slice(0, 20)
      );
    } catch (e) {
      console.error("FCM send error:", e.message);
      await event.data.ref.update({
        sent: false,
        error: e.message,
      });
    }
  }
);

// ── NEW: Emergency call notifications ─────────────────
// App writes to sos_queue → this function sends FCM v1
// Works even when receiver's app is fully killed
exports.sendEmergencyCall = onDocumentCreated(
  "sos_queue/{docId}",
  async (event) => {
    const data = event.data.data();
    if (!data || data.sent) return;

    const {
      toToken,
      callId,
      callerName,
      callerRole,
      agoraChannel,
      agoraToken,
    } = data;

    if (!toToken || !callId) {
      console.error("Missing toToken or callId in sos_queue");
      await event.data.ref.update({
        sent: false,
        error: "Missing toToken or callId",
      });
      return;
    }

    try {
      await admin.messaging().send({
        token: toToken,

        // ✅ High priority data message
        // Wakes device even when app is killed
        data: {
          type: "emergency_call",
          callId: callId,
          callerName: callerName || "Emergency",
          callerRole: callerRole || "unknown",
          agoraChannel: agoraChannel || "",
          agoraToken: agoraToken || "",
        },

        // Notification shown on lock screen
        notification: {
          title: "🚨 EMERGENCY CALL",
          body: `${callerName || "Someone"} needs help NOW`,
        },

        android: {
          // ✅ PRIORITY_HIGH wakes the device
          priority: "high",
          notification: {
            channelId: "emergency_channel",
            priority: "max",
            defaultSound: true,
            defaultVibrateTimings: true,
            visibility: "PUBLIC",
            // Show on lock screen even when phone is locked
            notificationPriority: "PRIORITY_MAX",
          },
        },

        apns: {
          headers: {
            // ✅ Highest priority for iOS
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
          payload: {
            aps: {
              alert: {
                title: "🚨 EMERGENCY CALL",
                body: `${callerName || "Someone"} needs help NOW`,
              },
              sound: "default",
              badge: 1,
              // ✅ Wakes app in background on iOS
              "content-available": 1,
            },
          },
        },
      });

      await event.data.ref.update({ sent: true });
      console.log(
        `Emergency FCM sent: ${callerName} → ${toToken.slice(0, 20)}...`
      );
    } catch (e) {
      console.error("Emergency FCM error:", e.message);
      await event.data.ref.update({
        sent: false,
        error: e.message,
      });
    }
  }
);