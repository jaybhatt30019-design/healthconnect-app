// lib/core/services/connection_service.dart
// When parent connects via pairing code,
// their uid is stored so caregiver can resolve parentUid

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ConnectionInfo {
  final bool isConnected;
  final String? connectedName;
  final String? connectedPhone;
  final String? relation;
  final String? connectedSince;
  final String? parentDocId;

  const ConnectionInfo({
    required this.isConnected,
    this.connectedName,
    this.connectedPhone,
    this.relation,
    this.connectedSince,
    this.parentDocId,
  });
}

class ConnectionService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<ConnectionInfo> loadConnectionInfo() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const ConnectionInfo(isConnected: false);
    }

    final userDoc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    final userData = userDoc.data() ?? {};
    final role = userData['role'] as String? ?? '';

    if (role == 'caregiver') {
      return await _loadParentInfo(uid);
    } else {
      return await _loadCaregiverInfo(uid, userData);
    }
  }

  Future<ConnectionInfo> _loadParentInfo(
      String caregiverId) async {
    try {
      final snap = await _firestore
          .collection('parents')
          .where('caregiverId', isEqualTo: caregiverId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        return const ConnectionInfo(isConnected: false);
      }

      final doc = snap.docs.first;
      final data = doc.data();

      String? connectedSince;
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        final dt = createdAt.toDate();
        connectedSince =
            '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year}';
      }

      return ConnectionInfo(
        isConnected: true,
        connectedName:
            data['name'] as String? ?? 'Parent',
        connectedPhone:
            data['phone'] as String? ?? '',
        relation:
            data['relation'] as String? ?? '',
        connectedSince: connectedSince,
        parentDocId: doc.id,
      );
    } catch (e) {
      debugPrint(
          '[ConnectionService] Parent info: $e');
      return const ConnectionInfo(isConnected: false);
    }
  }

  Future<ConnectionInfo> _loadCaregiverInfo(
      String parentUid,
      Map<String, dynamic> userData) async {
    try {
      final caregiverId =
          userData['caregiverId'] as String?;

      if (caregiverId == null ||
          caregiverId.isEmpty) {
        return const ConnectionInfo(isConnected: false);
      }

      final caregiverDoc = await _firestore
          .collection('users')
          .doc(caregiverId)
          .get();

      if (!caregiverDoc.exists) {
        return const ConnectionInfo(isConnected: false);
      }

      final data = caregiverDoc.data() ?? {};

      String? connectedSince;
      final pairingDate =
          userData['connectedAt'] as Timestamp?;
      if (pairingDate != null) {
        final dt = pairingDate.toDate();
        connectedSince =
            '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year}';
      }

      return ConnectionInfo(
        isConnected: true,
        connectedName:
            data['name'] as String? ?? 'Caregiver',
        connectedPhone:
            data['phone'] as String? ?? '',
        connectedSince: connectedSince,
      );
    } catch (e) {
      debugPrint(
          '[ConnectionService] Caregiver info: $e');
      return const ConnectionInfo(isConnected: false);
    }
  }

  Future<void> disconnect() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    final userData = userDoc.data() ?? {};
    final role = userData['role'] as String? ?? '';

    if (role == 'caregiver') {
      await _caregiverDisconnect(uid);
    } else {
      await _parentDisconnect(uid, userData);
    }
  }

  Future<void> _caregiverDisconnect(
      String caregiverId) async {
    final batch = _firestore.batch();

    // Delete parent docs
    final parentSnap = await _firestore
        .collection('parents')
        .where('caregiverId', isEqualTo: caregiverId)
        .get();
    for (final doc in parentSnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete pairing codes
    final codeSnap = await _firestore
        .collection('pairing_codes')
        .where('caregiverId', isEqualTo: caregiverId)
        .get();
    for (final doc in codeSnap.docs) {
      batch.delete(doc.reference);
    }

    // Remove caregiverId from linked parent's doc
    final linkedParentSnap = await _firestore
        .collection('users')
        .where('caregiverId', isEqualTo: caregiverId)
        .where('role', isEqualTo: 'parent')
        .get();
    for (final doc in linkedParentSnap.docs) {
      batch.update(doc.reference, {
        'caregiverId': FieldValue.delete(),
        'connectedAt': FieldValue.delete(),
      });
    }

    // Update caregiver doc
    batch.update(
      _firestore.collection('users').doc(caregiverId),
      {
        'parentLinked': false,
        'pairingCode': FieldValue.delete(),
      },
    );

    await batch.commit();
    debugPrint(
        '[ConnectionService] Caregiver disconnected');
  }

  Future<void> _parentDisconnect(
      String parentUid,
      Map<String, dynamic> userData) async {
    final caregiverId =
        userData['caregiverId'] as String?;

    final batch = _firestore.batch();

    // Remove caregiverId from parent doc
    // Data stays safe — parentUid is still the key
    batch.update(
      _firestore.collection('users').doc(parentUid),
      {
        'caregiverId': FieldValue.delete(),
        'connectedAt': FieldValue.delete(),
      },
    );

    if (caregiverId != null &&
        caregiverId.isNotEmpty) {
      // Delete parents collection doc
      final parentSnap = await _firestore
          .collection('parents')
          .where('caregiverId', isEqualTo: caregiverId)
          .get();
      for (final doc in parentSnap.docs) {
        batch.delete(doc.reference);
      }

      // Delete pairing codes
      final codeSnap = await _firestore
          .collection('pairing_codes')
          .where('caregiverId', isEqualTo: caregiverId)
          .get();
      for (final doc in codeSnap.docs) {
        batch.delete(doc.reference);
      }

      // Update caregiver doc
      batch.update(
        _firestore
            .collection('users')
            .doc(caregiverId),
        {
          'parentLinked': false,
          'pairingCode': FieldValue.delete(),
        },
      );
    }

    await batch.commit();
    debugPrint(
        '[ConnectionService] Parent disconnected');
  }

  Future<ConnectResult> connectWithCode(
      String code) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return ConnectResult.error('Not logged in');
    }

    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      return ConnectResult.error(
          'Please enter a pairing code');
    }

    try {
      final codeDoc = await _firestore
          .collection('pairing_codes')
          .doc(trimmed)
          .get();

      if (!codeDoc.exists) {
        return ConnectResult.error(
            'Invalid pairing code. Check and try again.');
      }

      final codeData = codeDoc.data()!;

      if (codeData['isUsed'] == true) {
        return ConnectResult.error(
            'This code has already been used.');
      }

      final expiresAt =
          codeData['expiresAt'] as Timestamp?;
      if (expiresAt != null &&
          expiresAt.toDate().isBefore(DateTime.now())) {
        return ConnectResult.error(
            'This code has expired. Ask your caregiver '
            'to generate a new one.');
      }

      final caregiverId =
          codeData['caregiverId'] as String?;
      if (caregiverId == null) {
        return ConnectResult.error(
            'Invalid code data. Try again.');
      }

      final batch = _firestore.batch();

      // Mark code used
      batch.update(codeDoc.reference,
          {'isUsed': true});

      // Update caregiver
      batch.update(
        _firestore
            .collection('users')
            .doc(caregiverId),
        {'parentLinked': true},
      );

      // Link parent to caregiver
      batch.update(
        _firestore.collection('users').doc(uid),
        {
          'caregiverId': caregiverId,
          'connectedAt': FieldValue.serverTimestamp(),
        },
      );

      // ✅ Store parentUid in parents collection
      // so caregiver can resolve parentUid via query
      final parentDocId = codeData['parentId'] as String?;
      if (parentDocId != null) {
        batch.update(
          _firestore.collection('parents').doc(parentDocId),
          {'parentUid': uid},
        );
      }

      await batch.commit();

      final caregiverDoc = await _firestore
          .collection('users')
          .doc(caregiverId)
          .get();
      final caregiverName =
          caregiverDoc.data()?['name'] as String? ??
              'Caregiver';

      debugPrint(
          '[ConnectionService] Connected: '
          'parent=$uid → caregiver=$caregiverId');

      return ConnectResult.success(caregiverName);
    } catch (e) {
      debugPrint(
          '[ConnectionService] Connect error: $e');
      return ConnectResult.error(
          'Something went wrong. Please try again.');
    }
  }
}

class ConnectResult {
  final bool success;
  final String message;

  ConnectResult._({
    required this.success,
    required this.message,
  });

  factory ConnectResult.success(String name) =>
      ConnectResult._(success: true, message: name);

  factory ConnectResult.error(String error) =>
      ConnectResult._(success: false, message: error);
}