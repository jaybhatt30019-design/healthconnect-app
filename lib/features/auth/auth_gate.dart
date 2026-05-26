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
import 'package:healthconnect/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // ✅ Check if first time opening app
  final prefs = await SharedPreferences.getInstance();
  final hasOpenedBefore =
      prefs.getBool('hasOpenedBefore') ?? false;

  if (!hasOpenedBefore) {
    // First time — show welcome screen
    // Mark as opened so next time goes to login
    await prefs.setBool('hasOpenedBefore', true);
    _go(const WelcomeScreen());
  } else {
    // Returning user — go straight to login
    _go(const LoginScreen());
  }
  return;
}

    await FcmService().saveFcmToken();
    await NotificationService().initialize();

    if (mounted) {
      await PermissionHelper.requestAll(context);
    }

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

    await _scheduleMedicineReminders(user.uid, role);

    // ✅ Point 1 — Reset takenStatus every new day
    // Checks lastResetDate on each medicine
    // If it's a new day, resets all slots to false
    await _resetMedicinesIfNewDay(user.uid, role);

    if (role == 'parent') {
      await LocationService().startTracking();
    }

    if (!mounted) return;
    _go(MainDashboard(isCaregiver: role == 'caregiver'));
  }

  // ── Get parentUid for current user ───────────────
  Future<String?> _getParentUid(
      String uid, String role) async {
    if (role == 'parent') return uid;

    if (role == 'caregiver') {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('caregiverId', isEqualTo: uid)
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.first.id;
      }
    }
    return null;
  }

  // ── Schedule notifications ────────────────────────
  Future<void> _scheduleMedicineReminders(
      String uid, String role) async {
    try {
      final parentUid = await _getParentUid(uid, role);

      if (parentUid == null) {
        debugPrint(
            '[AuthGate] No parentUid — skipping reminders');
        return;
      }

      final medsSnap = await FirebaseFirestore.instance
          .collection('medicines')
          .where('parentUid', isEqualTo: parentUid)
          .get();

      debugPrint(
          '[AuthGate] Found ${medsSnap.docs.length} '
          'medicines for parent=$parentUid');

      for (final doc in medsSnap.docs) {
        final data =
            doc.data();
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

  // ── Point 1: Reset takenStatus if new day ─────────
  // Runs on every login/app open
  // Checks lastResetDate per medicine
  // If date is not today → resets takenStatus to false
  Future<void> _resetMedicinesIfNewDay(
      String uid, String role) async {
    try {
      final parentUid = await _getParentUid(uid, role);
      if (parentUid == null) return;

      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      final medsSnap = await FirebaseFirestore.instance
          .collection('medicines')
          .where('parentUid', isEqualTo: parentUid)
          .get();

      final batch =
          FirebaseFirestore.instance.batch();
      int resetCount = 0;

      for (final doc in medsSnap.docs) {
        final data =
            doc.data();

        // Get last reset date
        final lastReset =
            data['lastResetDate'] as String? ?? '';

        // Extract date part only (YYYY-MM-DD)
        final lastResetDate = lastReset.length >= 10
            ? lastReset.substring(0, 10)
            : '';

        // ✅ Reset if not yet reset today
        if (lastResetDate != todayStr) {
          final timesCount =
              (data['times'] as List? ?? []).length;
          final resetStatus =
              List.filled(timesCount, false);

          batch.update(doc.reference, {
            'takenStatus': resetStatus,
            'lastResetDate':
                today.toIso8601String(),
          });
          resetCount++;
        }
      }

      if (resetCount > 0) {
        await batch.commit();
        debugPrint(
            '[AuthGate] Reset $resetCount medicine(s) '
            'for new day ($todayStr)');
      } else {
        debugPrint(
            '[AuthGate] All medicines already reset '
            'for today ($todayStr)');
      }
    } catch (e) {
      debugPrint(
          '[AuthGate] Daily reset error: $e');
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