// lib/core/services/fcm_service.dart
// Sends FCM push notifications to the OTHER device
// Works when app is killed on receiver's phone
// Uses Firestore write → Cloud Function trigger pattern

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  static final FcmService _instance =
      FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ── Save FCM token ────────────────────────────────
  Future<void> saveFcmToken() async {
    if (kIsWeb) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final token =
        await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .update({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    FirebaseMessaging.instance.onTokenRefresh
        .listen((newToken) {
      _firestore
          .collection('users')
          .doc(uid)
          .update({'fcmToken': newToken});
    });

    debugPrint('[FcmService] Token saved');
  }

  // ── Get current user's own FCM token ─────────────
  Future<String?> _getOwnToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?['fcmToken'] as String?;
  }

  // ── Get paired person's FCM token ────────────────
  Future<String?> _getPairedToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final userDoc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    final data = userDoc.data();
    if (data == null) return null;

    final role = data['role'] as String? ?? '';
    String pairedUid = '';

    if (role == 'parent') {
      pairedUid = data['caregiverId'] ?? '';
    } else if (role == 'caregiver') {
      final q = await _firestore
          .collection('users')
          .where('caregiverId', isEqualTo: uid)
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        pairedUid = q.docs.first.id;
      }
    }

    if (pairedUid.isEmpty) return null;

    final pairedDoc = await _firestore
        .collection('users')
        .doc(pairedUid)
        .get();
    return pairedDoc.data()?['fcmToken'] as String?;
  }

  // ── Get caregiverId ───────────────────────────────
  Future<String?> _getCaregiverId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data();
    if (data == null) return null;

    final role = data['role'] as String? ?? '';
    if (role == 'caregiver') return uid;
    if (role == 'parent') {
      final cid = data['caregiverId'] as String?;
      return (cid != null && cid.isNotEmpty)
          ? cid
          : uid;
    }
    return uid;
  }

  // ── Queue FCM via Firestore ───────────────────────
  Future<void> _queueNotification({
    required String toToken,
    required String title,
    required String body,
    required String type,
    Map<String, String> data = const {},
  }) async {
    try {
      await _firestore.collection('fcm_queue').add({
        'token': toToken,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });
      debugPrint('[FcmService] Queued: $title');
    } catch (e) {
      debugPrint('[FcmService] Queue error: $e');
    }
  }

  // ── Queue to multiple tokens at once ─────────────
  // Deduplicates tokens so same device not notified twice
  Future<void> _queueToAll({
    required List<String?> tokens,
    required String title,
    required String body,
    required String type,
    Map<String, String> data = const {},
  }) async {
    // Remove nulls and duplicates
    final unique = tokens
        .whereType<String>()
        .where((t) => t.isNotEmpty)
        .toSet();

    for (final token in unique) {
      await _queueNotification(
        toToken: token,
        title: title,
        body: body,
        type: type,
        data: data,
      );
    }
  }

  // ─────────────────────────────────────────────────
  // MEDICINE — Dose taken (notify caregiver)
  // ─────────────────────────────────────────────────
  Future<void> notifyDoseTaken({
    required String medicineName,
    required String slotLabel,
    required String parentName,
  }) async {
    final token = await _getPairedToken();
    if (token == null) return;

    final caregiverId = await _getCaregiverId();
    await _writeInAppNotification(
      title: '✅ Dose Taken',
      body: '$parentName took $medicineName — $slotLabel',
      type: 'dose_taken',
      caregiverId: caregiverId,
      forCurrentUser: false,
    );

    await _queueNotification(
      toToken: token,
      title: '✅ Dose Taken',
      body:
          '$parentName took $medicineName — $slotLabel dose',
      type: 'dose_taken',
    );
  }

  // ─────────────────────────────────────────────────
  // MEDICINE — Missed dose (notify caregiver)
  // ─────────────────────────────────────────────────
  Future<void> notifyMissedDose({
    required String medicineName,
    required String dosage,
    required String slotLabel,
    required String parentName,
  }) async {
    final token = await _getPairedToken();
    if (token == null) return;

    final caregiverId = await _getCaregiverId();
    await _writeInAppNotification(
      title: '⚠️ Missed Dose',
      body:
          '$parentName missed $medicineName $dosage — $slotLabel',
      type: 'missed_dose',
      caregiverId: caregiverId,
      forCurrentUser: false,
    );

    await _queueNotification(
      toToken: token,
      title: '⚠️ Missed Dose',
      body:
          '$parentName missed $medicineName $dosage — $slotLabel dose',
      type: 'missed_dose',
    );
  }

  // ─────────────────────────────────────────────────
  // MEDICINE — Low stock (notify BOTH devices)
  // ✅ FIXED: was only sending to paired device
  // Now sends to both current user AND paired device
  // so both parent and caregiver see it on their panel
  // ─────────────────────────────────────────────────
  Future<void> notifyLowStock({
    required String medicineName,
    required int remaining,
    required String unit,
  }) async {
    final title =
        remaining <= 0 ? '📦 Out of Stock' : '📦 Low Stock';
    final body = remaining <= 0
        ? '$medicineName is out of stock. Please restock now.'
        : '$medicineName — only $remaining $unit left. Restock soon.';

    // ✅ Get BOTH tokens — own + paired
    final ownToken = await _getOwnToken();
    final pairedToken = await _getPairedToken();

    // ✅ Send to both — _queueToAll deduplicates
    // so if both are same device it only sends once
    await _queueToAll(
      tokens: [ownToken, pairedToken],
      title: title,
      body: body,
      type: 'low_stock',
    );

    debugPrint(
        '[FcmService] Low stock notified: '
        'own=${ownToken != null} '
        'paired=${pairedToken != null}');

    // In-app notification for both
    final caregiverId = await _getCaregiverId();
    await _writeInAppNotification(
      title: title,
      body: body,
      type: 'low_stock',
      caregiverId: caregiverId,
      forCurrentUser: true,
    );
  }

  // ─────────────────────────────────────────────────
  // MEDICINE — Restocked (notify other device)
  // ─────────────────────────────────────────────────
  Future<void> notifyRestocked({
    required String medicineName,
    required int addedQuantity,
    required String unit,
    required String addedByName,
  }) async {
    final token = await _getPairedToken();
    if (token == null) return;

    final caregiverId = await _getCaregiverId();
    final title = '📦 Medicine Restocked';
    final body =
        '$medicineName restocked by $addedByName '
        '(+$addedQuantity $unit)';

    await _queueNotification(
      toToken: token,
      title: title,
      body: body,
      type: 'restocked',
    );

    await _writeInAppNotification(
      title: title,
      body: body,
      type: 'restocked',
      caregiverId: caregiverId,
      forCurrentUser: false,
    );
  }

  // ─────────────────────────────────────────────────
  // APPOINTMENT — Added
  // ─────────────────────────────────────────────────
  Future<void> notifyAppointmentAdded({
    required String doctorName,
    required String hospitalName,
    required DateTime dateTime,
    required String addedByName,
  }) async {
    final token = await _getPairedToken();
    if (token == null) return;

    final caregiverId = await _getCaregiverId();
    final dateStr =
        '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    final title = '📅 New Appointment Added';
    final body =
        'Dr. $doctorName at $hospitalName on $dateStr';

    await _queueNotification(
      toToken: token,
      title: title,
      body: body,
      type: 'appointment_added',
    );

    await _writeInAppNotification(
      title: title,
      body: body,
      type: 'appointment_added',
      caregiverId: caregiverId,
      forCurrentUser: false,
    );
  }

  // ─────────────────────────────────────────────────
  // SCAN — Report saved
  // ─────────────────────────────────────────────────
  Future<void> notifyScanSaved({
    required String savedByName,
    required int itemCount,
  }) async {
    final token = await _getPairedToken();
    if (token == null) return;

    final caregiverId = await _getCaregiverId();
    final title = '📄 Medical Report Scanned';
    final body =
        '$savedByName added $itemCount '
        'item${itemCount == 1 ? '' : 's'} from a scanned document';

    await _queueNotification(
      toToken: token,
      title: title,
      body: body,
      type: 'scan_saved',
    );

    await _writeInAppNotification(
      title: title,
      body: body,
      type: 'scan_saved',
      caregiverId: caregiverId,
      forCurrentUser: false,
    );
  }

  // ─────────────────────────────────────────────────
  // LOCATION — Started sharing
  // ─────────────────────────────────────────────────
  Future<void> notifyLocationStarted({
    required String parentName,
  }) async {
    final token = await _getPairedToken();
    if (token == null) return;

    await _queueNotification(
      toToken: token,
      title: '📍 Location Sharing',
      body:
          '$parentName is now sharing their location',
      type: 'location_started',
    );
  }

  // ─────────────────────────────────────────────────
  // Write in-app notification to Firestore
  // Shows in the bell icon inside the app
  // ─────────────────────────────────────────────────
  Future<void> _writeInAppNotification({
    required String title,
    required String body,
    required String type,
    required String? caregiverId,
    required bool forCurrentUser,
  }) async {
    if (caregiverId == null) return;

    final uid = _auth.currentUser?.uid;
    final List<String> userIds = [];

    if (forCurrentUser && uid != null) {
      userIds.add(uid);
    }

    final pairedUid = await _getPairedUid();
    if (pairedUid != null) {
      userIds.add(pairedUid);
    }

    if (userIds.isEmpty && uid != null) {
      userIds.add(uid);
    }

    final batch = _firestore.batch();
    for (final userId in userIds.toSet()) {
      final ref =
          _firestore.collection('notifications').doc();
      batch.set(ref, {
        'userId': userId,
        'caregiverId': caregiverId,
        'type': type,
        'title': title,
        'body': body,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<String?> _getPairedUid() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final userDoc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    final data = userDoc.data();
    if (data == null) return null;

    final role = data['role'] as String? ?? '';

    if (role == 'parent') {
      return data['caregiverId'] as String?;
    } else if (role == 'caregiver') {
      final q = await _firestore
          .collection('users')
          .where('caregiverId', isEqualTo: uid)
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return q.docs.first.id;
    }
    return null;
  }
}