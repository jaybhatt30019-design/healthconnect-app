// lib/core/services/report_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/models/health_passport_model.dart';
import 'package:healthconnect/models/medical_history_model.dart';

// ── Unified report model ──────────────────────────────
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

  // ✅ FIXED: replaced .name with _severityLabel()
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
      final dateStr = ill.diagnosedDate ?? '';
      final date = _parseLooseDate(dateStr) ?? DateTime(2000);
      events.add(TimelineEvent(
        date: date,
        type: TimelineEventType.illness,
        title: ill.name,
        subtitle: ill.isOngoing ? 'Ongoing' : 'Recovered',
        detail: _severityLabel(ill.severity),
        badge: _severityLabel(ill.severity),
      ));
    }

    for (final surg in history?.surgeries ?? []) {
      final date =
          _parseLooseDate(surg.date ?? '') ?? DateTime(2000);
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
        subtitle: '${med.dosage} · ${med.intake ?? ""}',
        detail:
            '${med.stockDisplay} remaining · ${med.duration ?? ""}',
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
      if (m != null && y != null) return DateTime(y, m);
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

enum TimelineEventType { appointment, illness, surgery, medicine }

// ── Report service ────────────────────────────────────
class ReportService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<String?> _getCaregiverId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc =
        await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    final role = data['role'] as String? ?? '';

    if (role == 'caregiver') return uid;
    if (role == 'parent') {
      final cid = data['caregiverId'] as String?;
      return (cid != null && cid.isNotEmpty) ? cid : uid;
    }
    return uid;
  }

  Future<MedicalReport?> generateReport() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return null;

    debugPrint('[ReportService] Loading all data in parallel...');

    final results = await Future.wait([
      _loadUserProfile(uid),
      _loadPassport(caregiverId),
      _loadHistory(caregiverId),
      _loadMedicines(caregiverId),
      _loadAppointments(caregiverId),
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

  Future<UserProfile> _loadUserProfile(String uid) async {
    final doc =
        await _firestore.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    return UserProfile(
      name: data['name'] ?? 'Unknown',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? '',
    );
  }

  Future<HealthPassport?> _loadPassport(
      String caregiverId) async {
    try {
      final doc = await _firestore
          .collection('health_passport')
          .doc(caregiverId)
          .get();
      if (!doc.exists) return null;
      return HealthPassport.fromFirestore(
          doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ReportService] Passport error: $e');
      return null;
    }
  }

  Future<MedicalHistory?> _loadHistory(
      String caregiverId) async {
    try {
      final doc = await _firestore
          .collection('medical_history')
          .doc(caregiverId)
          .get();
      if (!doc.exists) return null;
      return MedicalHistory.fromFirestore(
          doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ReportService] History error: $e');
      return null;
    }
  }

  Future<List<Medicine>> _loadMedicines(
      String caregiverId) async {
    try {
      final snap = await _firestore
          .collection('medicines')
          .where('caregiverId', isEqualTo: caregiverId)
          .get();
      return snap.docs
          .map((doc) => Medicine.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      debugPrint('[ReportService] Medicines error: $e');
      return [];
    }
  }

  // ✅ FIXED: removed orderBy to avoid index requirement
  // Sorts in memory after fetching — no Firestore index needed
  Future<List<Appointment>> _loadAppointments(
      String caregiverId) async {
    try {
      final snap = await _firestore
          .collection('appointments')
          .where('caregiverId', isEqualTo: caregiverId)
          .get();

      final appointments = snap.docs
          .map((doc) => Appointment.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Sort newest first in memory
      appointments.sort(
          (a, b) => b.dateTime.compareTo(a.dateTime));

      return appointments;
    } catch (e) {
      debugPrint('[ReportService] Appointments error: $e');
      return [];
    }
  }
}