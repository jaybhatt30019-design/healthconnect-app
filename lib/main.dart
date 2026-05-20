// lib/main.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'package:healthconnect/features/auth/auth_gate.dart';
import 'package:healthconnect/core/services/notification_service.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/callkit_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Load .env only on non-web platforms
  // Web doesn't support file assets the same way
  // and the Gemini scan feature only works on Android/iOS
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // .env missing — scan feature will show error
      // when user tries to use it, not on startup
      debugPrint('[main] .env not found: $e');
    }
  }

  // ✅ Single Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Notifications — only on mobile
  if (!kIsWeb) {
    await NotificationService().initialize();
    await EmergencyService().saveFcmToken();
  }

  // ✅ Single runApp
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Navigator key for callkit screen navigation
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Wire callkit only on mobile
    if (!kIsWeb) {
      CallKitHandler.navigatorKey = MyApp.navigatorKey;
      CallKitHandler().initialize();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: MyApp.navigatorKey,
      home: const AuthGate(),
    );
  }
}