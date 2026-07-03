// lib/core/services/medical_history_service.dart
// Data ownership: parentUid is the permanent doc ID

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:Vitanex/models/medical_history_model.dart';

class MedicalHistoryService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  CollectionReference get _ref =>
      _firestore.collection('medical_history');

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
  Stream<MedicalHistory?> historyStream() {
    return Stream.fromFuture(_getParentUid())
        .asyncExpand(
      (parentUid) {
        if (parentUid == null) {
          return Stream.value(null);
        }
        return _ref.doc(parentUid).snapshots().map(
          (snap) {
            if (!snap.exists) {
              return MedicalHistory.empty(parentUid);
            }
            return MedicalHistory.fromFirestore(
                snap.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }

  // ── Load one-time ─────────────────────────────────
  Future<MedicalHistory?> loadHistory() async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return null;

    final doc = await _ref.doc(parentUid).get();
    if (!doc.exists) {
      return MedicalHistory.empty(parentUid);
    }
    return MedicalHistory.fromFirestore(
        doc.data() as Map<String, dynamic>);
  }

  // ── ILLNESS — Add ─────────────────────────────────
  Future<void> addIllness(Illness illness) async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return;

    final newIllness = Illness(
      id: _uuid.v4(),
      name: illness.name,
      diagnosedDate: illness.diagnosedDate,
      recoveredDate: illness.recoveredDate,
      severity: illness.severity,
      doctor: illness.doctor,
      notes: illness.notes,
    );

    await _ref.doc(parentUid).set({
      'parentUid': parentUid,
      'illnesses': FieldValue.arrayUnion(
          [newIllness.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    }, SetOptions(merge: true));

    debugPrint(
        '[MedicalHistory] Illness added: '
        '${newIllness.name} for parent=$parentUid');
  }

  // ── ILLNESS — Update ──────────────────────────────
  Future<void> updateIllness(Illness updated) async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return;

    final history = await loadHistory();
    if (history == null) return;

    final updatedList = history.illnesses.map((ill) {
      return ill.id == updated.id ? updated : ill;
    }).toList();

    await _ref.doc(parentUid).update({
      'illnesses':
          updatedList.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });
  }

  // ── ILLNESS — Delete ──────────────────────────────
  Future<void> deleteIllness(
      String illnessId) async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return;

    final history = await loadHistory();
    if (history == null) return;

    final updatedList = history.illnesses
        .where((ill) => ill.id != illnessId)
        .toList();

    await _ref.doc(parentUid).update({
      'illnesses':
          updatedList.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });
  }

  // ── SURGERY — Add ─────────────────────────────────
  Future<void> addSurgery(Surgery surgery) async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return;

    final newSurgery = Surgery(
      id: _uuid.v4(),
      name: surgery.name,
      date: surgery.date,
      hospital: surgery.hospital,
      surgeon: surgery.surgeon,
      notes: surgery.notes,
    );

    await _ref.doc(parentUid).set({
      'parentUid': parentUid,
      'surgeries': FieldValue.arrayUnion(
          [newSurgery.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    }, SetOptions(merge: true));

    debugPrint(
        '[MedicalHistory] Surgery added: '
        '${newSurgery.name} for parent=$parentUid');
  }

  // ── SURGERY — Update ──────────────────────────────
  Future<void> updateSurgery(Surgery updated) async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return;

    final history = await loadHistory();
    if (history == null) return;

    final updatedList = history.surgeries.map((s) {
      return s.id == updated.id ? updated : s;
    }).toList();

    await _ref.doc(parentUid).update({
      'surgeries':
          updatedList.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });
  }

  // ── SURGERY — Delete ──────────────────────────────
  Future<void> deleteSurgery(
      String surgeryId) async {
    final parentUid = await _getParentUid();
    if (parentUid == null) return;

    final history = await loadHistory();
    if (history == null) return;

    final updatedList = history.surgeries
        .where((s) => s.id != surgeryId)
        .toList();

    await _ref.doc(parentUid).update({
      'surgeries':
          updatedList.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });
  }
}