// lib/features/auth/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthconnect/features/dashboard/main_dashboard.dart';
import 'package:healthconnect/screens/login_screen.dart';
import 'package:healthconnect/core/services/fcm_service.dart';
import 'package:healthconnect/core/services/notification_service.dart';
import 'package:healthconnect/core/services/location_service.dart';
import 'package:healthconnect/core/services/permission_helper.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkUser());
  }

  Future<void> _checkUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _go(const LoginScreen());
      return;
    }

    // ── Initialize all services on login ────────────

    // 1. Save FCM token so other device can reach us
    await FcmService().saveFcmToken();

    // 2. Initialize local notification service
    //    Creates channels, requests permissions
    await NotificationService().initialize();

    // 3. Request all permissions
    if (mounted) {
      await PermissionHelper.requestAll(context);
    }

    // 4. Get user role
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      _go(const LoginScreen());
      return;
    }

    final role = doc.data()?['role'] as String? ?? '';

    // 5. Parent: start location + schedule medicine reminders
    if (role == 'parent') {
      await LocationService().startTracking();
      await _scheduleMedicineReminders(user.uid, doc);
    }

    if (!mounted) return;
    _go(MainDashboard(isCaregiver: role == 'caregiver'));
  }

  // Schedule medicine reminders on every login
  // (handles app reinstall, phone restart etc.)
  Future<void> _scheduleMedicineReminders(
      String uid, DocumentSnapshot userDoc) async {
    try {
      final data = userDoc.data() as Map<String, dynamic>;
      final role = data['role'] as String? ?? '';
      String caregiverId = uid;

      if (role == 'parent') {
        final cid = data['caregiverId'] as String?;
        if (cid != null && cid.isNotEmpty) {
          caregiverId = cid;
        }
      }

      final medsSnap = await FirebaseFirestore.instance
          .collection('medicines')
          .where('caregiverId', isEqualTo: caregiverId)
          .get();

      for (final doc in medsSnap.docs) {
        final medData =
            doc.data() as Map<String, dynamic>;
        final name =
            medData['name'] as String? ?? '';
        final dosage =
            medData['dosage'] as String? ?? '';
        final times = (medData['times'] as List? ?? [])
            .map((t) {
              final parts =
                  (t as String).split(':');
              return TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            })
            .toList();

        if (name.isNotEmpty && times.isNotEmpty) {
          await NotificationService()
              .scheduleMedicineReminders(
            medicineId: doc.id,
            medicineName: name,
            dosage: dosage,
            times: times,
          );
        }
      }

      debugPrint(
          '[AuthGate] Scheduled reminders for '
          '${medsSnap.docs.length} medicines');
    } catch (e) {
      debugPrint(
          '[AuthGate] Error scheduling reminders: $e');
    }
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