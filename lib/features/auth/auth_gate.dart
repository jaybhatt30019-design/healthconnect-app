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

    // 1. Save FCM token
    await FcmService().saveFcmToken();

    // 2. Initialize local notifications
    await NotificationService().initialize();

    // 3. Request permissions
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

    final role =
        doc.data()?['role'] as String? ?? '';

    // 5. Schedule medicine reminders on every login
    // Handles app reinstall, phone restart, new day
    await _scheduleMedicineReminders(user.uid, role);

    // 6. Parent: start location tracking
    if (role == 'parent') {
      await LocationService().startTracking();
    }

    if (!mounted) return;
    _go(MainDashboard(
        isCaregiver: role == 'caregiver'));
  }

  // ── Schedule reminders for all medicines ──────────
  // ✅ FIXED: queries by parentUid (new ownership model)
  // Parent  → parentUid = own uid
  // Caregiver → parentUid = linked parent's uid
  Future<void> _scheduleMedicineReminders(
      String uid, String role) async {
    try {
      String? parentUid;

      if (role == 'parent') {
        // Parent's own uid IS the parentUid
        parentUid = uid;
      } else if (role == 'caregiver') {
        // Caregiver → find linked parent's uid
        final parentSnap = await FirebaseFirestore
            .instance
            .collection('users')
            .where('caregiverId', isEqualTo: uid)
            .where('role', isEqualTo: 'parent')
            .limit(1)
            .get();

        if (parentSnap.docs.isNotEmpty) {
          parentUid = parentSnap.docs.first.id;
        }
      }

      if (parentUid == null) {
        debugPrint(
            '[AuthGate] No parentUid found — '
            'skipping medicine reminders');
        return;
      }

      // ✅ Query by parentUid — matches new data model
      final medsSnap = await FirebaseFirestore
          .instance
          .collection('medicines')
          .where('parentUid', isEqualTo: parentUid)
          .get();

      debugPrint(
          '[AuthGate] Found ${medsSnap.docs.length} '
          'medicines for parent=$parentUid');

      for (final doc in medsSnap.docs) {
        final data =
            doc.data() as Map<String, dynamic>;
        final name = data['name'] as String? ?? '';
        final dosage =
            data['dosage'] as String? ?? '';

        final times =
            (data['times'] as List? ?? []).map((t) {
          final parts = (t as String).split(':');
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }).toList();

        if (name.isNotEmpty && times.isNotEmpty) {
          await NotificationService()
              .scheduleMedicineReminders(
            medicineId: doc.id,
            medicineName: name,
            dosage: dosage,
            times: times,
          );
          debugPrint(
              '[AuthGate] Scheduled: $name '
              '(${times.length} slots)');
        }
      }
    } catch (e) {
      debugPrint(
          '[AuthGate] Schedule reminders error: $e');
    }
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
          child: CircularProgressIndicator()),
    );
  }
}