// lib/core/services/connection_service.dart
// Handles pairing and unpairing between caregiver and parent
// Both roles can call disconnect — logic is symmetric

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ConnectionInfo {
  final bool isConnected;
  final String? connectedName;
  final String? connectedPhone;
  final String? relation; // only for caregiver viewing parent
  final String? connectedSince;
  final String? parentDocId; // for deletion on disconnect

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

  // ── Load connection info ───────────────────────────
  // Returns who the current user is connected to
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

  // Caregiver — find their linked parent
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
      debugPrint('[ConnectionService] Parent info: $e');
      return const ConnectionInfo(isConnected: false);
    }
  }

  // Parent — find their linked caregiver
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

      // Get connected since from caregiver's createdAt
      // or parent's own doc
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

  // ── Disconnect ─────────────────────────────────────
  // Works for both roles — detects who is calling
  // and cleans up all relevant Firestore documents
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
      await _caregiverDisconnect(uid, userData);
    } else {
      await _parentDisconnect(uid, userData);
    }
  }

  // Caregiver initiated disconnect
  Future<void> _caregiverDisconnect(
      String caregiverId,
      Map<String, dynamic> userData) async {
    final batch = _firestore.batch();

    // 1. Find and delete parent doc
    final parentSnap = await _firestore
        .collection('parents')
        .where('caregiverId', isEqualTo: caregiverId)
        .get();

    for (final doc in parentSnap.docs) {
      batch.delete(doc.reference);
    }

    // 2. Find and delete pairing codes
    final codeSnap = await _firestore
        .collection('pairing_codes')
        .where('caregiverId', isEqualTo: caregiverId)
        .get();

    for (final doc in codeSnap.docs) {
      batch.delete(doc.reference);
    }

    // 3. Find linked parent user and remove caregiverId
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

    // 4. Update caregiver's own doc
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

  // Parent initiated disconnect
  Future<void> _parentDisconnect(
      String parentUid,
      Map<String, dynamic> userData) async {
    final caregiverId =
        userData['caregiverId'] as String?;

    final batch = _firestore.batch();

    // 1. Remove caregiverId from parent's doc
    batch.update(
      _firestore.collection('users').doc(parentUid),
      {
        'caregiverId': FieldValue.delete(),
        'connectedAt': FieldValue.delete(),
      },
    );

    if (caregiverId != null &&
        caregiverId.isNotEmpty) {
      // 2. Find and delete parent doc from parents collection
      final parentSnap = await _firestore
          .collection('parents')
          .where('caregiverId', isEqualTo: caregiverId)
          .get();

      for (final doc in parentSnap.docs) {
        batch.delete(doc.reference);
      }

      // 3. Find and delete pairing codes
      final codeSnap = await _firestore
          .collection('pairing_codes')
          .where('caregiverId', isEqualTo: caregiverId)
          .get();

      for (final doc in codeSnap.docs) {
        batch.delete(doc.reference);
      }

      // 4. Update caregiver's doc
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

  // ── Connect via pairing code ───────────────────────
  // Parent enters a code to connect to a caregiver
  // without logging out
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
      // 1. Find the code
      final codeDoc = await _firestore
          .collection('pairing_codes')
          .doc(trimmed)
          .get();

      if (!codeDoc.exists) {
        return ConnectResult.error(
            'Invalid pairing code. Check and try again.');
      }

      final codeData = codeDoc.data()!;

      // 2. Check if already used
      if (codeData['isUsed'] == true) {
        return ConnectResult.error(
            'This code has already been used.');
      }

      // 3. Check expiry if set
      final expiresAt =
          codeData['expiresAt'] as Timestamp?;
      if (expiresAt != null &&
          expiresAt.toDate().isBefore(DateTime.now())) {
        return ConnectResult.error(
            'This code has expired. Ask your caregiver to generate a new one.');
      }

      final caregiverId =
          codeData['caregiverId'] as String?;
      if (caregiverId == null) {
        return ConnectResult.error(
            'Invalid code data. Try again.');
      }

      final batch = _firestore.batch();

      // 4. Mark code as used
      batch.update(codeDoc.reference, {
        'isUsed': true,
      });

      // 5. Update caregiver's doc
      batch.update(
        _firestore
            .collection('users')
            .doc(caregiverId),
        {'parentLinked': true},
      );

      // 6. Link parent to caregiver
      batch.update(
        _firestore.collection('users').doc(uid),
        {
          'caregiverId': caregiverId,
          'connectedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      // Load caregiver name to show success message
      final caregiverDoc = await _firestore
          .collection('users')
          .doc(caregiverId)
          .get();
      final caregiverName =
          caregiverDoc.data()?['name'] as String? ??
              'Caregiver';

      debugPrint(
          '[ConnectionService] Parent connected to $caregiverName');

      return ConnectResult.success(caregiverName);
    } catch (e) {
      debugPrint(
          '[ConnectionService] Connect error: $e');
      return ConnectResult.error(
          'Something went wrong. Please try again.');
    }
  }
}

// Result class for connectWithCode
class ConnectResult {
  final bool success;
  final String message; // caregiver name or error msg

  ConnectResult._({
    required this.success,
    required this.message,
  });

  factory ConnectResult.success(String caregiverName) =>
      ConnectResult._(
          success: true, message: caregiverName);

  factory ConnectResult.error(String error) =>
      ConnectResult._(success: false, message: error);
}