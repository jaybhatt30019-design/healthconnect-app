// lib/core/services/medical_history_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:healthconnect/models/medical_history_model.dart';

// ✅ NO singleton — every screen creates its own instance
// This prevents stream caching issues completely
class MedicalHistoryService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  CollectionReference get _ref =>
      _firestore.collection('medical_history');

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
  // ✅ Returns a new stream every call — no caching
  Stream<MedicalHistory?> historyStream() {
    return Stream.fromFuture(_getCaregiverId()).asyncExpand(
      (caregiverId) {
        if (caregiverId == null) return Stream.value(null);

        return _ref.doc(caregiverId).snapshots().map((snap) {
          if (!snap.exists) {
            return MedicalHistory.empty(caregiverId);
          }
          return MedicalHistory.fromFirestore(
              snap.data() as Map<String, dynamic>);
        });
      },
    );
  }

  // ── Load one-time ─────────────────────────────────
  Future<MedicalHistory?> loadHistory() async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return null;

    final doc = await _ref.doc(caregiverId).get();
    if (!doc.exists) return MedicalHistory.empty(caregiverId);
    return MedicalHistory.fromFirestore(
        doc.data() as Map<String, dynamic>);
  }

  // ── ILLNESS — Add ─────────────────────────────────
  Future<void> addIllness(Illness illness) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    final newIllness = Illness(
      id: _uuid.v4(),
      name: illness.name,
      diagnosedDate: illness.diagnosedDate,
      recoveredDate: illness.recoveredDate,
      severity: illness.severity,
      doctor: illness.doctor,
      notes: illness.notes,
    );

    await _ref.doc(caregiverId).set({
      'caregiverId': caregiverId,
      'illnesses': FieldValue.arrayUnion([newIllness.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    }, SetOptions(merge: true));

    debugPrint('[MedicalHistory] Illness added: ${newIllness.name}');
  }

  // ── ILLNESS — Update ──────────────────────────────
  Future<void> updateIllness(Illness updated) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    final history = await loadHistory();
    if (history == null) return;

    final updatedList = history.illnesses.map((ill) {
      return ill.id == updated.id ? updated : ill;
    }).toList();

    await _ref.doc(caregiverId).update({
      'illnesses': updatedList.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });
  }

  // ── ILLNESS — Delete ──────────────────────────────
  Future<void> deleteIllness(String illnessId) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    final history = await loadHistory();
    if (history == null) return;

    final updatedList = history.illnesses
        .where((ill) => ill.id != illnessId)
        .toList();

    await _ref.doc(caregiverId).update({
      'illnesses': updatedList.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });
  }

  // ── SURGERY — Add ─────────────────────────────────
  Future<void> addSurgery(Surgery surgery) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    final newSurgery = Surgery(
      id: _uuid.v4(),
      name: surgery.name,
      date: surgery.date,
      hospital: surgery.hospital,
      surgeon: surgery.surgeon,
      notes: surgery.notes,
    );

    await _ref.doc(caregiverId).set({
      'caregiverId': caregiverId,
      'surgeries': FieldValue.arrayUnion([newSurgery.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    }, SetOptions(merge: true));

    debugPrint('[MedicalHistory] Surgery added: ${newSurgery.name}');
  }

  // ── SURGERY — Update ──────────────────────────────
  Future<void> updateSurgery(Surgery updated) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    final history = await loadHistory();
    if (history == null) return;

    final updatedList = history.surgeries.map((s) {
      return s.id == updated.id ? updated : s;
    }).toList();

    await _ref.doc(caregiverId).update({
      'surgeries': updatedList.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });
  }

  // ── SURGERY — Delete ──────────────────────────────
  Future<void> deleteSurgery(String surgeryId) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    final history = await loadHistory();
    if (history == null) return;

    final updatedList = history.surgeries
        .where((s) => s.id != surgeryId)
        .toList();

    await _ref.doc(caregiverId).update({
      'surgeries': updatedList.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });
  }
}