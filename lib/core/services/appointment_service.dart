// lib/core/services/appointment_service.dart
// Data ownership: parentUid is the permanent key

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/core/services/notification_service.dart';
import 'package:healthconnect/core/services/fcm_service.dart';

class AppointmentService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection('appointments');

  // ── Get parent's uid ───────────────────────────────
  // Parent  → own uid (permanent owner)
  // Caregiver → linked parent's uid
  Future<String?> _getParentUid() async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final userDoc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    if (!userDoc.exists) return null;

    final data = userDoc.data()!;
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

  Future<String> _getCurrentUserName() async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'User';
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?['name'] as String? ?? 'User';
  }

  Future<void> addAppointment(
      Appointment appointment) async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return;

    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    final docRef = await _ref.add({
      // ✅ parentUid is the owner key
      'parentUid': parentUid,
      'addedBy': uid,
      'doctorName': appointment.doctorName,
      'hospitalName': appointment.hospitalName,
      'dateTime':
          appointment.dateTime.toIso8601String(),
      'reason': appointment.reason,
      'reminder': appointment.reminder,
      'notes': appointment.notes,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await NotificationService()
        .scheduleAppointmentReminders(
      appointmentId: docRef.id,
      doctorName: appointment.doctorName,
      hospitalName: appointment.hospitalName,
      appointmentTime: appointment.dateTime,
    );

    final userName = await _getCurrentUserName();
    await FcmService().notifyAppointmentAdded(
      doctorName: appointment.doctorName,
      hospitalName: appointment.hospitalName,
      dateTime: appointment.dateTime,
      addedByName: userName,
    );
  }

  Future<void> updateAppointment(
      Appointment appointment) async {
    await _ref.doc(appointment.id).update({
      'doctorName': appointment.doctorName,
      'hospitalName': appointment.hospitalName,
      'dateTime':
          appointment.dateTime.toIso8601String(),
      'reason': appointment.reason,
      'reminder': appointment.reminder,
      'notes': appointment.notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await NotificationService()
        .cancelAppointmentReminders(appointment.id);
    await NotificationService()
        .scheduleAppointmentReminders(
      appointmentId: appointment.id,
      doctorName: appointment.doctorName,
      hospitalName: appointment.hospitalName,
      appointmentTime: appointment.dateTime,
    );
  }

  Future<void> deleteAppointment(String id) async {
    await _ref.doc(id).delete();
    await NotificationService()
        .cancelAppointmentReminders(id);
  }

  // ✅ Queries by parentUid — data always accessible
  Stream<List<Appointment>> getAppointments() async* {
    final parentUid = await _getParentUid();
    if (parentUid == null) {
      yield [];
      return;
    }

    yield* _ref
        .where('parentUid', isEqualTo: parentUid)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id))
            .toList());
  }
}