// lib/main.dart
// ✅ Auto-connect flow — no Answer button needed
// FCM arrives → 5 second wait → join Agora → wake screen

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'package:healthconnect/features/auth/auth_gate.dart';
import 'package:healthconnect/core/services/notification_service.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/callkit_handler.dart';
import 'package:healthconnect/core/services/sos_notification_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// ── Background FCM handler ────────────────────────
// Runs in separate isolate when app is killed
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
      '[BGHandler] Message type: ${message.data['type']}');

  if (message.data['type'] == 'emergency_call') {
    // ✅ Show CallKit notification so user sees the call
    // CallKit will show for 5 seconds
    // Cold start handleColdStartIfNeeded will auto-join
    await SosNotificationService()
        .showIncomingCallUI(data: message.data);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

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

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      CallKitHandler.navigatorKey = MyApp.navigatorKey;
      CallKitHandler().initialize();

      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        _handleColdStart();
      });

      // FCM foreground — show CallKit UI
      // CallKitHandler 5s timer auto-connects
      FirebaseMessaging.onMessage.listen((message) {
        if (message.data['type'] ==
            'emergency_call') {
          SosNotificationService()
              .showIncomingCallUI(
                  data: message.data);
        }
      });

      // FCM background tap — show CallKit UI
      FirebaseMessaging.onMessageOpenedApp
          .listen((message) {
        if (message.data['type'] ==
            'emergency_call') {
          SosNotificationService()
              .showIncomingCallUI(
                  data: message.data);
        }
      });
    }
  }

  Future<void> _handleColdStart() async {
    if (kIsWeb) return;

    // ✅ Wait for AuthGate to finish
    await Future.delayed(
        const Duration(milliseconds: 500));

    // ✅ Check if there is an active call from CallKit
    // If yes → auto-join (no Answer button needed)
    await CallKitHandler().handleColdStartIfNeeded();

    // FCM cold start
    try {
      final initialMessage = await FirebaseMessaging
          .instance
          .getInitialMessage();
      if (initialMessage != null &&
          initialMessage.data['type'] ==
              'emergency_call') {
        debugPrint(
            '[main] FCM cold start');
        // ✅ Show CallKit → CallKitHandler will
        // auto-connect after 5s via actionCallIncoming
        await SosNotificationService()
            .showIncomingCallUI(
                data: initialMessage.data);
      }
    } catch (e) {
      debugPrint('[main] FCM initial message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: MyApp.navigatorKey,
      home: const AuthGate(),
    );
  }
}