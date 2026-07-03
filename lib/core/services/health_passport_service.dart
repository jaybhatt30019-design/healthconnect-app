// lib/core/services/health_passport_service.dart
// Data ownership: parentUid is the permanent doc ID

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:Vitanex/models/health_passport_model.dart';

class HealthPassportService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get _ref =>
      _firestore.collection('health_passport');

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

    // Parent is the permanent owner
    if (role == 'parent') return uid;

    // Caregiver — find linked parent's uid
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

  // ── Realtime stream ───────────────────────────────
  Stream<HealthPassport?> passportStream() {
    return Stream.fromFuture(_getParentUid())
        .asyncExpand(
      (parentUid) {
        if (parentUid == null) {
          return Stream.value(null);
        }
        return _ref.doc(parentUid).snapshots().map(
          (snap) {
            if (!snap.exists) {
              return HealthPassport.empty(parentUid);
            }
            return HealthPassport.fromFirestore(
                snap.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }

  // ── One-time load ─────────────────────────────────
  Future<HealthPassport?> loadPassport() async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return null;

    final doc = await _ref.doc(parentUid).get();
    if (!doc.exists) {
      return HealthPassport.empty(parentUid);
    }
    return HealthPassport.fromFirestore(
        doc.data() as Map<String, dynamic>);
  }

  // ── Save full passport ────────────────────────────
  Future<void> savePassport(
      HealthPassport passport) async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return;

    final map = passport.toMap();
    // ✅ Store parentUid as the owner identifier
    map['parentUid'] = parentUid;
    map['updatedAt'] = FieldValue.serverTimestamp();
    map['updatedBy'] = _auth.currentUser?.uid;

    await _ref.doc(parentUid).set(
        map, SetOptions(merge: true));

    debugPrint(
        '[HealthPassport] Saved for parent=$parentUid');
  }

  // ── Save only readings ────────────────────────────
  Future<void> saveReadings(
      HealthPassport passport) async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return;

    await _ref.doc(parentUid).set({
      'parentUid': parentUid,
      'bloodPressureSystolic':
          passport.bloodPressureSystolic,
      'bloodPressureDiastolic':
          passport.bloodPressureDiastolic,
      'oxygenLevel': passport.oxygenLevel,
      'heartRate': passport.heartRate,
      'bloodSugarFasting': passport.bloodSugarFasting,
      'bloodSugarPostMeal': passport.bloodSugarPostMeal,
      'cholesterol': passport.cholesterol,
      'temperatureF': passport.temperatureF,
      'readingsUpdatedAt':
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    }, SetOptions(merge: true));
  }
}