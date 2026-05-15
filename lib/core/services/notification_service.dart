// lib/core/services/notification_service.dart
// Fixed for flutter_callkit_incoming v2.5.8

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] == 'emergency_call') {
    await NotificationService()._showIncomingCallUI(data: message.data);
  }
}

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    await _createEmergencyChannel();

    FirebaseMessaging.onMessage.listen((msg) {
      if (msg.data['type'] == 'emergency_call') {
        _showIncomingCallUI(data: msg.data);
      }
    });
  }

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
      // ✅ textMissedCall & textCallback removed — not in v2.5.8
      extra: {
        'callId': callId,
        'agoraChannel': agoraChannel,
        'agoraToken': agoraToken,
      },
      android: const AndroidParams(
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
      ios: const IOSParams(
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

  Future<void> sendEmergencyNotification({
    required String toToken,
    required String callId,
    required String callerName,
    required String callerRole,
    required String agoraChannel,
    required String agoraToken,
  }) async {
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
          'android_channel_id': 'emergency_channel',
        },
      }),
    );
  }
}