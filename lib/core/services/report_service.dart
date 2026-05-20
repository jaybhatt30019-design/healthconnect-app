// lib/core/services/report_service.dart
// All queries use parentUid — data always accessible

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/models/health_passport_model.dart';
import 'package:healthconnect/models/medical_history_model.dart';

class MedicalReport {
  final UserProfile profile;
  final HealthPassport? passport;
  final MedicalHistory? history;
  final List<Medicine> medicines;
  final List<Appointment> appointments;
  final DateTime generatedAt;

  MedicalReport({
    required this.profile,
    required this.passport,
    required this.history,
    required this.medicines,
    required this.appointments,
    required this.generatedAt,
  });

  static String _severityLabel(Severity s) {
    switch (s) {
      case Severity.mild: return 'Mild';
      case Severity.moderate: return 'Moderate';
      case Severity.severe: return 'Severe';
    }
  }

  List<TimelineEvent> get timelineEvents {
    final events = <TimelineEvent>[];

    for (final appt in appointments) {
      events.add(TimelineEvent(
        date: appt.dateTime,
        type: TimelineEventType.appointment,
        title: appt.doctorName,
        subtitle: appt.hospitalName,
        detail: appt.reason,
      ));
    }

    for (final ill in history?.illnesses ?? []) {
      final date = _parseLooseDate(
              ill.diagnosedDate ?? '') ??
          DateTime(2000);
      events.add(TimelineEvent(
        date: date,
        type: TimelineEventType.illness,
        title: ill.name,
        subtitle:
            ill.isOngoing ? 'Ongoing' : 'Recovered',
        detail: _severityLabel(ill.severity),
        badge: _severityLabel(ill.severity),
      ));
    }

    for (final surg in history?.surgeries ?? []) {
      final date =
          _parseLooseDate(surg.date ?? '') ??
              DateTime(2000);
      events.add(TimelineEvent(
        date: date,
        type: TimelineEventType.surgery,
        title: surg.name,
        subtitle: surg.hospital ?? '',
        detail: surg.surgeon ?? '',
      ));
    }

    for (final med in medicines) {
      events.add(TimelineEvent(
        date: med.startDate ?? DateTime(2000),
        type: TimelineEventType.medicine,
        title: med.name,
        subtitle:
            '${med.dosage} · ${med.intake ?? ""}',
        detail: '${med.stockDisplay} remaining · '
            '${med.duration ?? ""}',
        badge: med.stockStatus == StockStatus.out
            ? 'Out'
            : med.stockStatus == StockStatus.low
                ? 'Low'
                : null,
      ));
    }

    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

  static DateTime? _parseLooseDate(String s) {
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final year = int.tryParse(s.trim());
    if (year != null) return DateTime(year);
    final months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
      'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
      'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final parts = s.trim().toLowerCase().split(' ');
    if (parts.length == 2) {
      final m = months[parts[0].length >= 3
          ? parts[0].substring(0, 3)
          : parts[0]];
      final y = int.tryParse(parts[1]);
      if (m != null && y != null) {
        return DateTime(y, m);
      }
    }
    return null;
  }
}

class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String role;

  UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });
}

class TimelineEvent {
  final DateTime date;
  final TimelineEventType type;
  final String title;
  final String subtitle;
  final String detail;
  final String? badge;

  TimelineEvent({
    required this.date,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.badge,
  });
}

enum TimelineEventType {
  appointment,
  illness,
  surgery,
  medicine
}

class ReportService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ── Get parent's uid ───────────────────────────────
  Future<String?> _getParentUid() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    final role = data['role'] as String? ?? '';

    if (role == 'parent') return uid;

    if (role == 'caregiver') {
      final parentSnap = await _firestore
          .collection('users')
          .where('caregiverId', isEqualTo: uid)
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();

      if (parentSnap.docs.isNotEmpty) {
        return parentSnap.docs.first.id;
      }
      return null;
    }

    return null;
  }

  Future<MedicalReport?> generateReport() async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return null;

    debugPrint(
        '[ReportService] Generating for '
        'parent=$parentUid');

    final results = await Future.wait([
      _loadParentProfile(parentUid),
      _loadPassport(parentUid),
      _loadHistory(parentUid),
      _loadMedicines(parentUid),
      _loadAppointments(parentUid),
    ]);

    return MedicalReport(
      profile: results[0] as UserProfile,
      passport: results[1] as HealthPassport?,
      history: results[2] as MedicalHistory?,
      medicines: results[3] as List<Medicine>,
      appointments: results[4] as List<Appointment>,
      generatedAt: DateTime.now(),
    );
  }

  // Load parent's profile by their uid
  Future<UserProfile> _loadParentProfile(
      String parentUid) async {
    try {
      // Check users collection first
      // (parent who signed up themselves)
      final userDoc = await _firestore
          .collection('users')
          .doc(parentUid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        return UserProfile(
          name: data['name'] as String? ?? 'Parent',
          email: data['email'] as String? ?? '',
          phone: data['phone'] as String? ?? '',
          role: 'parent',
        );
      }

      // Fallback: check parents collection
      // (parent added by caregiver via Add Parent screen)
      final parentSnap = await _firestore
          .collection('parents')
          .where('parentUid', isEqualTo: parentUid)
          .limit(1)
          .get();

      if (parentSnap.docs.isNotEmpty) {
        final data = parentSnap.docs.first.data();
        return UserProfile(
          name: data['name'] as String? ?? 'Parent',
          email: '',
          phone: data['phone'] as String? ?? '',
          role: 'parent',
        );
      }
    } catch (e) {
      debugPrint(
          '[ReportService] Parent profile: $e');
    }

    return UserProfile(
      name: 'Unknown',
      email: '',
      phone: '',
      role: 'parent',
    );
  }

  Future<HealthPassport?> _loadPassport(
      String parentUid) async {
    try {
      final doc = await _firestore
          .collection('health_passport')
          .doc(parentUid)
          .get();
      if (!doc.exists) return null;
      return HealthPassport.fromFirestore(
          doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ReportService] Passport: $e');
      return null;
    }
  }

  Future<MedicalHistory?> _loadHistory(
      String parentUid) async {
    try {
      final doc = await _firestore
          .collection('medical_history')
          .doc(parentUid)
          .get();
      if (!doc.exists) return null;
      return MedicalHistory.fromFirestore(
          doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ReportService] History: $e');
      return null;
    }
  }

  Future<List<Medicine>> _loadMedicines(
      String parentUid) async {
    try {
      final snap = await _firestore
          .collection('medicines')
          .where('parentUid', isEqualTo: parentUid)
          .get();
      return snap.docs
          .map((doc) => Medicine.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id))
          .toList();
    } catch (e) {
      debugPrint('[ReportService] Medicines: $e');
      return [];
    }
  }

  Future<List<Appointment>> _loadAppointments(
      String parentUid) async {
    try {
      final snap = await _firestore
          .collection('appointments')
          .where('parentUid', isEqualTo: parentUid)
          .get();

      final list = snap.docs
          .map((doc) => Appointment.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id))
          .toList();

      list.sort(
          (a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    } catch (e) {
      debugPrint(
          '[ReportService] Appointments: $e');
      return [];
    }
  }
}