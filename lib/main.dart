// lib/main.dart

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

// ✅ CRITICAL: Must be top-level function, not inside a class
// Must be registered BEFORE Firebase.initializeApp
// This runs in a separate isolate when app is killed
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  // Must init Firebase in background isolate
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError =
    FirebaseCrashlytics.instance.recordFlutterFatalError;

PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};

  debugPrint(
      '[BGHandler] Message type: ${message.data['type']}');

  if (message.data['type'] == 'emergency_call') {
    // Show native CallKit/incoming call UI
    // even when app is fully killed
    await SosNotificationService()
        .showIncomingCallUI(data: message.data);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Register background handler FIRST
  // Before Firebase.initializeApp
  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

  // Load .env
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('[main] .env not found: $e');
    }
  }

  // Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Services
  if (!kIsWeb) {
    await NotificationService().initialize();
    await SosNotificationService().initialize();
    await EmergencyService().saveFcmToken();
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

    if (!kIsWeb) {
      // Wire CallKit handler
      CallKitHandler.navigatorKey = MyApp.navigatorKey;
      CallKitHandler().initialize();

      // ✅ Handle cold start — app was killed
      // User tapped CallKit accept notification
      _handleColdStart();
    }
  }

  Future<void> _handleColdStart() async {
    // Check if app was launched from a CallKit action
    final callkitData =
        await CallKitHandler().getInitialCallData();
    if (callkitData != null) {
      debugPrint(
          '[main] Cold start with call: $callkitData');
      // CallKitHandler will handle joining the channel
      // after the navigator is ready
    }

    // Also handle FCM cold start
    // (app opened by tapping FCM notification)
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null &&
        initialMessage.data['type'] == 'emergency_call') {
      debugPrint(
          '[main] FCM cold start: ${initialMessage.data}');
      await SosNotificationService().showIncomingCallUI(
          data: initialMessage.data);
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