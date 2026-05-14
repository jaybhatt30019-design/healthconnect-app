import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:healthconnect/models/emergency_contact_model.dart';
import 'package:healthconnect/core/services/agora_token_service.dart';
import 'package:healthconnect/core/services/notification_service.dart';

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Active call state
  String? _activeCallId;
  StreamSubscription? _callStatusSubscription;
  Timer? _fallbackTimer;

  String? get activeCallId => _activeCallId;

  // ─────────────────────────────────────────────────────
  // STEP 1: Save FCM token to Firestore on every launch
  // ─────────────────────────────────────────────────────
  Future<void> saveFcmToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
    });

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _firestore.collection('users').doc(uid).update({'fcmToken': newToken});
    });
  }

  // ─────────────────────────────────────────────────────
  // STEP 2: Get paired person's info
  // ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _getPairedPersonInfo() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final data = userDoc.data();
    if (data == null) return null;

    final role = data['role'] as String;
    String pairedUid;

    if (role == 'parent') {
      pairedUid = data['caregiverId'] ?? '';
    } else {
      // caregiver — find linked parent
      final parentQuery = await _firestore
          .collection('users')
          .where('caregiverId', isEqualTo: uid)
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();

      if (parentQuery.docs.isEmpty) return null;
      pairedUid = parentQuery.docs.first.id;
    }

    if (pairedUid.isEmpty) return null;

    final pairedDoc = await _firestore.collection('users').doc(pairedUid).get();
    return {
      'uid': pairedUid,
      'data': pairedDoc.data(),
    };
  }

  // ─────────────────────────────────────────────────────
  // STEP 3A: CHILD presses CALL HELP
  // Creates call doc, notifies parent
  // ─────────────────────────────────────────────────────
  Future<String?> initiateChildEmergency({required String callerName}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final pairedInfo = await _getPairedPersonInfo();
    if (pairedInfo == null) {
      debugPrint('[Emergency] No paired caregiver found');
      return null;
    }

    final caregiverId = pairedInfo['uid'] as String;
    final caregiverData = pairedInfo['data'] as Map<String, dynamic>?;
    final caregiverFcmToken = caregiverData?['fcmToken'] as String?;

    // Generate Agora channel
    final channel = AgoraConfig.generateChannelName();
    final token = await AgoraConfig.getToken(channel, uid);

    // Create Firestore call doc
    final docRef = await _firestore.collection('emergency_calls').add({
      'callerId': uid,
      'callerName': callerName,
      'callerRole': 'child',
      'receiverId': caregiverId,
      'caregiverId': caregiverId,
      'status': 'ringing',
      'agoraChannel': channel,
      'agoraToken': token,
      'fallbackAttempt': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': null,
      'endedAt': null,
    });

    _activeCallId = docRef.id;

    // Send FCM to parent
    if (caregiverFcmToken != null) {
      await NotificationService().sendEmergencyNotification(
        toToken: caregiverFcmToken,
        callId: docRef.id,
        callerName: callerName,
        callerRole: 'child',
        agoraChannel: channel,
        agoraToken: token,
      );
    }

    // Start listening for status changes (so child knows if accepted/rejected)
    _listenForCallStatus(docRef.id);

    return docRef.id;
  }

  // ─────────────────────────────────────────────────────
  // STEP 3B: PARENT presses CALL HELP
  // Automatic fallback through contacts
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

    // Create call doc
    final docRef = await _firestore.collection('emergency_calls').add({
      'callerId': uid,
      'callerName': callerName,
      'callerRole': 'parent',
      'receiverId': receiverId,
      'caregiverId': uid, // parent is always the caregiver-scope key here
      'status': 'ringing',
      'agoraChannel': channel,
      'agoraToken': token,
      'fallbackAttempt': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': null,
      'endedAt': null,
    });

    _activeCallId = docRef.id;

    // Dial primary contact (paired child) first
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
  // Auto-fallback dialing logic
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
      // No more contacts → mark missed
      await _firestore.collection('emergency_calls').doc(callId).update({
        'status': 'missed',
        'endedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Update fallback attempt
    await _firestore.collection('emergency_calls').doc(callId).update({
      'fallbackAttempt': attempt,
      'status': 'ringing',
    });

    // If contact has FCM token → in-app call
    if (contact.fcmToken != null) {
      await NotificationService().sendEmergencyNotification(
        toToken: contact.fcmToken!,
        callId: callId,
        callerName: callerName,
        callerRole: 'parent',
        agoraChannel: channel,
        agoraToken: token,
      );
    }

    // Cancel any existing timer
    _fallbackTimer?.cancel();

    // Wait 15 seconds, then try next contact if not answered
    _fallbackTimer = Timer(const Duration(seconds: 15), () async {
      final doc = await _firestore.collection('emergency_calls').doc(callId).get();
      final status = doc.data()?['status'] as String?;

      // If still ringing (not answered), try next
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

  // ─────────────────────────────────────────────────────
  // Listen to call status in real time
  // ─────────────────────────────────────────────────────
  void _listenForCallStatus(String callId) {
    _callStatusSubscription?.cancel();
    _callStatusSubscription = _firestore
        .collection('emergency_calls')
        .doc(callId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final status = snap.data()?['status'] as String?;

      if (status == 'accepted' || status == 'ended' || status == 'rejected') {
        _fallbackTimer?.cancel();
      }
    });
  }

  // ─────────────────────────────────────────────────────
  // Accept incoming call (called by receiver)
  // ─────────────────────────────────────────────────────
  Future<void> acceptCall(String callId) async {
    await _firestore.collection('emergency_calls').doc(callId).update({
      'status': 'accepted',
      'answeredAt': FieldValue.serverTimestamp(),
    });
    _activeCallId = callId;
  }

  // ─────────────────────────────────────────────────────
  // Reject incoming call
  // ─────────────────────────────────────────────────────
  Future<void> rejectCall(String callId) async {
    await _firestore.collection('emergency_calls').doc(callId).update({
      'status': 'rejected',
      'endedAt': FieldValue.serverTimestamp(),
    });
    _activeCallId = null;
    _fallbackTimer?.cancel();
  }

  // ─────────────────────────────────────────────────────
  // End active call
  // ─────────────────────────────────────────────────────
  Future<void> endCall(String callId) async {
    _fallbackTimer?.cancel();
    _callStatusSubscription?.cancel();
    _activeCallId = null;

    await _firestore.collection('emergency_calls').doc(callId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────
  // Get real-time stream of an active call
  // ─────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────
  // Load emergency contacts for current user
  // ─────────────────────────────────────────────────────
  Future<EmergencyContacts?> loadContacts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('emergency_contacts').doc(uid).get();
    if (!doc.exists) return EmergencyContacts(uid: uid);

    return EmergencyContacts.fromFirestore(doc.data()!, uid);
  }

  // ─────────────────────────────────────────────────────
  // Save secondary/tertiary contacts
  // ─────────────────────────────────────────────────────
  Future<void> saveContacts(EmergencyContacts contacts) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('emergency_contacts')
        .doc(uid)
        .set(contacts.toMap(), SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────
  // Listen for INCOMING calls (for receiver side)
  // ─────────────────────────────────────────────────────
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

  void dispose() {
    _callStatusSubscription?.cancel();
    _fallbackTimer?.cancel();
  }
}