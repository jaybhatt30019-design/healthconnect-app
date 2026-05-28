// lib/core/services/callkit_handler.dart
// ✅ Auto-connect — no Answer button required
// When CallKit fires actionCallIncoming → start 5s timer
// After 5s → join Agora → wake screen → ActiveCallScreen
// If user taps Answer before 5s → join immediately
// If user taps Decline → end call only

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/core/services/ringtone_service.dart';
import 'package:healthconnect/features/emergency/active_call_screen.dart';
import 'package:healthconnect/models/emergency_call_model.dart';

class CallKitHandler {
  static final CallKitHandler _instance =
      CallKitHandler._internal();
  factory CallKitHandler() => _instance;
  CallKitHandler._internal();

  final _emergencyService = EmergencyService();
  final _agoraService = AgoraCallService();
  final _ringtoneService = RingtoneService();

  static GlobalKey<NavigatorState>? navigatorKey;
  static bool isHandlingCall = false;

  // ✅ Timer for auto-connect after 5 seconds
  Timer? _autoConnectTimer;
  bool _hasConnected = false;

  void initialize() {
    FlutterCallkitIncoming.onEvent.listen(
        (event) async {
      if (event == null) return;

      final body =
          event.body as Map<dynamic, dynamic>? ?? {};
      final extra =
          body['extra'] as Map<dynamic, dynamic>? ?? {};

      final callId = extra['callId'] as String? ??
          body['id'] as String? ?? '';
      final channel =
          extra['agoraChannel'] as String? ?? '';
      final token =
          extra['agoraToken'] as String? ?? '';
      final callerRole =
          extra['callerRole'] as String? ?? 'child';

      final eventName = event.event.toString();
      debugPrint(
          '[CallKitHandler] event=$eventName '
          'callId=$callId callerRole=$callerRole');

      // ── Call incoming ───────────────────────────
      // ✅ Start 5 second auto-connect timer
      if (eventName.contains('actionCallIncoming')) {
        isHandlingCall = true;
        _hasConnected = false;
        await _ringtoneService.startRinging();

        // ✅ Auto-connect after 5 seconds
        _autoConnectTimer?.cancel();
        _autoConnectTimer = Timer(
          const Duration(seconds: 5),
          () => _doConnect(
            callId: callId,
            channel: channel,
            token: token,
            callerRole: callerRole,
          ),
        );
      }

      // ── User tapped Answer before 5s ───────────
      // Connect immediately
      else if (eventName
          .contains('actionCallAccept')) {
        _autoConnectTimer?.cancel();
        await _doConnect(
          callId: callId,
          channel: channel,
          token: token,
          callerRole: callerRole,
        );
      }

      // ── User tapped Decline ─────────────────────
      else if (eventName
          .contains('actionCallDecline')) {
        _autoConnectTimer?.cancel();
        isHandlingCall = false;
        _hasConnected = false;
        await _ringtoneService.stopRinging();
        await FlutterCallkitIncoming.endAllCalls();
        if (callId.isNotEmpty) {
          await _emergencyService.endCall(callId);
        }
      }

      // ── Call ended ──────────────────────────────
      else if (eventName
          .contains('actionCallEnded')) {
        _autoConnectTimer?.cancel();
        isHandlingCall = false;
        _hasConnected = false;
        await _ringtoneService.stopRinging();
        await FlutterCallkitIncoming.endAllCalls();
        if (callId.isNotEmpty) {
          await _emergencyService.endCall(callId);
        }
        await _agoraService.leaveChannel();
      }

      // ── Timeout ─────────────────────────────────
      else if (eventName
          .contains('actionCallTimeout')) {
        // Timer already handles this — no-op
      }
    });
  }

  // ── Core connect logic ────────────────────────────
  // Called after 5s timer OR on Answer tap
  Future<void> _doConnect({
    required String callId,
    required String channel,
    required String token,
    required String callerRole,
  }) async {
    if (_hasConnected) return;
    _hasConnected = true;

    await _ringtoneService.stopRinging();
    await FlutterCallkitIncoming.endAllCalls();

    if (callId.isEmpty) {
      isHandlingCall = false;
      return;
    }

    await _emergencyService.acceptCall(callId);

    try {
      await _agoraService.initialize();
      await _agoraService.joinChannel(
        channelName: channel,
        token: token,
        uid: callId,
      );
    } catch (e) {
      debugPrint(
          '[CallKitHandler] Join error: $e');
      isHandlingCall = false;
      return;
    }

    EmergencyCall? call;
    try {
      call = await _emergencyService
          .callStream(callId)
          .first;
    } catch (e) {
      debugPrint(
          '[CallKitHandler] Get call: $e');
    }

    if (call == null) {
      isHandlingCall = false;
      return;
    }

    // ✅ callerRole == child → caregiver called parent
    //    parent receives → playArrivalSound=true
    //    no fallback button
    // callerRole == parent → parent called caregiver
    //    caregiver receives → no sound, no fallback
    final isParentCalling = callerRole == 'parent';
    final isCaregiverCalling = callerRole == 'child';

    // Navigate with retry loop for cold start
    bool navigated = false;
    for (int i = 0; i < 15; i++) {
      final context = navigatorKey?.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context, rootNavigator: true)
            .pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ActiveCallScreen(
              call: call!,
              agoraService: _agoraService,
              isIncoming: true,
              // ✅ No fallback button in any
              // auto-connect scenario from CallKit
              showFallbackButton: false,
              // ✅ Play arrival sound only when
              // caregiver called parent (parent receives)
              playArrivalSound: isCaregiverCalling,
            ),
          ),
          (route) => false,
        );
        navigated = true;
        break;
      }
      await Future.delayed(
          const Duration(milliseconds: 300));
    }

    if (!navigated) {
      debugPrint(
          '[CallKitHandler] Navigator not ready');
    }

    isHandlingCall = false;
  }

  // ── Cold start handler ────────────────────────────
  Future<void> handleColdStartIfNeeded() async {
    try {
      final calls =
          await FlutterCallkitIncoming.activeCalls();
      if (calls == null || calls.isEmpty) return;

      final call =
          calls.first as Map<dynamic, dynamic>;
      final extra =
          call['extra'] as Map<dynamic, dynamic>? ??
              {};

      final callId = extra['callId'] as String?;
      if (callId == null || callId.isEmpty) return;

      final channel =
          extra['agoraChannel'] as String? ?? '';
      final token =
          extra['agoraToken'] as String? ?? '';
      final callerRole =
          extra['callerRole'] as String? ?? 'child';

      debugPrint(
          '[CallKitHandler] Cold start callId=$callId');

      isHandlingCall = true;

      // ✅ On cold start — wait 500ms for app to load
      // then auto-connect without any user input
      await Future.delayed(
          const Duration(milliseconds: 500));

      await _doConnect(
        callId: callId,
        channel: channel,
        token: token,
        callerRole: callerRole,
      );
    } catch (e) {
      debugPrint(
          '[CallKitHandler] Cold start error: $e');
      isHandlingCall = false;
    }
  }

  Future<Map<String, dynamic>?>
      getInitialCallData() async {
    try {
      final calls =
          await FlutterCallkitIncoming.activeCalls();
      if (calls == null || calls.isEmpty) return null;

      final call =
          calls.first as Map<dynamic, dynamic>;
      final extra =
          call['extra'] as Map<dynamic, dynamic>? ??
              {};
      final callId = extra['callId'] as String?;
      if (callId == null || callId.isEmpty) return null;

      return {
        'callId': callId,
        'agoraChannel': extra['agoraChannel'] ?? '',
        'agoraToken': extra['agoraToken'] ?? '',
        'callerRole': extra['callerRole'] ?? 'child',
      };
    } catch (e) {
      return null;
    }
  }
}