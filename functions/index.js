// functions/index.js
// Firebase Functions v2 syntax — fixes the "not a function" error

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

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
      console.log("FCM sent:", data.title, "→", data.token.slice(0, 20));
    } catch (e) {
      console.error("FCM send error:", e.message);
      await event.data.ref.update({
        sent: false,
        error: e.message,
      });
    }
  }
);