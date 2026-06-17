// // lib/main.dart
// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'firebase_options.dart';
// import 'package:healthconnect/features/auth/auth_gate.dart';
// import 'package:healthconnect/core/services/notification_service.dart';
// import 'package:healthconnect/core/services/emergency_service.dart';
// import 'package:healthconnect/core/services/callkit_handler.dart';
// import 'package:healthconnect/core/services/sos_notification_service.dart';
// import 'package:healthconnect/core/services/agora_call_service.dart';
// import 'package:healthconnect/features/emergency/active_call_screen.dart';
// import 'package:healthconnect/models/emergency_call_model.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(
//     RemoteMessage message) async {
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//   debugPrint('[BGHandler] type=${message.data['type']}');
//   if (message.data['type'] == 'emergency_call') {
//     // ✅ Only show CallKit UI — do NOT initialize CallKitHandler
//     // here. Background isolate must not register a second listener.



//     print("helllllllllo");
//         await SosNotificationService()
//         .showIncomingCallUI(data: message.data);
//   }
// }

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   FirebaseMessaging.onBackgroundMessage(
//       _firebaseMessagingBackgroundHandler);

//   if (!kIsWeb) {
//     try {
//       await dotenv.load(fileName: '.env');
//     } catch (e) {
//       debugPrint('[main] .env not found: $e');
//     }
//   }

//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

//   FlutterError.onError =
//       FirebaseCrashlytics.instance.recordFlutterFatalError;
//   PlatformDispatcher.instance.onError = (error, stack) {
//     FirebaseCrashlytics.instance
//         .recordError(error, stack, fatal: true);
//     return true;
//   };

//   if (!kIsWeb) {
//     await NotificationService().initialize();
//     await SosNotificationService().initialize();
//     await EmergencyService().saveFcmToken();
//   }

//   runApp(const MyApp());
// }

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});
//   static final navigatorKey = GlobalKey<NavigatorState>();

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   @override
//   void initState() {
//     super.initState();

//     if (!kIsWeb) {
//       CallKitHandler.navigatorKey = MyApp.navigatorKey;
//       // ✅ initialize() only called ONCE here
//       // _initialized guard inside prevents double registration
//       CallKitHandler().initialize();

//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         _handleColdStart();
//       });

//       // ── Foreground FCM ─────────────────────────────
//       FirebaseMessaging.onMessage.listen((message) async {
//         final type = message.data['type'] ?? '';

//         if (type == 'emergency_call') {
//           // ✅ Only show CallKit if not already in a call
//           if (!AgoraCallService().isInCall) {
//             await SosNotificationService()
//                 .showIncomingCallUI(data: message.data);
//           }
//           return;
//         }

//         final title = message.notification?.title
//             ?? message.data['title'] ?? '';
//         final body = message.notification?.body
//             ?? message.data['body'] ?? '';

//         if (title.isNotEmpty) {
//           await NotificationService().showSystemNotification(
//             title: title,
//             body: body,
//             channelId: type == 'low_stock'
//                 ? 'health_alerts'
//                 : type == 'appointment_added'
//                     ? 'appointment_reminders'
//                     : 'medicine_reminders',
//           );
//         }
//       });

//       // ── Background notification tapped ─────────────
//       FirebaseMessaging.onMessageOpenedApp
//           .listen((message) async {
//         if (message.data['type'] != 'emergency_call') return;

//         // ✅ Already in call — just navigate to ActiveCallScreen
//         if (AgoraCallService().isInCall) {
//           EmergencyCall? activeCall;
//           try {
//             activeCall = await EmergencyService().getActiveCall();
//           } catch (_) {}
//           if (activeCall != null) {
//             final ctx = MyApp.navigatorKey.currentContext;
//             if (ctx != null && ctx.mounted) {
//               Navigator.of(ctx, rootNavigator: true)
//                   .pushAndRemoveUntil(
//                 MaterialPageRoute(
//                   builder: (_) => ActiveCallScreen(
//                     call: activeCall!,
//                     agoraService: AgoraCallService(),
//                     isIncoming: true,
//                     showFallbackButton: false,
//                     playArrivalSound: false,
//                   ),
//                 ),
//                 (route) => false,
//               );
//             }
//           }
//           return;
//         }

//         // ✅ BUG D FIX — was just a debugPrint. The CallKit auto-connect
//         // timer may have already expired by the time the user taps the
//         // banner (or never started for this message), so the call would
//         // never join. Drive the connect explicitly via cold-start logic,
//         // unless CallKitHandler is already handling this call.
//         if (!CallKitHandler.isHandlingCall) {
//           debugPrint('[main] onMessageOpenedApp — triggering connect');
//           await CallKitHandler().handleColdStartIfNeeded();
//         } else {
//           debugPrint('[main] onMessageOpenedApp — already handling');
//         }
//       });
//     }
//   }

//   Future<void> _handleColdStart() async {
//     if (kIsWeb) return;

//     // ✅ BUG B FIX — was a fixed 2s delay, which is too short on slow
//     // devices: AuthGate hadn't pushed MainDashboard yet, so the
//     // navigator context was null and cold-start navigation looped to
//     // nowhere. Poll for the navigator to actually be ready (up to ~10s),
//     // then proceed.
//     for (int i = 0; i < 20; i++) {
//       await Future.delayed(const Duration(milliseconds: 500));
//       if (MyApp.navigatorKey.currentContext != null) break;
//     }

//     // ✅ Check for active CallKit call — called ONCE only here
//     await CallKitHandler().handleColdStartIfNeeded();

//     // ✅ FCM initial message — only if CallKit didn't handle it
//     if (!CallKitHandler.isHandlingCall) {
//       try {
//         final initialMessage =
//             await FirebaseMessaging.instance.getInitialMessage();
//         if (initialMessage != null &&
//             initialMessage.data['type'] == 'emergency_call') {
//           debugPrint('[main] FCM cold start — showing CallKit');
//           await SosNotificationService()
//               .showIncomingCallUI(data: initialMessage.data);
//         }
//       } catch (e) {
//         debugPrint('[main] FCM initial message error: $e');
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       navigatorKey: MyApp.navigatorKey,
//       home: const AuthGate(),
//     );
//   }
// }



// // lib/main.dart
// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:healthconnect/core/services/background_service.dart';
// import 'package:healthconnect/features/emergency/auto_join_screen.dart';
// import 'firebase_options.dart';
// import 'package:healthconnect/features/auth/auth_gate.dart';
// import 'package:healthconnect/core/services/notification_service.dart';
// import 'package:healthconnect/core/services/emergency_service.dart';
// // import 'package:healthconnect/core/services/callkit_handler.dart';
// import 'package:healthconnect/core/services/sos_notification_service.dart';
// import 'package:healthconnect/core/services/agora_call_service.dart';
// import 'package:healthconnect/features/emergency/active_call_screen.dart';
// import 'package:healthconnect/models/emergency_call_model.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(
//     RemoteMessage message) async {

//       WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

//   await initializeBackgroundService();
//   debugPrint('[BGHandler] type=${message.data['type']}');
//   if (message.data['type'] == 'emergency_call') {
//     print("helllllllo");

//   FlutterBackgroundService()
//       .invoke(
//         "incomingCall",
//         message.data,
//       );
// }
// }

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   FirebaseMessaging.onBackgroundMessage(
//       _firebaseMessagingBackgroundHandler);

//   if (!kIsWeb) {
//     try {
//       await dotenv.load(fileName: '.env');
//     } catch (e) {
//       debugPrint('[main] .env not found: $e');
//     }
//   }

//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

//   FlutterError.onError =
//       FirebaseCrashlytics.instance.recordFlutterFatalError;
//   PlatformDispatcher.instance.onError = (error, stack) {
//     FirebaseCrashlytics.instance
//         .recordError(error, stack, fatal: true);
//     return true;
//   };

//   if (!kIsWeb) {
//     await NotificationService().initialize();
//     await SosNotificationService().initialize();
//     await EmergencyService().saveFcmToken();
//   }

//   runApp(const MyApp());
// }

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});
//   static final navigatorKey = GlobalKey<NavigatorState>();

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   @override
//   void initState() {
//     super.initState();


//     FlutterBackgroundService()
//     .on("joinAgoraCall")
//     .listen((event) {

//   final navigator =
//       MyApp.navigatorKey.currentState;

//   if (navigator == null) return;

//   navigator.push(
//     MaterialPageRoute(
//       builder: (_) => AutoJoinScreen(
//   channel: event?['channel'] ?? '',
//   token: event?['token'] ?? '',
//   callId: event?['callId'] ?? '',
// ),
//     ),
//   );
// });

//     if (!kIsWeb) {
//       // CallKitHandler.navigatorKey = MyApp.navigatorKey;
//       // // ✅ initialize() only called ONCE here
//       // // _initialized guard inside prevents double registration
//       // CallKitHandler().initialize();

//       // WidgetsBinding.instance.addPostFrameCallback((_) {
//       //   // _handleColdStart();
//       // });

//       // ── Foreground FCM ─────────────────────────────
//       // FirebaseMessaging.onMessage.listen((message) async {
//       //   final type = message.data['type'] ?? '';

//       //   if (type == 'emergency_call') {
//       //     // ✅ Only show CallKit if not already in a call
//       //     if (!AgoraCallService().isInCall) {
//       //       await SosNotificationService()
//       //           .showIncomingCallUI(data: message.data);
//       //     }
//       //     return;
//       //   }

//       //   final title = message.notification?.title
//       //       ?? message.data['title'] ?? '';
//       //   final body = message.notification?.body
//       //       ?? message.data['body'] ?? '';

//       //   if (title.isNotEmpty) {
//       //     await NotificationService().showSystemNotification(
//       //       title: title,
//       //       body: body,
//       //       channelId: type == 'low_stock'
//       //           ? 'health_alerts'
//       //           : type == 'appointment_added'
//       //               ? 'appointment_reminders'
//       //               : 'medicine_reminders',
//       //     );
//       //   }
//       // });



// FirebaseMessaging.onMessage.listen((message) async {

//   if (message.data['type'] != 'emergency_call') {
//      final title = message.notification?.title
//             ?? message.data['title'] ?? '';
//         final body = message.notification?.body
//             ?? message.data['body'] ?? '';

//         if (title.isNotEmpty) {
//           await NotificationService().showSystemNotification(
//             title: title,
//             body: body,
//             channelId: 'emergency_call' == 'low_stock'
//                 ? 'health_alerts'
//                 : 'emergency_call' == 'appointment_added'
//                     ? 'appointment_reminders'
//                     : 'medicine_reminders',
//           );
//         }
//     return;
//   }

//   FlutterBackgroundService()
//       .invoke(
//         "incomingCall",
//         message.data,
//       );

      
// });
//       // ── Background notification tapped ─────────────
//       FirebaseMessaging.onMessageOpenedApp
//           .listen((message) async {
//         if (message.data['type'] != 'emergency_call') return;

//         // ✅ Already in call — just navigate to ActiveCallScreen
//         if (AgoraCallService().isInCall) {
//           EmergencyCall? activeCall;
//           try {
//             activeCall = await EmergencyService().getActiveCall();
//           } catch (_) {}
//           if (activeCall != null) {
//             final ctx = MyApp.navigatorKey.currentContext;
//             if (ctx != null && ctx.mounted) {
//               Navigator.of(ctx, rootNavigator: true)
//                   .pushAndRemoveUntil(
//                 MaterialPageRoute(
//                   builder: (_) => ActiveCallScreen(
//                     call: activeCall!,
//                     agoraService: AgoraCallService(),
//                     isIncoming: true,
//                     showFallbackButton: false,
//                     playArrivalSound: false,
//                   ),
//                 ),
//                 (route) => false,
//               );
//             }
//           }
//           return;
//         }

//         // ✅ BUG D FIX — was just a debugPrint. The CallKit auto-connect
//         // timer may have already expired by the time the user taps the
//         // banner (or never started for this message), so the call would
//         // never join. Drive the connect explicitly via cold-start logic,
//         // unless CallKitHandler is already handling this call.
//         // if (!CallKitHandler.isHandlingCall) {
//         //   debugPrint('[main] onMessageOpenedApp — triggering connect');
//         //   await CallKitHandler().handleColdStartIfNeeded();
//         // } else {
//         //   debugPrint('[main] onMessageOpenedApp — already handling');
//         // }
//       });
//     }
//   }

//   // Future<void> _handleColdStart() async {
//   //   if (kIsWeb) return;

//   //   // ✅ BUG B FIX — was a fixed 2s delay, which is too short on slow
//   //   // devices: AuthGate hadn't pushed MainDashboard yet, so the
//   //   // navigator context was null and cold-start navigation looped to
//   //   // nowhere. Poll for the navigator to actually be ready (up to ~10s),
//   //   // then proceed.
//   //   for (int i = 0; i < 20; i++) {
//   //     await Future.delayed(const Duration(milliseconds: 500));
//   //     if (MyApp.navigatorKey.currentContext != null) break;
//   //   }

//   //   // ✅ Check for active CallKit call — called ONCE only here
//   //   await CallKitHandler().handleColdStartIfNeeded();

//   //   // ✅ FCM initial message — only if CallKit didn't handle it
//   //   if (!CallKitHandler.isHandlingCall) {
//   //     try {
//   //       final initialMessage =
//   //           await FirebaseMessaging.instance.getInitialMessage();
//   //       if (initialMessage != null &&
//   //           initialMessage.data['type'] == 'emergency_call') {
//   //         debugPrint('[main] FCM cold start — showing CallKit');
//   //         await SosNotificationService()
//   //             .showIncomingCallUI(data: initialMessage.data);
//   //       }
//   //     } catch (e) {
//   //       debugPrint('[main] FCM initial message error: $e');
//   //     }
//   //   }
//   // }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       navigatorKey: MyApp.navigatorKey,
//       home: const AuthGate(),
//     );
//   }
// }















// lib/main.dart
import 'dart:async';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:healthconnect/core/services/background_service.dart';
import 'package:healthconnect/features/emergency/auto_join_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'package:healthconnect/features/auth/auth_gate.dart';
import 'package:healthconnect/core/services/notification_service.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/callkit_handler.dart';
import 'package:healthconnect/core/services/sos_notification_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/features/emergency/active_call_screen.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {

      WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('[BGHandler] type=${message.data['type']}');
  if (message.data['type'] == 'emergency_call') {
    print("helllllllo");

  // FlutterBackgroundService()
  //     .invoke(
  //       "incomingCall",
  //       message.data,
//   //     );

//   final intent = AndroidIntent(
//       action: 'android.intent.action.MAIN',
//       category: 'android.intent.category.LAUNCHER',
//       package: 'com.healthconnect.app',
//       componentName: 'com.healthconnect.app.MainActivity',
//       flags: [
//         Flag.FLAG_ACTIVITY_NEW_TASK,
//         Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
//         Flag.FLAG_ACTIVITY_SINGLE_TOP,
//       ],
//     );
//     await intent.launch();

//     final navigator =
//       MyApp.navigatorKey.currentState;

//   if (navigator == null) return;

// // print(event?['agoraChannel']);
//   navigator.push(
//     MaterialPageRoute(
//       builder: (_) => AutoJoinScreen(
//   channel:  message.data?['agoraChannel'] ?? '',
//   token:  message.data?['agoraToken'] ?? '',
//   callId:  message.data?['callId'] ?? '',
// ),
//     ),
//   );

await initializeBackgroundService();

    // Dispatches the background intent payload forward
    // FlutterBackgroundService().invoke("incomingCall", message.data);
await SosNotificationService()
        .showIncomingCallUI(data: message.data);

  //        FlutterBackgroundService().invoke(
  //   "joinAgoraCall",
  //   {
  //     'agoraChannel': message.data['agoraChannel'],
  //     'agoraToken': message.data['agoraToken'],
  //     'callId': message.data['callId'],
  //   },
  // );

   try {
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
    } catch (e) {
      debugPrint('[Background Service] Force UI foreground intent launch failed: $e');
    }
  FlutterBackgroundService().invoke(
      "incomingCall",
      message.data,
    );
      return;
}

  final title =
      message.notification?.title ??
      message.data['title'] ??
      'HealthConnect';

  final body =
      message.notification?.body ??
      message.data['body'] ??
      '';

  await NotificationService().showSystemNotification(
    title: title,
    body: body,
    channelId: 'general_notifications',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

await initializeBackgroundService();
if(! await Permission.ignoreBatteryOptimizations.isGranted){
await Permission.ignoreBatteryOptimizations.request();
}
if(! await Permission.systemAlertWindow.isGranted){
await Permission.systemAlertWindow.request();
}



  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('[main] .env not found: $e');
    }
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError =
      FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance
        .recordError(error, stack, fatal: true);
    return true;
  };

  if (!kIsWeb) {
    await NotificationService().initialize();
    await SosNotificationService().initialize();
    await EmergencyService().saveFcmToken();
  }


final service = FlutterBackgroundService();

bool isRunning = await service.isRunning();

if (!isRunning) {
  service.startService();
}
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();


    FlutterBackgroundService()
    .on("joinAgoraCall")
    .listen((event) {

  final navigator =
      MyApp.navigatorKey.currentState;

  if (navigator == null) return;

// print(event?['agoraChannel']);
  navigator.push(
    MaterialPageRoute(
      builder: (_) => AutoJoinScreen(
  channel: event?['agoraChannel'] ?? '',
  token: event?['agoraToken'] ?? '',
  callId: event?['callId'] ?? '',
),
    ),
  );
});

    if (!kIsWeb) {



FlutterCallkitIncoming.onEvent.listen((event) async {

  switch (event?.event) {

    case Event.actionCallAccept:

      final extra =
          Map<String, dynamic>.from(
            event?.body['extra'] ?? {},
          );

      MyApp.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AutoJoinScreen(
            channel: extra['agoraChannel'],
            token: extra['agoraToken'],
            callId: extra['callId'],
          ),
        ),
      );

      break;


  //   case Event.actionCallIncoming:
  //   Future.delayed(
  //   const Duration(seconds: 1),
  //   () async {

  //      await FlutterCallkitIncoming.endCall(
  //       event!.body['id'],
  //     );

  //   },
  // );
  // break;
    case Event.actionCallDecline:
      break;

    case Event.actionCallEnded:
      break;
      default:
      break;
  }
});

      // CallKitHandler.navigatorKey = MyApp.navigatorKey;
      // // ✅ initialize() only called ONCE here
      // // _initialized guard inside prevents double registration
      // CallKitHandler().initialize();

      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   // _handleColdStart();
      // });

      // ── Foreground FCM ─────────────────────────────
      // FirebaseMessaging.onMessage.listen((message) async {
      //   final type = message.data['type'] ?? '';

      //   if (type == 'emergency_call') {
      //     // ✅ Only show CallKit if not already in a call
      //     if (!AgoraCallService().isInCall) {
      //       await SosNotificationService()
      //           .showIncomingCallUI(data: message.data);
      //     }
      //     return;
      //   }

      //   final title = message.notification?.title
      //       ?? message.data['title'] ?? '';
      //   final body = message.notification?.body
      //       ?? message.data['body'] ?? '';

      //   if (title.isNotEmpty) {
      //     await NotificationService().showSystemNotification(
      //       title: title,
      //       body: body,
      //       channelId: type == 'low_stock'
      //           ? 'health_alerts'
      //           : type == 'appointment_added'
      //               ? 'appointment_reminders'
      //               : 'medicine_reminders',
      //     );
      //   }
      // });



// FirebaseMessaging.onMessage.listen((message) async {

//   if (message.data['type'] != 'emergency_call') {
//      final title = message.notification?.title
//             ?? message.data['title'] ?? '';
//         final body = message.notification?.body
//             ?? message.data['body'] ?? '';

//         if (title.isNotEmpty) {
//           await NotificationService().showSystemNotification(
//             title: title,
//             body: body,
//             channelId: 'emergency_call' == 'low_stock'
//                 ? 'health_alerts'
//                 : 'emergency_call' == 'appointment_added'
//                     ? 'appointment_reminders'
//                     : 'medicine_reminders',
//           );
//         }
//     return;
//   }

//   FlutterBackgroundService()
//       .invoke(
//         "incomingCall",
//         message.data,
//       );

      
// });

FirebaseMessaging.onMessage.listen((message) async {
  final data = message.data;
  final type = data['type'] ?? '';

  debugPrint('[FCM] Foreground message type=$type');

  // ─────────────────────────────────────────────
  // Emergency Call
  // ─────────────────────────────────────────────
  if (type == 'emergency_call') {
    FlutterBackgroundService().invoke(
      "incomingCall",
      data,
    );
    return;
  }

  // ─────────────────────────────────────────────
  // Normal Notifications
  // ─────────────────────────────────────────────
  final title =
      message.notification?.title ??
      data['title'] ??
      'HealthConnect';

  final body =
      message.notification?.body ??
      data['body'] ??
      '';

  String channelId;

  switch (type) {
    case 'low_stock':
      channelId = 'health_alerts';
      break;

    case 'appointment_added':
    case 'appointment_reminder':
      channelId = 'appointment_reminders';
      break;

    case 'medicine_reminder':
      channelId = 'medicine_reminders';
      break;

    default:
      channelId = 'general_notifications';
  }

  await NotificationService().showSystemNotification(
    title: title,
    body: body,
    channelId: channelId,
  );
});
      // ── Background notification tapped ─────────────
      FirebaseMessaging.onMessageOpenedApp
          .listen((message) async {
        if (message.data['type'] != 'emergency_call') return;

        // ✅ Already in call — just navigate to ActiveCallScreen
        if (AgoraCallService().isInCall) {
          EmergencyCall? activeCall;
          try {
            activeCall = await EmergencyService().getActiveCall();
          } catch (_) {}
          if (activeCall != null) {
            final ctx = MyApp.navigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              Navigator.of(ctx, rootNavigator: true)
                  .pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => ActiveCallScreen(
                    call: activeCall!,
                    agoraService: AgoraCallService(),
                    isIncoming: true,
                    showFallbackButton: false,
                    playArrivalSound: false,
                  ),
                ),
                (route) => false,
              );
            }
          }
          return;
        }

        // ✅ BUG D FIX — was just a debugPrint. The CallKit auto-connect
        // timer may have already expired by the time the user taps the
        // banner (or never started for this message), so the call would
        // never join. Drive the connect explicitly via cold-start logic,
        // unless CallKitHandler is already handling this call.
        // if (!CallKitHandler.isHandlingCall) {
        //   debugPrint('[main] onMessageOpenedApp — triggering connect');
        //   await CallKitHandler().handleColdStartIfNeeded();
        // } else {
        //   debugPrint('[main] onMessageOpenedApp — already handling');
        // }
      });
    }
  }

  // Future<void> _handleColdStart() async {
  //   if (kIsWeb) return;

  //   // ✅ BUG B FIX — was a fixed 2s delay, which is too short on slow
  //   // devices: AuthGate hadn't pushed MainDashboard yet, so the
  //   // navigator context was null and cold-start navigation looped to
  //   // nowhere. Poll for the navigator to actually be ready (up to ~10s),
  //   // then proceed.
  //   for (int i = 0; i < 20; i++) {
  //     await Future.delayed(const Duration(milliseconds: 500));
  //     if (MyApp.navigatorKey.currentContext != null) break;
  //   }

  //   // ✅ Check for active CallKit call — called ONCE only here
  //   await CallKitHandler().handleColdStartIfNeeded();

  //   // ✅ FCM initial message — only if CallKit didn't handle it
  //   if (!CallKitHandler.isHandlingCall) {
  //     try {
  //       final initialMessage =
  //           await FirebaseMessaging.instance.getInitialMessage();
  //       if (initialMessage != null &&
  //           initialMessage.data['type'] == 'emergency_call') {
  //         debugPrint('[main] FCM cold start — showing CallKit');
  //         await SosNotificationService()
  //             .showIncomingCallUI(data: initialMessage.data);
  //       }
  //     } catch (e) {
  //       debugPrint('[main] FCM initial message error: $e');
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: MyApp.navigatorKey,
      home: const AuthGate(),
    );
  }
}