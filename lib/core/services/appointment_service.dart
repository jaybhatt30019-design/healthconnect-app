import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthconnect/models/appointment_model.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _ref => _firestore.collection('appointments');

  // ─────────────────────────────────────────
  // Get caregiverId for whoever is logged in
  // Caregiver → their own uid
  // Parent    → caregiverId stored after pairing
  // ─────────────────────────────────────────
  Future<String?> _getCaregiverId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print('[ApptService] ERROR: No logged-in user');
      return null;
    }

    final userDoc = await _firestore.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      print('[ApptService] ERROR: No user doc for uid=$uid');
      return null;
    }

    final data = userDoc.data()!;
    final role = data['role'] as String? ?? '';

    print('[ApptService] uid=$uid  role=$role');

    if (role == 'caregiver') {
      print('[ApptService] caregiverId = $uid');
      return uid;
    }

    if (role == 'parent') {
      final cid = data['caregiverId'] as String?;
      print('[ApptService] parent caregiverId = $cid');
      if (cid == null) {
        print('[ApptService] WARNING: parent has no caregiverId — not paired yet');
      }
      return cid;
    }

    print('[ApptService] ERROR: unknown role "$role"');
    return null;
  }

  // ─────────────────────────────────────────
  // ADD
  // ─────────────────────────────────────────
  Future<String?> addAppointment(Appointment appointment) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) {
      print('[ApptService] addAppointment aborted — no caregiverId');
      return null;
    }

    final map = appointment.toMap(caregiverId);
    map['createdAt'] = FieldValue.serverTimestamp();

    print('[ApptService] Saving appointment: $map');

    final ref = await _ref.add(map);
    print('[ApptService] Saved! docId=${ref.id}');
    return ref.id;
  }

  // ─────────────────────────────────────────
  // UPDATE
  // ─────────────────────────────────────────
  Future<void> updateAppointment(Appointment appointment) async {
    print('[ApptService] Updating docId=${appointment.id}');

    final map = {
      'doctorName': appointment.doctorName,
      'hospitalName': appointment.hospitalName,
      'dateTime': appointment.dateTime.toIso8601String(),
      'reason': appointment.reason,
      'reminder': appointment.reminder,
      'notes': appointment.notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _ref.doc(appointment.id).update(map);
    print('[ApptService] Update done');
  }

  // ─────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────
  Future<void> deleteAppointment(String id) async {
    print('[ApptService] Deleting docId=$id');
    await _ref.doc(id).delete();
  }

  // ─────────────────────────────────────────
  // REALTIME STREAM (shared between parent & caregiver)
  // ─────────────────────────────────────────
  Stream<List<Appointment>> getAppointments() async* {
    final caregiverId = await _getCaregiverId();

    if (caregiverId == null) {
      print('[ApptService] getAppointments: no caregiverId → empty stream');
      yield [];
      return;
    }

    print('[ApptService] Listening to appointments for caregiverId=$caregiverId');

    yield* _ref
        .where('caregiverId', isEqualTo: caregiverId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) {
      print('[ApptService] Got ${snapshot.docs.length} appointments');
      return snapshot.docs
          .map((doc) => Appointment.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }
}