// lib/core/services/callkit_handler.dart

import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/core/services/ringtone_service.dart';
import 'package:healthconnect/features/emergency/active_call_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CallKitHandler {
  static final CallKitHandler _instance =
      CallKitHandler._internal();
  factory CallKitHandler() => _instance;
  CallKitHandler._internal();

  final _emergencyService = EmergencyService();
  final _agoraService = AgoraCallService();
  final _ringtoneService = RingtoneService();

  static GlobalKey<NavigatorState>? navigatorKey;

  void initialize() {
    FlutterCallkitIncoming.onEvent.listen(
        (event) async {
      if (event == null) return;

      final body =
          event.body as Map<dynamic, dynamic>? ?? {};
      final extra =
          body['extra'] as Map<dynamic, dynamic>? ?? {};
      final callId = extra['callId'] as String? ??
          body['id'] as String? ??
          '';
      final channel =
          extra['agoraChannel'] as String? ?? '';
      final token =
          extra['agoraToken'] as String? ?? '';

      debugPrint(
          '[CallKitHandler] event=${event.event} '
          'callId=$callId');

      final eventName = event.event.toString();

      if (eventName.contains('actionCallAccept')) {
        // ✅ User tapped Accept on native CallKit UI
        // Join Agora and open ActiveCallScreen
        await _ringtoneService.stopRinging();
        if (callId.isEmpty) return;

        await _emergencyService.acceptCall(callId);

        try {
          await _agoraService.initialize();
        } catch (e) {
          debugPrint(
              '[CallKitHandler] Agora init: $e');
        }

        try {
          await _agoraService.joinChannel(
            channelName: channel,
            token: token,
            uid: callId,
          );
        } catch (e) {
          debugPrint(
              '[CallKitHandler] Join error: $e');
          return;
        }

        // Get call data to pass to ActiveCallScreen
        final call = await _emergencyService
            .callStream(callId)
            .first;
        if (call == null) return;

        
        // Detect role
        // ignore: unused_local_variable
        bool isCaregiver = false;
        try {
          final uid =
              FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();
            isCaregiver =
                (doc.data()?['role'] as String? ??
                        '') ==
                    'caregiver';
          }
        } catch (e) {
          debugPrint('[CallKitHandler] Role: $e');
        }

        // Navigate to ActiveCallScreen
        // Works whether app was foreground or cold start
        final context =
            navigatorKey?.currentContext;
        if (context != null) {
          Navigator.of(context, rootNavigator: true)
              .push(
            MaterialPageRoute(
              builder: (_) => ActiveCallScreen(
                call: call,
                agoraService: _agoraService,
                isIncoming: true,
              ),
            ),
          );
        }
      } else if (eventName
          .contains('actionCallDecline')) {
        await _ringtoneService.stopRinging();
        if (callId.isNotEmpty) {
          await _emergencyService.endCall(callId);
        }
      } else if (eventName
          .contains('actionCallEnded')) {
        await _ringtoneService.stopRinging();
        if (callId.isNotEmpty) {
          await _emergencyService.endCall(callId);
        }
        await _agoraService.leaveChannel();
      } else if (eventName
          .contains('actionCallIncoming')) {
        await _ringtoneService.startRinging();
      } else if (eventName
          .contains('actionCallTimeout')) {
        await _ringtoneService.stopRinging();
        if (callId.isNotEmpty) {
          await _emergencyService.endCall(callId);
        }
      }
    });
  }

  // ✅ Check if app was cold-started from a CallKit action
  // Returns call data if yes, null if normal launch
  Future<Map<String, dynamic>?> getInitialCallData() async {
    try {
      final calls =
          await FlutterCallkitIncoming.activeCalls();
      if (calls == null || calls.isEmpty) return null;

      // There's an active call from a previous CallKit event
      final call = calls.first as Map<dynamic, dynamic>;
      final extra =
          call['extra'] as Map<dynamic, dynamic>? ?? {};

      final callId = extra['callId'] as String?;
      if (callId == null || callId.isEmpty) return null;

      return {
        'callId': callId,
        'agoraChannel': extra['agoraChannel'] ?? '',
        'agoraToken': extra['agoraToken'] ?? '',
      };
    } catch (e) {
      debugPrint(
          '[CallKitHandler] getInitialCallData: $e');
      return null;
    }
  }
}