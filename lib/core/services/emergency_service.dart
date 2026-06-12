// lib/core/services/emergency_service.dart
// Auto-connect flow: receiver auto-joins when call is created
// No accept/decline buttons needed

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:healthconnect/models/emergency_contact_model.dart';
import 'package:healthconnect/core/services/agora_token_service.dart';
import 'package:healthconnect/core/services/sos_notification_service.dart';

class EmergencyService {
  static final EmergencyService _instance =
      EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _activeCallId;
  StreamSubscription? _callStatusSubscription;
  Timer? _fallbackTimer;

  String? get activeCallId => _activeCallId;

  Future<void> saveFcmToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (kIsWeb) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS
             ? 'ios'
             : 'android',  
      'updatedAt': FieldValue.serverTimestamp(),
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _firestore
          .collection('users')
          .doc(uid)
          .update({'fcmToken': newToken});
    });
  }

  Future<Map<String, dynamic>?> _getCurrentUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc =
        await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<String?> _getCaregiverId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final data = await _getCurrentUserData();
    if (data == null) return null;

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

  Future<bool> isPaired() async {
    final data = await _getCurrentUserData();
    if (data == null) return false;

    final role = data['role'] as String? ?? '';

    if (role == 'caregiver') {
      return data['parentLinked'] == true;
    }

    if (role == 'parent') {
      final caregiverId = data['caregiverId'] as String?;
      return caregiverId != null && caregiverId.isNotEmpty;
    }

    return false;
  }

  Future<Map<String, dynamic>?> _getPairedPersonInfo() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final data = await _getCurrentUserData();
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
      if (q.docs.isNotEmpty) pairedUid = q.docs.first.id;
    }

    if (pairedUid.isEmpty) return null;

    final pairedDoc =
        await _firestore.collection('users').doc(pairedUid).get();
    if (!pairedDoc.exists) return null;

    return {'uid': pairedUid, 'data': pairedDoc.data()};
  }

  // ── CHILD (caregiver) presses CALL HELP ──────────────
  // ✅ Status set to 'accepted' immediately
  // Receiver auto-joins without pressing any button
  Future<String?> initiateChildEmergency({
    required String callerName,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final pairedInfo = await _getPairedPersonInfo();
    if (pairedInfo == null) {
      debugPrint('[EmergencyService] No paired parent found');
      return null;
    }

    final receiverId = pairedInfo['uid'] as String;
    final receiverData =
        pairedInfo['data'] as Map<String, dynamic>?;
    final receiverFcmToken =
        receiverData?['fcmToken'] as String?;

    final channel = AgoraConfig.generateChannelName();
    final token = await AgoraConfig.getToken(channel, uid);

    // ✅ Status = 'accepted' from the start
    // No ringing state needed — auto-connect flow
    final docRef =
        await _firestore.collection('emergency_calls').add({
      'callerId': uid,
      'callerName': callerName,
      'callerRole': 'child',
      'receiverId': receiverId,
      'caregiverId': receiverId,
      'status': 'accepted',
      'agoraChannel': channel,
      'agoraToken': token,
      'fallbackAttempt': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': FieldValue.serverTimestamp(),
      'endedAt': null,
    });

    _activeCallId = docRef.id;

    // Send FCM to receiver — they auto-join on notification
    if (receiverFcmToken != null) {
      final receiverPlatform =
          receiverData?['platform'] as String? ?? 'android';
      await SosNotificationService().sendEmergencyNotification(
        toToken: receiverFcmToken,
        toPlatform: receiverPlatform,
        callId: docRef.id,
        callerName: callerName,
        callerRole: 'child',
        agoraChannel: channel,
        agoraToken: token,
      );
    }

    return docRef.id;
  }

  // ── PARENT presses CALL HELP ──────────────────────────
  // ✅ Status set to 'accepted' immediately
  Future<String?> initiateParentEmergency({
    required String callerName,
    required EmergencyContacts contacts,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final pairedInfo = await _getPairedPersonInfo();
    final channel = AgoraConfig.generateChannelName();
    final token = await AgoraConfig.getToken(channel, uid);
    final receiverId = pairedInfo?['uid'] as String? ?? '';

    final docRef =
        await _firestore.collection('emergency_calls').add({
      'callerId': uid,
      'callerName': callerName,
      'callerRole': 'parent',
      'receiverId': receiverId,
      'caregiverId': uid,
      'status': 'accepted',
      'agoraChannel': channel,
      'agoraToken': token,
      'fallbackAttempt': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': FieldValue.serverTimestamp(),
      'endedAt': null,
    });

    _activeCallId = docRef.id;

    // Notify paired caregiver first
    if (pairedInfo != null) {
      final receiverData =
          pairedInfo['data'] as Map<String, dynamic>?;
      final receiverFcmToken =
          receiverData?['fcmToken'] as String?;

if (receiverFcmToken != null) {
        final receiverPlatform =
            receiverData?['platform'] as String? ?? 'android';
        await SosNotificationService()
            .sendEmergencyNotification(
          toToken: receiverFcmToken,
          toPlatform: receiverPlatform,
          callId: docRef.id,
          callerName: callerName,
          callerRole: 'parent',
          agoraChannel: channel,
          agoraToken: token,
        );
      }
    }

    return docRef.id;
  }

  // Notify fallback phone contacts (non-app)
  Future<void> _notifyFallbackContacts({
    required EmergencyContacts contacts,
    required String callerName,
  }) async {
    for (final contact in [
      contacts.secondary,
      contacts.tertiary,
    ]) {
      if (contact == null) continue;

      if (contact.fcmToken != null &&
          contact.fcmToken!.isNotEmpty) {
        // App user — handled via FCM already
        continue;
      }

      if (contact.phone.isNotEmpty) {
        // Non-app contact — open phone dialer
        final uri = Uri.parse('tel:${contact.phone}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          break; // Only call one at a time
        }
      }
    }
  }

  Future<void> endCall(String callId) async {
    _fallbackTimer?.cancel();
    _callStatusSubscription?.cancel();
    _activeCallId = null;
    await _firestore
        .collection('emergency_calls')
        .doc(callId)
        .update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  // Keep acceptCall for backward compatibility
  // (callkit_handler still calls this)
  Future<void> acceptCall(String callId) async {
    await _firestore
        .collection('emergency_calls')
        .doc(callId)
        .update({
      'status': 'accepted',
      'answeredAt': FieldValue.serverTimestamp(),
    });
    _activeCallId = callId;
  }

  Future<void> rejectCall(String callId) async {
    await _firestore
        .collection('emergency_calls')
        .doc(callId)
        .update({
      'status': 'rejected',
      'endedAt': FieldValue.serverTimestamp(),
    });
    _activeCallId = null;
    _fallbackTimer?.cancel();
  }

  Stream<EmergencyCall?> callStream(String callId) {
    return _firestore
        .collection('emergency_calls')
        .doc(callId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return EmergencyCall.fromFirestore(
          snap.data()!, snap.id);
    });
  }
    // ── Get currently active call by stored ID ────────
Future<EmergencyCall?> getActiveCall() async {
  if (_activeCallId == null) return null;
  try {
    final doc = await _firestore
        .collection('emergency_calls')
        .doc(_activeCallId)
        .get();
    if (!doc.exists) return null;
    final call = EmergencyCall.fromFirestore(
        doc.data()!, doc.id);
    if (call.status == CallStatus.ended) return null;
    return call;
  } catch (e) {
    debugPrint('[EmergencyService] getActiveCall: $e');
    return null;
  }
}
  // ✅ Stream now listens for 'accepted' status
  // instead of 'ringing' — auto-joins on notification
  Stream<EmergencyCall?> incomingCallStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _firestore
        .collection('emergency_calls')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      final call = EmergencyCall.fromFirestore(
          doc.data(), doc.id);

      // Only return calls from last 2 minutes
      // to avoid rejoining old ended calls
      final age = DateTime.now()
          .difference(call.createdAt)
          .inMinutes;
      if (age > 2) return null;

      return call;
    });
  }

  Future<EmergencyContacts?> loadContacts() async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return null;

    final doc = await _firestore
        .collection('emergency_contacts')
        .doc(caregiverId)
        .get();

    if (!doc.exists) {
      return EmergencyContacts(uid: caregiverId);
    }
    return EmergencyContacts.fromFirestore(
        doc.data()!, caregiverId);
  }

  Future<void> saveContacts(
      EmergencyContacts contacts) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    await _firestore
        .collection('emergency_contacts')
        .doc(caregiverId)
        .set(contacts.toMap(), SetOptions(merge: true));
  }

  void dispose() {
    _callStatusSubscription?.cancel();
    _fallbackTimer?.cancel();
  }
}