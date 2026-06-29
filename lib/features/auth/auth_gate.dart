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
      final prefs =
          await SharedPreferences.getInstance();
      final hasOpenedBefore =
          prefs.getBool('hasOpenedBefore') ?? false;

      if (!hasOpenedBefore) {
        await prefs.setBool('hasOpenedBefore', true);
        _go(const WelcomeScreen());
      } else {
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
    debugPrint('[AuthGate] This device role=$role uid=${user.uid}');

    await _scheduleMedicineReminders(user.uid, role);
    await _resetMedicinesIfNewDay(user.uid, role);

    if (role == 'parent') {
      await LocationService().startTracking();
    }

    if (!mounted) return;
    _go(MainDashboard(
        isCaregiver: role == 'caregiver'));
  }

  // ── Get parentUid ─────────────────────────────────
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
  // ✅ Only parent's phone should get local OS reminders
  // Caregiver gets notified via FCM (cross-device) only
  if (role != 'parent') {
    debugPrint('[AuthGate] Caregiver — skipping local reminders');
    return;
  }

  try {
    final parentUid =
        await _getParentUid(uid, role);

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
        final data = doc.data();
        final name =
            data['name'] as String? ?? '';
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

        // ✅ Parse endDate from Firestore
        // null means Ongoing — no end date
        DateTime? endDate;
        final endDateStr =
            data['endDate'] as String?;
        if (endDateStr != null &&
            endDateStr.isNotEmpty) {
          endDate = DateTime.tryParse(endDateStr);
        }

        if (name.isNotEmpty && times.isNotEmpty) {
  // ✅ Read takenStatus — skip slots already marked taken
  final takenStatus = List<bool>.from(
      data['takenStatus'] ?? List.filled(times.length, false));

  // ✅ If ALL slots taken today — cancel all and skip
  final allTaken = takenStatus.every((t) => t);
  if (allTaken) {
    await NotificationService().cancelMedicineReminders(
        doc.id, times.length);
    debugPrint('[AuthGate] All taken — cancelled reminders: $name');
    continue;
  }

  // ✅ Cancel already-taken slots individually
  for (int i = 0; i < takenStatus.length; i++) {
    if (i < takenStatus.length && takenStatus[i]) {
      await NotificationService().cancelSlotFollowUps(doc.id, i);
      // Also cancel the base notification for this slot
      await NotificationService().plugin.cancel(
        (doc.id.hashCode.abs() % 10000) + (i * 1000),
      );
      debugPrint('[AuthGate] Slot $i already taken — cancelled: $name');
    }
  }

  await NotificationService()
      .scheduleMedicineReminders(
    medicineId: doc.id,
    medicineName: name,
    dosage: dosage,
    times: times,
    endDate: endDate,
  );
          debugPrint(
              '[AuthGate] Scheduled: $name '
              '(${times.length} slots) '
              'endDate=${endDate?.toIso8601String() ?? 'Ongoing'}');
        }
      }
    } catch (e) {
      debugPrint(
          '[AuthGate] Schedule reminders error: $e');
    }
  }

  // ── Reset takenStatus if new day ──────────────────
  Future<void> _resetMedicinesIfNewDay(
      String uid, String role) async {
    try {
      final parentUid =
          await _getParentUid(uid, role);
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
        final data = doc.data();

        final lastReset =
            data['lastResetDate'] as String? ?? '';
        final lastResetDate =
            lastReset.length >= 10
                ? lastReset.substring(0, 10)
                : '';

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
        // debugPrint(
            // '[AuthGate] Reset $resetCount medicine(s) '
            // 'for new day ($todayStr)');
      } else {
        // debugPrint(
        //    '[AuthGate] All medicines already reset '
          //  'for today ($todayStr)');
      }
    } catch (e) {
      // debugPrint(
          // '[AuthGate] Daily reset error: $e');
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