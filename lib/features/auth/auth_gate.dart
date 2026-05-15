// lib/features/auth/auth_gate.dart
// Auto-starts location tracking when parent logs in
// No toggle needed — location is always shared

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthconnect/features/dashboard/main_dashboard.dart';
import 'package:healthconnect/screens/login_screen.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/permission_helper.dart';
import 'package:healthconnect/core/services/location_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUser());
  }

  Future<void> _checkUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _go(const LoginScreen());
      return;
    }

    // Save FCM token on every login
    await EmergencyService().saveFcmToken();

    // Request permissions
    if (mounted) await PermissionHelper.requestAll(context);

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      _go(const LoginScreen());
      return;
    }

    final role = doc.data()?['role'] as String? ?? '';

    // ✅ Auto-start location tracking for parent
    // No toggle — starts automatically, runs in background
    if (role == 'parent') {
      await LocationService().startTracking();
    }

    if (!mounted) return;
    _go(MainDashboard(isCaregiver: role == 'caregiver'));
  }

  void _go(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}