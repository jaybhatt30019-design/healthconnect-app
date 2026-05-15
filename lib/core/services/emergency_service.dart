// lib/core/services/emergency_service.dart

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
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _activeCallId;
  StreamSubscription? _callStatusSubscription;
  Timer? _fallbackTimer;

  String? get activeCallId => _activeCallId;

  // ─────────────────────────────────────────────────────
  // Save FCM token on every launch
  // ─────────────────────────────────────────────────────
  Future<void> saveFcmToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (kIsWeb) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _firestore.collection('users').doc(uid).update({'fcmToken': newToken});
    });
  }

  // ─────────────────────────────────────────────────────
  // Get current user data
  // ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _getCurrentUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  // ─────────────────────────────────────────────────────
  // Get caregiverId for current user
  //
  // Caregiver           → own uid
  // Parent paired       → caregiverId from user doc
  // Parent NOT paired   → own uid (so contacts/data still work)
  //
  // ─────────────────────────────────────────────────────
  Future<String?> _getCaregiverId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final data = await _getCurrentUserData();
    if (data == null) return null;

    final role = data['role'] as String? ?? '';

    if (role == 'caregiver') return uid;

    if (role == 'parent') {
      final caregiverId = data['caregiverId'] as String?;
      if (caregiverId != null && caregiverId.isNotEmpty) return caregiverId;
      // ✅ Parent alone — use own uid so contacts/data still work
      return uid;
    }

    return uid;
  }

  // ─────────────────────────────────────────────────────
  // Check if current user is paired
  // Used by UI to show/hide features that need pairing
  // ─────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────
  // Get paired person info (null if not paired)
  // ─────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────
  // CHILD (caregiver) presses CALL HELP
  // ─────────────────────────────────────────────────────
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
    final receiverData = pairedInfo['data'] as Map<String, dynamic>?;
    final receiverFcmToken = receiverData?['fcmToken'] as String?;

    final channel = AgoraConfig.generateChannelName();
    final token = await AgoraConfig.getToken(channel, uid);

    final docRef = await _firestore.collection('emergency_calls').add({
      'callerId': uid,
      'callerName': callerName,
      'callerRole': 'child',
      'receiverId': receiverId,
      'caregiverId': receiverId,
      'status': 'ringing',
      'agoraChannel': channel,
      'agoraToken': token,
      'fallbackAttempt': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': null,
      'endedAt': null,
    });

    _activeCallId = docRef.id;

    if (receiverFcmToken != null) {
      await SosNotificationService().sendEmergencyNotification(
        toToken: receiverFcmToken,
        callId: docRef.id,
        callerName: callerName,
        callerRole: 'child',
        agoraChannel: channel,
        agoraToken: token,
      );
    }

    _listenForCallStatus(docRef.id);
    return docRef.id;
  }

  // ─────────────────────────────────────────────────────
  // PARENT presses CALL HELP
  // Works with or without a paired caregiver.
  // Falls back through contacts automatically.
  // Non-app contacts open phone dialer.
  // ─────────────────────────────────────────────────────
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

    final docRef = await _firestore.collection('emergency_calls').add({
      'callerId': uid,
      'callerName': callerName,
      'callerRole': 'parent',
      'receiverId': receiverId,
      'caregiverId': uid,
      'status': 'ringing',
      'agoraChannel': channel,
      'agoraToken': token,
      'fallbackAttempt': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': null,
      'endedAt': null,
    });

    _activeCallId = docRef.id;

    await _dialContact(
      callId: docRef.id,
      contact: contacts.primary,
      attempt: 0,
      contacts: contacts,
      channel: channel,
      token: token,
      callerName: callerName,
    );

    return docRef.id;
  }

  // ─────────────────────────────────────────────────────
  // Dial a contact — in-app FCM or phone dialer
  // ─────────────────────────────────────────────────────
  Future<void> _dialContact({
    required String callId,
    required EmergencyContactEntry? contact,
    required int attempt,
    required EmergencyContacts contacts,
    required String channel,
    required String token,
    required String callerName,
  }) async {
    if (contact == null) {
      await _firestore.collection('emergency_calls').doc(callId).update({
        'status': 'missed',
        'endedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await _firestore.collection('emergency_calls').doc(callId).update({
      'fallbackAttempt': attempt,
      'status': 'ringing',
    });

    if (contact.fcmToken != null && contact.fcmToken!.isNotEmpty) {
      // In-app call via FCM
      await SosNotificationService().sendEmergencyNotification(
        toToken: contact.fcmToken!,
        callId: callId,
        callerName: callerName,
        callerRole: 'parent',
        agoraChannel: channel,
        agoraToken: token,
      );
    } else if (contact.phone.isNotEmpty) {
      // Non-app contact — open phone dialer
      final uri = Uri.parse('tel:${contact.phone}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }

    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 15), () async {
      final doc = await _firestore
          .collection('emergency_calls')
          .doc(callId)
          .get();
      final status = doc.data()?['status'] as String?;

      if (status == 'ringing') {
        final nextAttempt = attempt + 1;
        EmergencyContactEntry? nextContact;
        if (nextAttempt == 1) nextContact = contacts.secondary;
        if (nextAttempt == 2) nextContact = contacts.tertiary;

        await _dialContact(
          callId: callId,
          contact: nextContact,
          attempt: nextAttempt,
          contacts: contacts,
          channel: channel,
          token: token,
          callerName: callerName,
        );
      }
    });

    _listenForCallStatus(callId);
  }

  void _listenForCallStatus(String callId) {
    _callStatusSubscription?.cancel();
    _callStatusSubscription = _firestore
        .collection('emergency_calls')
        .doc(callId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final status = snap.data()?['status'] as String?;
      if (status == 'accepted' ||
          status == 'ended' ||
          status == 'rejected') {
        _fallbackTimer?.cancel();
      }
    });
  }

  Future<void> acceptCall(String callId) async {
    await _firestore.collection('emergency_calls').doc(callId).update({
      'status': 'accepted',
      'answeredAt': FieldValue.serverTimestamp(),
    });
    _activeCallId = callId;
  }

  Future<void> rejectCall(String callId) async {
    await _firestore.collection('emergency_calls').doc(callId).update({
      'status': 'rejected',
      'endedAt': FieldValue.serverTimestamp(),
    });
    _activeCallId = null;
    _fallbackTimer?.cancel();
  }

  Future<void> endCall(String callId) async {
    _fallbackTimer?.cancel();
    _callStatusSubscription?.cancel();
    _activeCallId = null;
    await _firestore.collection('emergency_calls').doc(callId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<EmergencyCall?> callStream(String callId) {
    return _firestore
        .collection('emergency_calls')
        .doc(callId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return EmergencyCall.fromFirestore(snap.data()!, snap.id);
    });
  }

  Stream<EmergencyCall?> incomingCallStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _firestore
        .collection('emergency_calls')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return EmergencyCall.fromFirestore(doc.data(), doc.id);
    });
  }

  // ─────────────────────────────────────────────────────
  // Emergency contacts — stored under caregiverId
  // Works for unpaired users too (caregiverId = own uid)
  // ─────────────────────────────────────────────────────
  Future<EmergencyContacts?> loadContacts() async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return null;

    final doc = await _firestore
        .collection('emergency_contacts')
        .doc(caregiverId)
        .get();

    if (!doc.exists) return EmergencyContacts(uid: caregiverId);
    return EmergencyContacts.fromFirestore(doc.data()!, caregiverId);
  }

  Future<void> saveContacts(EmergencyContacts contacts) async {
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