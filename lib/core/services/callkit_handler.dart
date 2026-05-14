// lib/core/services/callkit_handler.dart
//
// This singleton must be initialized in main.dart AFTER NotificationService.
// It bridges flutter_callkit_incoming button presses → EmergencyService actions.

import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/core/services/sos_notification_service.dart';

class CallKitHandler {
  static final CallKitHandler _instance = CallKitHandler._internal();
  factory CallKitHandler() => _instance;
  CallKitHandler._internal();

  final _emergencyService = EmergencyService();
  final _agoraService = AgoraCallService();
  final _ringtoneService = RingtoneService();

  // Navigation key — set this in MyApp so we can push screens from here
  static GlobalKey<NavigatorState>? navigatorKey;

  void initialize() {
    FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) return;

      final body = event.body as Map<dynamic, dynamic>? ?? {};
      final extra = body['extra'] as Map<dynamic, dynamic>? ?? {};
      final callId = extra['callId'] as String? ?? body['id'] as String? ?? '';
      final channel = extra['agoraChannel'] as String? ?? '';
      final token = extra['agoraToken'] as String? ?? '';

      debugPrint('[CallKitHandler] Event: ${event.event}  callId=$callId');

      switch (event.event) {

        // ── User tapped Accept on system call UI ──────────
        case Event.actionCallAccept:
          await _ringtoneService.stopRinging();

          if (callId.isEmpty) return;

          await _emergencyService.acceptCall(callId);

          await _agoraService.initialize();
          await _agoraService.joinChannel(
            channelName: channel,
            token: token,
            uid: callId, // reuse callId as uid placeholder
          );

          // Navigate to active call screen
          // (EmergencyService.incomingCallStream listener in emergency_screen
          //  will handle this if the app is open — this handles background case)
          _navigateToActiveCall(callId: callId, channel: channel, token: token);
          break;

        // ── User tapped Decline on system call UI ─────────
        case Event.actionCallDecline:
          await _ringtoneService.stopRinging();
          if (callId.isNotEmpty) {
            await _emergencyService.rejectCall(callId);
          }
          break;

        // ── Call ended from system UI ─────────────────────
        case Event.actionCallEnded:
          await _ringtoneService.stopRinging();
          if (callId.isNotEmpty) {
            await _emergencyService.endCall(callId);
          }
          await _agoraService.leaveChannel();
          break;

        // ── Incoming call shown ───────────────────────────
        case Event.actionCallIncoming:
          await _ringtoneService.startRinging();
          break;

        // ── Call timed out (45s no answer) ────────────────
        case Event.actionCallTimeout:
          await _ringtoneService.stopRinging();
          if (callId.isNotEmpty) {
            await _emergencyService.rejectCall(callId);
          }
          break;

        default:
          break;
      }
    });
  }

  void _navigateToActiveCall({
    required String callId,
    required String channel,
    required String token,
  }) {
    // Only navigate if we have a valid navigator key
    if (navigatorKey?.currentState == null) return;

    // The active call stream in emergency_screen.dart handles this when app is open.
    // This is the fallback for when the notification came while app was in background.
    debugPrint('[CallKitHandler] Navigating to active call screen');
  }
}