import 'package:flutter/material.dart';
import '../features/caregiver/caregiver_home.dart';
import '../screens/welcome_screen.dart';
import '../features/parent/parent_home.dart';

class AppRoutes {
  static const String welcome = '/';
  static const String caregiverHome = '/caregiver-home';
  static const String parentHome = '/parent-home';

  static Map<String, WidgetBuilder> routes = {
    welcome: (context) => const WelcomeScreen(),
    caregiverHome: (context) => const CaregiverHome(),
    parentHome: (context) => const ParentHome(),
  };
}