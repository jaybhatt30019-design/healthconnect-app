// lib/core/services/health_passport_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:healthconnect/models/health_passport_model.dart';

class HealthPassportService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get _ref =>
      _firestore.collection('health_passport');

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

  // ── Realtime stream ───────────────────────────────
  Stream<HealthPassport?> passportStream() {
    return Stream.fromFuture(_getCaregiverId()).asyncExpand(
      (caregiverId) {
        if (caregiverId == null) return Stream.value(null);
        return _ref.doc(caregiverId).snapshots().map((snap) {
          if (!snap.exists) {
            return HealthPassport.empty(caregiverId);
          }
          return HealthPassport.fromFirestore(
              snap.data() as Map<String, dynamic>);
        });
      },
    );
  }

  // ── One-time load — used by edit screen ───────────
  // ✅ NEW: edit screen calls this to pre-fill all fields
  Future<HealthPassport?> loadPassport() async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return null;

    final doc = await _ref.doc(caregiverId).get();
    if (!doc.exists) return HealthPassport.empty(caregiverId);

    return HealthPassport.fromFirestore(
        doc.data() as Map<String, dynamic>);
  }

  // ── Save full passport ────────────────────────────
  Future<void> savePassport(HealthPassport passport) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    final map = passport.toMap();
    map['updatedAt'] = FieldValue.serverTimestamp();
    map['updatedBy'] = _auth.currentUser?.uid;

    // ✅ merge: true — only overwrites fields we send
    // Fields not in toMap() are never touched
    await _ref.doc(caregiverId).set(map, SetOptions(merge: true));
    debugPrint('[HealthPassport] Saved for caregiverId=$caregiverId');
  }

  // ── Save only readings ────────────────────────────
  Future<void> saveReadings(HealthPassport passport) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    await _ref.doc(caregiverId).set({
      'caregiverId': caregiverId,
      'bloodPressureSystolic': passport.bloodPressureSystolic,
      'bloodPressureDiastolic': passport.bloodPressureDiastolic,
      'oxygenLevel': passport.oxygenLevel,
      'heartRate': passport.heartRate,
      'bloodSugarFasting': passport.bloodSugarFasting,
      'bloodSugarPostMeal': passport.bloodSugarPostMeal,
      'cholesterol': passport.cholesterol,
      'temperatureF': passport.temperatureF,
      'readingsUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    }, SetOptions(merge: true));
  }
}