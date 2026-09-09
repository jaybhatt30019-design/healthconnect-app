import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'Incoming Call Service',
    description: 'This channel is used for monitoring fastcall status.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'FastCall Active',
      initialNotificationContent: 'Monitoring incoming calls...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "Vitanex",
      content: "Call Monitoring Pipeline Running",
    );
  }

  // ── 1. Incoming call dispatched from FCM Background Handler ──
  service.on("incomingCall").listen((Map<String, dynamic>? event) async {
    if (event == null) return;

    // Bring the app to foreground so the CallKit UI is visible
    try {
      const intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: 'com.straventisglobal.vitanex',
        componentName: 'com.straventisglobal.vitanex.MainActivity',
        flags: [
          Flag.FLAG_ACTIVITY_NEW_TASK,
          Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
          Flag.FLAG_ACTIVITY_SINGLE_TOP,
        ],
      );
      await intent.launch();
    } catch (_) {}

    final String callId = event['callId'] ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final params = CallKitParams(
      id: callId,
      nameCaller: event['callerName'] ?? 'Emergency Call',
      handle: event['callerRole'] == 'child'
          ? '🚨 Child Emergency'
          : '🚨 Parent Emergency',
      type: 0,
      extra: <String, dynamic>{
        'agoraChannel': event['agoraChannel'] ?? '',
        'agoraToken': event['agoraToken'] ?? '',
        'callId': callId,
      },
    );

    // Show the real incoming call UI. Agora only joins if/when accepted.
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  });

  // ── 2. CallKit native listener — user tapped the incoming call banner ──
  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
    if (event == null) return;

    switch (event) {
      case CallEventActionCallAccept():
        final extra = event.callKitParams.extra ?? {};
        service.invoke("joinAgoraCall", {
          'agoraChannel': extra['agoraChannel'] ?? '',
          'agoraToken': extra['agoraToken'] ?? '',
          'callId': extra['callId'] ?? event.callKitParams.id ?? '',
        });
        break;
      default:
        break;
    }
  });
}