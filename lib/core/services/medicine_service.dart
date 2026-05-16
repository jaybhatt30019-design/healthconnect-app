// lib/core/services/medicine_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:healthconnect/models/medicine_model.dart';

class MedicineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _ref => _firestore.collection('medicines');

  // ─────────────────────────────────────────────────────
  // Get caregiverId — unchanged from your current code
  // ─────────────────────────────────────────────────────
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
      return uid;
    }

    return uid;
  }

  // ─────────────────────────────────────────────────────
  // ADD — unchanged logic, new fields included via toMap()
  // ─────────────────────────────────────────────────────
  Future<void> addMedicine(Medicine med) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    final map = med.toMap(isNew: true);
    map['caregiverId'] = caregiverId;
    await _ref.add(map);
  }

  // ─────────────────────────────────────────────────────
  // UPDATE — unchanged
  // ─────────────────────────────────────────────────────
  Future<void> updateMedicine(Medicine med) async {
    await _ref.doc(med.id).update(med.toMap());
  }

  // ─────────────────────────────────────────────────────
  // DELETE — unchanged
  // ─────────────────────────────────────────────────────
  Future<void> deleteMedicine(String id) async {
    await _ref.doc(id).delete();
  }

  // ─────────────────────────────────────────────────────
  // STREAM — unchanged
  // ─────────────────────────────────────────────────────
  Stream<List<Medicine>> getMedicines() async* {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) {
      yield [];
      return;
    }

    yield* _ref
        .where('caregiverId', isEqualTo: caregiverId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Medicine.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // ─────────────────────────────────────────────────────
  // MARK TAKEN — NEW
  // Marks dose as taken AND decrements stock by 1
  // Then checks if stock is low and sends notification
  // ─────────────────────────────────────────────────────
  Future<void> markTaken(Medicine med, int index) async {
    // Update takenStatus
    final newStatus = List<bool>.from(med.takenStatus);
    newStatus[index] = true;

    // Decrement stock — never goes below 0
    final newStock =
        med.stockCount > 0 ? med.stockCount - 1 : 0;

    await _ref.doc(med.id).update({
      'takenStatus': newStatus,
      'stockCount': newStock,
    });

    debugPrint(
        '[MedicineService] Marked taken: ${med.name}, stock: $newStock ${med.stockUnit}');

    // Check low stock and notify both users
    if (newStock <= med.lowStockThreshold) {
      await _sendLowStockNotification(
        med: med,
        remainingCount: newStock,
      );
    }
  }

  // ─────────────────────────────────────────────────────
  // RESTOCK — NEW
  // Adds quantity to current stock
  // ─────────────────────────────────────────────────────
  Future<void> restock(Medicine med, int addQuantity) async {
    if (addQuantity <= 0) return;

    final newStock = med.stockCount + addQuantity;

    await _ref.doc(med.id).update({
      'stockCount': newStock,
      'lastRestockedAt': DateTime.now().toIso8601String(),
    });

    debugPrint(
        '[MedicineService] Restocked: ${med.name} +$addQuantity, new stock: $newStock ${med.stockUnit}');
  }

  // ─────────────────────────────────────────────────────
  // LOW STOCK NOTIFICATION — NEW
  // Writes to /notifications for both parent and caregiver
  // Both see it on their dashboards
  // ─────────────────────────────────────────────────────
  Future<void> _sendLowStockNotification({
    required Medicine med,
    required int remainingCount,
  }) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Get both user IDs — caregiver + parent
    final List<String> userIds = [caregiverId];

    // Find the parent uid (if exists)
    final parentQuery = await _firestore
        .collection('users')
        .where('caregiverId', isEqualTo: caregiverId)
        .where('role', isEqualTo: 'parent')
        .limit(1)
        .get();

    if (parentQuery.docs.isNotEmpty) {
      userIds.add(parentQuery.docs.first.id);
    }

    final title = remainingCount <= 0
        ? '⚠️ Medicine Out of Stock'
        : '💊 Medicine Running Low';

    final body = remainingCount <= 0
        ? '${med.name} is out of stock. Please restock immediately.'
        : '${med.name} — only $remainingCount ${med.stockUnit} remaining. Time to restock.';

    // Write notification for each user
    final batch = _firestore.batch();
    for (final userId in userIds) {
      final notifRef =
          _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': userId,
        'caregiverId': caregiverId,
        'type': 'low_stock',
        'title': title,
        'body': body,
        'medicineName': med.name,
        'remainingCount': remainingCount,
        'stockUnit': med.stockUnit,
        'medicineId': med.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    debugPrint('[MedicineService] Low stock notification sent: ${med.name}');
  }

  // ─────────────────────────────────────────────────────
  // RESET TAKEN STATUS — called on new day
  // Resets takenStatus to all false without touching stock
  // ─────────────────────────────────────────────────────
  Future<void> resetDailyStatus(Medicine med) async {
    final resetStatus = List.filled(med.times.length, false);
    await _ref.doc(med.id).update({
      'takenStatus': resetStatus,
      'lastResetDate': DateTime.now().toIso8601String(),
    });
  }
}