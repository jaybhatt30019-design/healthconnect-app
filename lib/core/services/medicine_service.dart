// lib/core/services/medicine_service.dart
// Data ownership: parentUid is the permanent key
// Parent's own uid never changes regardless of caregiver

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:Vitanex/models/medicine_model.dart';
import 'package:Vitanex/core/services/notification_service.dart';
import 'package:Vitanex/core/services/fcm_service.dart';
import 'package:flutter/material.dart';

class MedicineService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get _ref =>
      _firestore.collection('medicines');

  // ── Get parent's uid ───────────────────────────────
  Future<String?> _getParentUid() async {
    final uid = _auth.currentUser?.uid;
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

  // ── Is THIS device the parent's device? ────────────
  Future<bool> _isParentDevice() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final userDoc =
        await _firestore.collection('users').doc(uid).get();
    return userDoc.data()?['role'] == 'parent';
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
    final parentUid = await _getParentUid();
    if (parentUid == null) return;

    final uid = _auth.currentUser?.uid ?? '';
    final map = med.toMap(isNew: true);
    map['parentUid'] = parentUid;
    map['addedBy'] = uid;

    final ref = await _ref.add(map);

    if (await _isParentDevice()) {
      await NotificationService()
          .scheduleMedicineReminders(
        medicineId: ref.id,
        medicineName: med.name,
        dosage: med.dosage,
        times: med.times,
        endDate: med.endDate,
      );
    }


    try {
   if (! await _isParentDevice()) {
      // Child added it: Send silent trigger to Parent's device token to schedule locally
      final parentToken = await _getDeviceFcmToken(parentUid);
      if (parentToken != null) {
        await _sendMedicineSyncNotification(
          toToken: parentToken,
          medicineId: ref.id,
          medicineName: med.name,
          dosage: med.dosage,
          times: med.times,
          endDate: med.endDate,
        );
      }
    } else {
      // Parent added it: Send silent trigger to Child's device token so they can track/remind
      final childUid = await _getChildUid(parentUid);
      if (childUid != null) {
        final childToken = await _getDeviceFcmToken(childUid);
        if (childToken != null) {
          await _sendMedicineSyncNotification(
            toToken: childToken,
            medicineId: ref.id,
            medicineName: med.name,
            dosage: med.dosage,
            times: med.times,
            endDate: med.endDate,
          );
        }
      }
    }
  } catch (e) {
    debugPrint('[MedicineService] Remote sync notification failed: $e');
  }
  }



Future<String> _getChildUid (String parentid) async{
  final userDoc = await _firestore
        .collection('users')
        .doc(parentid)
        .get();
    if (!userDoc.exists) return "";


      //if (userDoc.) {
        return userDoc.get("caregiverId");
 // return "";
}

  Future<String > _getDeviceFcmToken(String uid) async{


final uid = _auth.currentUser?.uid;
    if (uid == null) return "";

    final userDoc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    if (!userDoc.exists) return "";


      //if (userDoc.) {
        return userDoc.get("fcmTken");
     // }
      //return "";
    

    ///   JUST 1 MIN SIR I AM COMMING OK

// return  "";
  }

  // ── UPDATE ────────────────────────────────────────
  Future<void> updateMedicine(Medicine med) async {
   await _ref.doc(med.id).update(med.toMap());

    if (await _isParentDevice()) {
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

   Future<void> courseCompleted(String id) async {
    final doc = await _ref.doc(id).get();
    final data =
        doc.data() as Map<String, dynamic>? ?? {};
    final timesCount =
        (data['times'] as List?)?.length ?? 3;
    await _ref.doc(id).update({
        "isCourseCompleted":true,
    });
    await NotificationService()
        .cancelMedicineReminders(id, timesCount);
  }

  // ── STREAM ────────────────────────────────────────
  Stream<List<Medicine>> getMedicines() async* {
    try {
      final parentUid = await _getParentUid()
          .timeout(const Duration(seconds: 10));

      if (parentUid == null) {
        yield [];
        return;
      }

      yield* _ref
          .where('parentUid', isEqualTo: parentUid)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Medicine.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id))
              .toList());
    } catch (e) {
      debugPrint(
          '[MedicineService] getMedicines: $e');
      yield [];
    }
  }

  // ── MARK TAKEN ────────────────────────────────────
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
      // Keep reset date in sync
      'lastResetDate':
          DateTime.now().toIso8601String(),
    });

    await NotificationService()
        .cancelSlotFollowUps(med.id, index);

    // ✅ Use the real slot label travelling with the medicine
    final slotLabel = med.slotLabelAt(index);

    final userName = await _getCurrentUserName();

    await FcmService().notifyDoseTaken(
      medicineName: med.name,
      slotLabel: slotLabel,
      parentName: userName,
    );

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
  Future<void> resetDailyStatus(Medicine med) async {
    final resetStatus =
        List.filled(med.times.length, false);
    await _ref.doc(med.id).update({
      'takenStatus': resetStatus,
      'lastResetDate':
          DateTime.now().toIso8601String(),
    });

    if (await _isParentDevice()) {
      await NotificationService()
          .scheduleMedicineReminders(
        medicineId: med.id,
        medicineName: med.name,
        dosage: med.dosage,
        times: med.times,
      );
    }
  }


  
    // ---------------  to take medicine from the other device and set it here ---------
  Future<void> _sendMedicineSyncNotification({
  required String toToken,
  required String medicineId,
  required String medicineName,
  required String dosage,
  required List<TimeOfDay> times,
  DateTime? endDate,
}) async {
  // Convert List<TimeOfDay> to a clear string format: "HH:mm,HH:mm"
  final timeStrings = times.map((t) => '${t.hour}:${t.minute}').join(',');

  await FirebaseFirestore.instance.collection('sync_queue').add({
    'toToken': toToken,
    'type': 'sync_medicine_reminder',
    'medicineId': medicineId,
    'medicineName': medicineName,
    'dosage': dosage,
    'times': timeStrings,
    'endDate': endDate?.toIso8601String(),
    'sent': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
}