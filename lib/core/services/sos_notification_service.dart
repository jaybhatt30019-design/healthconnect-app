// lib/core/services/sos_notification_service.dart
//
// Renamed from notification_service.dart to avoid any conflict.
// This handles FCM sending + flutter_callkit_incoming display.

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// ─── Background FCM handler (top-level, required by Firebase) ──────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] == 'emergency_call') {
    await SosNotificationService()
        ._showIncomingCallUI(data: message.data);
  }
}
// ────────────────────────────────────────────────────────────────────────────

class SosNotificationService {
  static final SosNotificationService _instance =
      SosNotificationService._internal();
  factory SosNotificationService() => _instance;
  SosNotificationService._internal();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  // ─────────────────────────────────────────────────────
  // Initialize — called from main.dart
  // ─────────────────────────────────────────────────────
  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
          android: androidInit, iOS: iosInit),
    );

    await _createEmergencyChannel();

    // Foreground FCM
    FirebaseMessaging.onMessage.listen((msg) {
      if (msg.data['type'] == 'emergency_call') {
        _showIncomingCallUI(data: msg.data);
      }
    });
  }

  // ─────────────────────────────────────────────────────
  // Android high-priority channel
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
  // Show incoming call UI via flutter_callkit_incoming
  // ─────────────────────────────────────────────────────
  Future<void> _showIncomingCallUI(
      {required Map<String, dynamic> data}) async {
    final callId = data['callId'] ?? '';
    final callerName = data['callerName'] ?? 'Emergency';
    final callerRole = data['callerRole'] ?? 'child';
    final agoraChannel = data['agoraChannel'] ?? '';
    final agoraToken = data['agoraToken'] ?? '';

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'HealthConnect',
      handle: callerRole == 'child'
          ? '🚨 Child Emergency'
          : '🚨 Parent Emergency',
      type: 0,
      duration: 45000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: {
        'callId': callId,
        'agoraChannel': agoraChannel,
        'agoraToken': agoraToken,
      },
      android: AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#B71C1C',
        actionColor: '#FFFFFF',
        textColor: '#FFFFFF',
        isShowFullLockedScreen: true,
        isImportant: true,
        isBot: false,
        isShowCallID: false,
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
  // Send FCM to another device
  // Replace serverKey with yours from Firebase Console →
  // Project Settings → Cloud Messaging → Server key
  // ─────────────────────────────────────────────────────
  Future<void> sendEmergencyNotification({
    required String toToken,
    required String callId,
    required String callerName,
    required String callerRole,
    required String agoraChannel,
    required String agoraToken,
  }) async {
    // ── PRODUCTION: use Cloud Function (Step 9) ──────────
    // await http.post(
    //   Uri.parse('https://us-central1-YOUR_PROJECT.cloudfunctions.net/sendEmergencyCall'),
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode({
    //     'toToken': toToken, 'callId': callId,
    //     'callerName': callerName, 'callerRole': callerRole,
    //     'agoraChannel': agoraChannel, 'agoraToken': agoraToken,
    //   }),
    // );

    // ── DEVELOPMENT: FCM Legacy HTTP API ─────────────────
    const serverKey = 'YOUR_FCM_SERVER_KEY'; // ← replace this

    final response = await http.post(
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

    debugPrint(
        '[SosNotificationService] FCM sent — status: ${response.statusCode}');
  }
}