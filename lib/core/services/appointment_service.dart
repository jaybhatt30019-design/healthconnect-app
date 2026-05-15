// lib/core/services/appointment_service.dart
// All debug prints removed — clean production version

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthconnect/models/appointment_model.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _ref => _firestore.collection('appointments');

  Future<String?> _getCaregiverId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final userDoc =
        await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return null;

    final data = userDoc.data()!;
    final role = data['role'] as String? ?? '';

    if (role == 'caregiver') return uid;

    if (role == 'parent') {
      final caregiverId = data['caregiverId'] as String?;
      if (caregiverId != null && caregiverId.isNotEmpty) {
        return caregiverId;
      }
      // Parent not yet paired — use own uid so app still works
      return uid;
    }

    return uid;
  }

  Future<void> addAppointment(Appointment appointment) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    await _ref.add({
      'caregiverId': caregiverId,
      'doctorName': appointment.doctorName,
      'hospitalName': appointment.hospitalName,
      'dateTime': appointment.dateTime.toIso8601String(),
      'reason': appointment.reason,
      'reminder': appointment.reminder,
      'notes': appointment.notes,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAppointment(Appointment appointment) async {
    await _ref.doc(appointment.id).update({
      'doctorName': appointment.doctorName,
      'hospitalName': appointment.hospitalName,
      'dateTime': appointment.dateTime.toIso8601String(),
      'reason': appointment.reason,
      'reminder': appointment.reminder,
      'notes': appointment.notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAppointment(String id) async {
    await _ref.doc(id).delete();
  }

  Stream<List<Appointment>> getAppointments() async* {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) {
      yield [];
      return;
    }

    yield* _ref
        .where('caregiverId', isEqualTo: caregiverId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
}