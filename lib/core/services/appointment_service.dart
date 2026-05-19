// lib/core/services/appointment_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthconnect/models/appointment_model.dart';
// ✅ ADD these two imports
import 'package:healthconnect/core/services/notification_service.dart';
import 'package:healthconnect/core/services/fcm_service.dart';

class AppointmentService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection('appointments');

  Future<String?> _getCaregiverId() async {
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

    if (role == 'caregiver') return uid;

    if (role == 'parent') {
      final caregiverId =
          data['caregiverId'] as String?;
      if (caregiverId != null &&
          caregiverId.isNotEmpty) {
        return caregiverId;
      }
      return uid;
    }

    return uid;
  }

  // ✅ NEW helper — gets current user's name for notifications
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
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    // ✅ Save to Firestore and capture the doc ref
    final docRef = await _ref.add({
      'caregiverId': caregiverId,
      'doctorName': appointment.doctorName,
      'hospitalName': appointment.hospitalName,
      'dateTime':
          appointment.dateTime.toIso8601String(),
      'reason': appointment.reason,
      'reminder': appointment.reminder,
      'notes': appointment.notes,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ✅ ADDED: Schedule local reminders on BOTH devices
    // (1 day before + 1 hour before)
    await NotificationService()
        .scheduleAppointmentReminders(
      appointmentId: docRef.id,
      doctorName: appointment.doctorName,
      hospitalName: appointment.hospitalName,
      appointmentTime: appointment.dateTime,
    );

    // ✅ ADDED: Notify other device via FCM
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

    // ✅ ADDED: Reschedule reminders with updated time
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

    // ✅ ADDED: Cancel reminders when appointment deleted
    await NotificationService()
        .cancelAppointmentReminders(id);
  }

  Stream<List<Appointment>> getAppointments() async* {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) {
      yield [];
      return;
    }

    yield* _ref
        .where('caregiverId',
            isEqualTo: caregiverId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id))
            .toList());
  }
}