
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'dart:async';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:firebase_core/firebase_core.dart';
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
void onStart(ServiceInstance service) {

  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "HealthConnect",
      content: "Service Running",
    );
  }
  service.on("incomingCall").listen((event) async {

  //   const intent = AndroidIntent(
  //    action: 'android.intent.action.MAIN',
  // category: 'android.intent.category.LAUNCHER',
  // package: 'com.healthconnect.app',
  //     componentName:
  //         'com.healthconnect.MainActivity',
  //     flags: [
  //       Flag.FLAG_ACTIVITY_NEW_TASK,
  //       Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
  //       Flag.FLAG_ACTIVITY_SINGLE_TOP,
  //     ],
  //   );

const intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: 'com.healthconnect.app',
      componentName: 'com.healthconnect.app.MainActivity',
      flags: [
        Flag.FLAG_ACTIVITY_NEW_TASK, 
        Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
        Flag.FLAG_ACTIVITY_SINGLE_TOP 
      ],
    );
    await intent.launch();

    // await intent.launch();

    service.invoke(
      "joinAgoraCall",
      event,
    );
  });
}