import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:healthconnect/features/auth/auth_gate.dart';
import 'package:healthconnect/core/services/notification_service.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/callkit_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());

    WidgetsFlutterBinding.ensureInitialized();
 
  // 1. Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
 
  // 2. Notifications (FCM, local, emergency channel)
  await NotificationService().initialize();
 
  // 3. Save this device's FCM token to Firestore
  await EmergencyService().saveFcmToken();
 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
 
  // Navigator key — allows callkit_handler to push screens
  static final navigatorKey = GlobalKey<NavigatorState>();
 
  @override
  Widget build(BuildContext context) {
    // Wire navigator key and start listening to callkit events
    CallKitHandler.navigatorKey = MyApp.navigatorKey;
    CallKitHandler().initialize();
 
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: MyApp.navigatorKey,
      home: const AuthGate(),
    );
  }
}
