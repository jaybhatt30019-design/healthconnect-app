import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// ─── TOP-LEVEL: handles FCM when app is fully terminated ───────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  if (data['type'] == 'emergency_call') {
    await NotificationService()
        ._showIncomingCallUI(data: data, fromBackground: true);
  }
}
// ────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  // ─────────────────────────────────────────────────────
  // Initialize — call from main.dart BEFORE runApp()
  // ─────────────────────────────────────────────────────
  Future<void> initialize() async {
    // 1. FCM background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Request permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true, // iOS critical alerts bypass silent mode
    );

    // 3. Local notifications setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 4. Android notification channel for emergency
    await _createEmergencyChannel();

    // 5. Foreground FCM handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 6. App opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
  }

  // ─────────────────────────────────────────────────────
  // Create high-priority Android channel
  // ─────────────────────────────────────────────────────
  Future<void> _createEmergencyChannel() async {
    const channel = AndroidNotificationChannel(
      'emergency_channel',
      'Emergency Alerts',
      description: 'Critical emergency notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Colors.red,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ─────────────────────────────────────────────────────
  // Handle foreground FCM message
  // ─────────────────────────────────────────────────────
  void _handleForegroundMessage(RemoteMessage message) {
    if (message.data['type'] == 'emergency_call') {
      _showIncomingCallUI(data: message.data, fromBackground: false);
    }
  }

  void _handleNotificationOpen(RemoteMessage message) {
    // Navigation handled by the call screen listener
  }

  void _onNotificationTap(NotificationResponse response) {
    // The callkit handles accept/reject; local notification just opens app
  }

  // ─────────────────────────────────────────────────────
  // Show full-screen incoming call UI using flutter_callkit_incoming
  // ─────────────────────────────────────────────────────
  Future<void> _showIncomingCallUI({
    required Map<String, dynamic> data,
    required bool fromBackground,
  }) async {
    final callId = data['callId'] ?? '';
    final callerName = data['callerName'] ?? 'Emergency';
    final callerRole = data['callerRole'] ?? 'child';

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'HealthConnect',
      avatar: 'https://i.pravatar.cc/150?img=3',
      handle: callerRole == 'child' ? 'Child Emergency' : 'Parent Emergency',
      type: 0, // 0 = audio, 1 = video
      duration: 45000, // 45 second ring timeout
      textAccept: 'Accept',
      textDecline: 'Decline',
      textMissedCall: 'Missed Emergency Call',
      textCallback: 'Call Back',
      extra: {
        'callId': callId,
        'agoraChannel': data['agoraChannel'] ?? '',
        'agoraToken': data['agoraToken'] ?? '',
      },
      headers: {'apiKey': 'Abc@123!', 'platform': 'flutter'},
      android: AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#E53935', // emergency red
        backgroundUrl: '',
        actionColor: '#FFFFFF',
        textColor: '#FFFFFF',
        isShowFullLockedScreen: true,     // shows over lock screen
        isShowCallID: false,
        isImportant: true,
        isBot: false,
      ),
      ios: IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  // ─────────────────────────────────────────────────────
  // Send emergency FCM to another device
  // This requires your own backend/Cloud Function to call FCM v1 API.
  // Below shows the Cloud Function approach (recommended).
  // ─────────────────────────────────────────────────────
  Future<void> sendEmergencyNotification({
    required String toToken,
    required String callId,
    required String callerName,
    required String callerRole,
    required String agoraChannel,
    required String agoraToken,
  }) async {
    // ── Option A: Via your Firebase Cloud Function (PRODUCTION) ──
    // Uncomment and replace URL when Cloud Function is deployed:
    //
    // await http.post(
    //   Uri.parse('https://us-central1-YOUR_PROJECT.cloudfunctions.net/sendEmergencyCall'),
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode({
    //     'toToken': toToken,
    //     'callId': callId,
    //     'callerName': callerName,
    //     'callerRole': callerRole,
    //     'agoraChannel': agoraChannel,
    //     'agoraToken': agoraToken,
    //   }),
    // );

    // ── Option B: Direct FCM Legacy API (for development only) ──
    // Replace YOUR_SERVER_KEY from Firebase Console → Project Settings → Cloud Messaging
    const serverKey = 'BMi62-2vS-HM3QWyX9QefytaAept2Qr3WXap2jr4gpLDUcbgYVj8p1iLbNmpcqSGndr2lugDpTHCmRi_cqrLKGw';

    await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: jsonEncode({
        'to': toToken,
        'priority': 'high',
        'data': {
          'type': 'emergency_call',
          'callId': callId,
          'callerName': callerName,
          'callerRole': callerRole,
          'agoraChannel': agoraChannel,
          'agoraToken': agoraToken,
        },
        'notification': {
          'title': '🚨 EMERGENCY CALL',
          'body': '$callerName needs help NOW',
          'sound': 'default',
          'android_channel_id': 'emergency_channel',
        },
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': 'emergency_channel',
            'notification_priority': 'PRIORITY_MAX',
            'visibility': 'PUBLIC',
            'default_sound': true,
            'default_vibrate_timings': true,
          },
        },
        'apns': {
          'headers': {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          'payload': {
            'aps': {
              'alert': {
                'title': '🚨 EMERGENCY CALL',
                'body': '$callerName needs help NOW',
              },
              'sound': 'default',
              'badge': 1,
              'content-available': 1,
            },
          },
        },
      }),
    );

    debugPrint('[NotificationService] Emergency FCM sent to $toToken');
  }

  // ─────────────────────────────────────────────────────
  // Listen for callkit events (accept / reject)
  // ─────────────────────────────────────────────────────
  void listenCallKitEvents({
    required Function(Map<String, dynamic>) onAccept,
    required Function(Map<String, dynamic>) onDecline,
    required Function(Map<String, dynamic>) onEnded,
  }) {
    FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      switch (event.event) {
        case Event.actionCallAccept:
          onAccept(event.body as Map<String, dynamic>);
          break;
        case Event.actionCallDecline:
          onDecline(event.body as Map<String, dynamic>);
          break;
        case Event.actionCallEnded:
          onEnded(event.body as Map<String, dynamic>);
          break;
        default:
          break;
      }
    });
  }
}