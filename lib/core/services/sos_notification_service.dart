// lib/core/services/sos_notification_service.dart
// ✅ Auto-connect flow — no Answer button
// CallKit shows incoming call UI for visual only
// App auto-joins Agora after 5 seconds regardless

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SosNotificationService {
  static final SosNotificationService _instance =
      SosNotificationService._internal();
  factory SosNotificationService() => _instance;
  SosNotificationService._internal();

  final _localNotifications =
      FlutterLocalNotificationsPlugin();
  final _firestore = FirebaseFirestore.instance;

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings(
        '@mipmap/ic_launcher');
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

  // ✅ Called from background FCM handler
  // Shows CallKit UI — but auto-connect happens
  // via _autoConnectAfterDelay in main.dart
  Future<void> showIncomingCallUI({
    required Map<String, dynamic> data,
  }) async {
    final callId = data['callId'] as String? ?? '';
    final callerName =
        data['callerName'] as String? ?? 'Emergency';
    final callerRole =
        data['callerRole'] as String? ?? 'child';
    final agoraChannel =
        data['agoraChannel'] as String? ?? '';
    final agoraToken =
        data['agoraToken'] as String? ?? '';

    // ✅ Show CallKit notification for visual alert
    // User sees the call on screen/lock screen
    // But auto-connect happens after 5 seconds
    // regardless of whether they tap anything
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'HealthConnect',
      handle: callerRole == 'child'
          ? '🚨 Child Emergency'
          : '🚨 Parent Emergency',
      type: 0,
      // ✅ Set duration to 5 seconds only
      // After this CallKit dismisses itself
      // and app has already auto-connected
      duration: 5000,
      textAccept: 'Answer',
      textDecline: 'Decline',
      extra: {
        'callId': callId,
        'agoraChannel': agoraChannel,
        'agoraToken': agoraToken,
        // ✅ Pass callerRole so cold start knows
        // whether to show fallback button or sound
        'callerRole': callerRole,
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

    await FlutterCallkitIncoming.showCallkitIncoming(
        params);
  }

  Future<void> sendEmergencyNotification({
    required String toToken,
    required String callId,
    required String callerName,
    required String callerRole,
    required String agoraChannel,
    required String agoraToken,
  }) async {
    try {
      await _firestore.collection('sos_queue').add({
        'toToken': toToken,
        'callId': callId,
        'callerName': callerName,
        'callerRole': callerRole,
        'agoraChannel': agoraChannel,
        'agoraToken': agoraToken,
        'sent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '[SosNotificationService] Written to '
          'sos_queue for callId=$callId');
    } catch (e) {
      debugPrint(
          '[SosNotificationService] sos_queue error: $e');
    }
  }
}