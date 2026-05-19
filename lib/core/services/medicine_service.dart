// lib/core/services/medicine_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:healthconnect/core/services/notification_service.dart';
import 'package:healthconnect/core/services/fcm_service.dart';

class MedicineService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get _ref =>
      _firestore.collection('medicines');

  Future<String?> _getCaregiverId() async {
    final uid = _auth.currentUser?.uid;
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
          caregiverId.isNotEmpty) return caregiverId;
      return uid;
    }
    return uid;
  }

  Future<String> _getCurrentUserName() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'User';
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?['name'] as String? ?? 'User';
  }

  // ── ADD ───────────────────────────────────────────
  Future<void> addMedicine(Medicine med) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    final map = med.toMap(isNew: true);
    map['caregiverId'] = caregiverId;
    final ref = await _ref.add(map);

    // Schedule daily reminder + hourly follow-ups
    await NotificationService()
        .scheduleMedicineReminders(
      medicineId: ref.id,
      medicineName: med.name,
      dosage: med.dosage,
      times: med.times,
    );
  }

  // ── UPDATE ────────────────────────────────────────
  Future<void> updateMedicine(Medicine med) async {
    await _ref.doc(med.id).update(med.toMap());

    // Reschedule with updated times
    await NotificationService()
        .cancelMedicineReminders(
            med.id, med.times.length + 1);
    await NotificationService()
        .scheduleMedicineReminders(
      medicineId: med.id,
      medicineName: med.name,
      dosage: med.dosage,
      times: med.times,
    );
  }

  // ── DELETE ────────────────────────────────────────
  Future<void> deleteMedicine(String id) async {
    final doc = await _ref.doc(id).get();
    final data =
        doc.data() as Map<String, dynamic>? ?? {};
    final timesCount =
        (data['times'] as List?)?.length ?? 3;
    await _ref.doc(id).delete();
    await NotificationService()
        .cancelMedicineReminders(id, timesCount);
  }

  // ── STREAM ────────────────────────────────────────
  Stream<List<Medicine>> getMedicines() async* {
    try {
      final caregiverId = await _getCaregiverId()
          .timeout(const Duration(seconds: 10));

      if (caregiverId == null) {
        yield [];
        return;
      }

      yield* _ref
          .where('caregiverId',
              isEqualTo: caregiverId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Medicine.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id))
              .toList());
    } catch (e) {
      debugPrint(
          '[MedicineService] getMedicines error: $e');
      yield [];
    }
  }

  // ── MARK TAKEN ────────────────────────────────────
  // ✅ Cancels all follow-up reminders for this slot
  // so user stops getting "not taken yet" alerts
  Future<void> markTaken(
      Medicine med, int index) async {
    final newStatus =
        List<bool>.from(med.takenStatus);
    newStatus[index] = true;

    final newStock =
        med.stockCount > 0 ? med.stockCount - 1 : 0;

    await _ref.doc(med.id).update({
      'takenStatus': newStatus,
      'stockCount': newStock,
    });

    debugPrint(
        '[MedicineService] Taken: ${med.name} '
        'slot $index, stock: $newStock');

    // ✅ Cancel all follow-up reminders for this slot
    await NotificationService()
        .cancelSlotFollowUps(med.id, index);

    final slotLabel = index == 0
        ? 'Morning'
        : index == 1
            ? 'Afternoon'
            : 'Night';

    final userName = await _getCurrentUserName();

    // Notify caregiver that dose was taken
    await FcmService().notifyDoseTaken(
      medicineName: med.name,
      slotLabel: slotLabel,
      parentName: userName,
    );

    // Low stock check
    if (newStock <= med.lowStockThreshold) {
      await FcmService().notifyLowStock(
        medicineName: med.name,
        remaining: newStock,
        unit: med.stockUnit,
      );
    }
  }

  // ── RESTOCK ───────────────────────────────────────
  Future<void> restock(
      Medicine med, int addQuantity) async {
    if (addQuantity <= 0) return;

    final newStock = med.stockCount + addQuantity;
    await _ref.doc(med.id).update({
      'stockCount': newStock,
      'lastRestockedAt':
          DateTime.now().toIso8601String(),
    });

    final userName = await _getCurrentUserName();
    await FcmService().notifyRestocked(
      medicineName: med.name,
      addedQuantity: addQuantity,
      unit: med.stockUnit,
      addedByName: userName,
    );
  }

  // ── RESET DAILY STATUS ────────────────────────────
  // Call on new day — resets taken status
  // and reschedules follow-up reminders
  Future<void> resetDailyStatus(Medicine med) async {
    final resetStatus =
        List.filled(med.times.length, false);
    await _ref.doc(med.id).update({
      'takenStatus': resetStatus,
      'lastResetDate':
          DateTime.now().toIso8601String(),
    });

    // Reschedule follow-ups for new day
    await NotificationService()
        .scheduleMedicineReminders(
      medicineId: med.id,
      medicineName: med.name,
      dosage: med.dosage,
      times: med.times,
    );
  }
}