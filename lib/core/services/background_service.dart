
// import 'dart:ui';

// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// import 'dart:async';
// import 'package:android_intent_plus/android_intent.dart';
// import 'package:android_intent_plus/flag.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:firebase_core/firebase_core.dart';
// Future<void> initializeBackgroundService() async {
//   final service = FlutterBackgroundService();

//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'my_foreground', 
//     'Incoming Call Service',
    
//     description: 'This channel is used for monitoring fastcall status.',
//     importance: Importance.low, 
//   );

//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();


//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(channel);

//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       autoStart: true,
//     autoStartOnBoot: true,
//     isForegroundMode: true,
      
//       notificationChannelId: 'my_foreground', 
//       initialNotificationTitle: 'FastCall Active',
//       initialNotificationContent: 'Monitoring incoming calls...',
//       foregroundServiceNotificationId: 888,
//     ),
//     iosConfiguration: IosConfiguration(
//       autoStart: true,
//       onForeground: onStart,
//     ),
//   );

//   service.startService();
// }

// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) {

//   DartPluginRegistrant.ensureInitialized();

//   if (service is AndroidServiceInstance) {
//     service.setForegroundNotificationInfo(
//       title: "HealthConnect",
//       content: "Service Running",
//     );
//   }
//   service.on("incomingCall").listen((event) async {

//   //   const intent = AndroidIntent(
//   //    action: 'android.intent.action.MAIN',
//   // category: 'android.intent.category.LAUNCHER',
//   // package: 'com.healthconnect.app',
//   //     componentName:
//   //         'com.healthconnect.MainActivity',
//   //     flags: [
//   //       Flag.FLAG_ACTIVITY_NEW_TASK,
//   //       Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
//   //       Flag.FLAG_ACTIVITY_SINGLE_TOP,
//   //     ],
//   //   );

// const intent = AndroidIntent(
//       action: 'android.intent.action.MAIN',
//       category: 'android.intent.category.LAUNCHER',
//       package: 'com.healthconnect.app',
//       componentName: 'com.healthconnect.app.MainActivity',
//       flags: [
//         Flag.FLAG_ACTIVITY_NEW_TASK, 
//         Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
//         Flag.FLAG_ACTIVITY_SINGLE_TOP 
//       ],
//     );
//     await intent.launch();

//     // await intent.launch();

//     service.invoke(
//       "joinAgoraCall",
//       event,
//     );
//   });
// }

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

// Notice: Ensure you import your default firebase configurations matching your app
// import 'package:Vitanex/firebase_options.dart';

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

  // If running inside background persistence engines on Android, wire persistent system elements
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "Vitanex",
      content: "Call Monitoring Pipeline Running",
    );
  }

  // ── 1. Listen for calls dispatched out of FCM Background Handler ──
  service.on("incomingCall").listen((Map<String, dynamic>? event) async {
    if (event == null) return;

  //  debugPrint('[Background Service] Processing incomingCall event payload.');

    // Fire the intent window instantly using the Draw Over Other Apps entitlement
    // This forces the main activity loop to jump directly to the screen view stack
    try {
      const intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: 'com.straventisglobal.vitanex',
        componentName: 'com.straventisglobal.vitanex',
        flags: [
          Flag.FLAG_ACTIVITY_NEW_TASK, 
          Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
          Flag.FLAG_ACTIVITY_SINGLE_TOP 
        ],
      );
      await intent.launch();
    } catch (e) {
     // debugPrint('[Background Service] Force UI foreground intent launch failed: $e');
    }

    // Set up a 1-second auto-answer fallback loop inside the background execution memory
    Timer(const Duration(seconds: 1), () async {
      final String callId = event['callId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      final params = CallKitParams(
        id: callId,
        nameCaller: event['callerName'] ?? 'Emergency Call',
        handle: event['callerRole'] == 'child' ? '🚨 Child Emergency' : '🚨 Parent Emergency',
        type: 0,
        extra: <String, dynamic>{
          'agoraChannel': event['agoraChannel'] ?? '',
          'agoraToken': event['agoraToken'] ?? '',
          'callId': callId,
        },
      );

      // Force-connect the system line state programmatically
      await FlutterCallkitIncoming.startCall(params);
await FlutterCallkitIncoming.endCall(callId);
      // Tell main.dart screen handlers to open AutoJoinScreen immediately
      service.invoke("joinAgoraCall", {
        'agoraChannel': event['agoraChannel'] ?? '',
        'agoraToken': event['agoraToken'] ?? '',
        'callId': callId,
      });
    });
  });

  // ── 2. CallKit Native Listener (Handles user tapping raw native banners) ──
  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
    if (event == null) return;

    if (event.event == Event.actionCallAccept) {
      final Map<String, dynamic> extra = Map<String, dynamic>.from(event.body['extra'] ?? {});
      
      service.invoke("joinAgoraCall", {
        'agoraChannel': extra['agoraChannel'] ?? '',
        'agoraToken': extra['agoraToken'] ?? '',
        'callId': event.body['id'] ?? '',
      });
    }
  });
}