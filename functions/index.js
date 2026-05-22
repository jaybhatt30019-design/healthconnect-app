// functions/index.js

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// ── Medicine/appointment notifications ────────────────
exports.sendFcmFromQueue = onDocumentCreated(
  "fcm_queue/{docId}",
  async (event) => {
    const data = event.data.data();
    if (!data || data.sent) return;

    try {
      await admin.messaging().send({
        token: data.token,

        // ✅ notification block makes Android show it
        // on the phone panel automatically
        notification: {
          title: data.title,
          body: data.body,
        },

        data: {
          type: data.type || "",
          ...(data.data || {}),
        },

        android: {
          // ✅ HIGH priority wakes screen
          priority: "high",
          notification: {
            // ✅ Must match channel created in app
            channelId: "health_alerts",
            // ✅ MAX priority shows at top
            notificationPriority: "PRIORITY_HIGH",
            defaultSound: true,
            defaultVibrateTimings: true,
            // ✅ Show on lock screen
            visibility: "PUBLIC",
          },
        },

        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              alert: {
                title: data.title,
                body: data.body,
              },
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

// ── Emergency call notifications ──────────────────────
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
      console.error("Missing toToken or callId");
      await event.data.ref.update({
        sent: false,
        error: "Missing toToken or callId",
      });
      return;
    }

    try {
      await admin.messaging().send({
        token: toToken,

        data: {
          type: "emergency_call",
          callId: callId,
          callerName: callerName || "Emergency",
          callerRole: callerRole || "unknown",
          agoraChannel: agoraChannel || "",
          agoraToken: agoraToken || "",
        },

        notification: {
          title: "🚨 EMERGENCY CALL",
          body: `${callerName || "Someone"} needs help NOW`,
        },

        android: {
          priority: "high",
          notification: {
            channelId: "emergency_channel",
            notificationPriority: "PRIORITY_MAX",
            defaultSound: true,
            defaultVibrateTimings: true,
            visibility: "PUBLIC",
          },
        },

        apns: {
          headers: {
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