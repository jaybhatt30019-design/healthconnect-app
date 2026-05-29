// lib/core/services/callkit_handler.dart
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

  // ✅ Prevents double listener registration
  bool _initialized = false;

  Timer? _autoConnectTimer;
  bool _hasConnected = false;

  // ✅ Store call data at actionCallIncoming time
  // because actionCallAccept extra map is often empty
  String _pendingCallId = '';
  String _pendingChannel = '';
  String _pendingToken = '';
  String _pendingCallerRole = '';

  void initialize() {
    // ✅ Guard — only register listener once
    if (_initialized) {
      debugPrint('[CallKitHandler] Already initialized — skipping');
      return;
    }
    _initialized = true;

    FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) return;

      final body = event.body as Map<dynamic, dynamic>? ?? {};
      final extra = body['extra'] as Map<dynamic, dynamic>? ?? {};

      final callId = extra['callId'] as String? ??
          body['id'] as String? ?? '';
      final channel = extra['agoraChannel'] as String? ?? '';
      final token = extra['agoraToken'] as String? ?? '';
      final callerRole =
          extra['callerRole'] as String? ?? 'child';

      final eventName = event.event.toString();
      debugPrint(
          '[CallKitHandler] event=$eventName callId=$callId');

      // ── Incoming ────────────────────────────────────
      if (eventName.contains('actionCallIncoming')) {
        isHandlingCall = true;
        _hasConnected = false;

        // ✅ Store for use in actionCallAccept
        _pendingCallId = callId;
        _pendingChannel = channel;
        _pendingToken = token;
        _pendingCallerRole = callerRole;

        await _ringtoneService.startRinging();

        _autoConnectTimer?.cancel();
        _autoConnectTimer = Timer(
          const Duration(seconds: 6),
          () {
            if (_hasConnected) return;
            _doConnect(
              callId: _pendingCallId,
              channel: _pendingChannel,
              token: _pendingToken,
              callerRole: _pendingCallerRole,
            );
          },
        );
      }

      // ── Answer tapped ────────────────────────────────
      else if (eventName.contains('actionCallAccept')) {
        _autoConnectTimer?.cancel();
        if (_hasConnected) return;

        // ✅ Set true BEFORE _doConnect so any actionCallEnded
        // fired during connect is blocked immediately
        _hasConnected = true;

        await _doConnect(
          callId: _pendingCallId.isNotEmpty
              ? _pendingCallId
              : callId,
          channel: _pendingChannel.isNotEmpty
              ? _pendingChannel
              : channel,
          token: _pendingToken.isNotEmpty
              ? _pendingToken
              : token,
          callerRole: _pendingCallerRole.isNotEmpty
              ? _pendingCallerRole
              : callerRole,
        );
      }

      // ── Decline tapped ───────────────────────────────
      else if (eventName.contains('actionCallDecline')) {
        _autoConnectTimer?.cancel();
        isHandlingCall = false;
        await _ringtoneService.stopRinging();
        if (!_hasConnected) {
          final id = _pendingCallId.isNotEmpty
              ? _pendingCallId
              : callId;
          if (id.isNotEmpty) {
            await _emergencyService.endCall(id);
          }
        }
        await FlutterCallkitIncoming.endAllCalls();
        _hasConnected = false;
        _clearPending();
      }

      // ── Call ended ───────────────────────────────────
      else if (eventName.contains('actionCallEnded')) {
        // ✅ If already connected — this is fired by our own
        // endAllCalls() call after navigation. Ignore it.
        if (_hasConnected) {
          debugPrint(
              '[CallKitHandler] actionCallEnded ignored — already connected');
          await _ringtoneService.stopRinging();
          return;
        }
        _autoConnectTimer?.cancel();
        isHandlingCall = false;
        _hasConnected = false;
        await _ringtoneService.stopRinging();
        final id = _pendingCallId.isNotEmpty
            ? _pendingCallId
            : callId;
        if (id.isNotEmpty) {
          await _emergencyService.endCall(id);
        }
        await _agoraService.leaveChannel();
        _clearPending();
      }

      // ── Timeout ──────────────────────────────────────
      else if (eventName.contains('actionCallTimeout')) {}
    });
  }

  void _clearPending() {
    _pendingCallId = '';
    _pendingChannel = '';
    _pendingToken = '';
    _pendingCallerRole = '';
  }

  // ── Core connect ──────────────────────────────────────
  Future<void> _doConnect({
    required String callId,
    required String channel,
    required String token,
    required String callerRole,
  }) async {
    // ✅ _hasConnected already set true by caller in Accept case
    // Set it here too for timer/cold-start cases
    if (!_hasConnected) _hasConnected = true;

    await _ringtoneService.stopRinging();

    if (callId.isEmpty || channel.isEmpty) {
      debugPrint(
          '[CallKitHandler] Missing callId or channel — aborting');
      isHandlingCall = false;
      _hasConnected = false;
      return;
    }

    await _emergencyService.acceptCall(callId);

    try {
      await _agoraService.initialize();
    } catch (e) {
      debugPrint('[CallKitHandler] Agora init warning: $e');
    }

    final joined = await _agoraService.joinChannel(
      channelName: channel,
      token: token,
      uid: callId,
    );

    if (!joined) {
      debugPrint('[CallKitHandler] Join failed');
      isHandlingCall = false;
      _hasConnected = false;
      return;
    }

    // ✅ Fetch call doc with retries
    EmergencyCall? call;
    for (int i = 0; i < 5; i++) {
      try {
        call = await _emergencyService
            .callStream(callId)
            .first
            .timeout(const Duration(seconds: 3));
        if (call != null) break;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }

    if (call == null) {
      debugPrint('[CallKitHandler] Could not fetch call doc');
      isHandlingCall = false;
      return;
    }

    final isCaregiverCalling = callerRole == 'child';

    // ✅ Navigate with retry loop
    bool navigated = false;
    for (int i = 0; i < 20; i++) {
      final context = navigatorKey?.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context, rootNavigator: true)
            .pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ActiveCallScreen(
              call: call!,
              agoraService: _agoraService,
              isIncoming: true,
              showFallbackButton: false,
              playArrivalSound: isCaregiverCalling,
            ),
          ),
          (route) => route.isFirst,
        );
        navigated = true;
        debugPrint('[CallKitHandler] Navigated to ActiveCallScreen');

        // ✅ endAllCalls AFTER navigation so actionCallEnded
        // fires AFTER _hasConnected=true blocks it
        await FlutterCallkitIncoming.endAllCalls();
        break;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!navigated) {
      debugPrint(
          '[CallKitHandler] Navigator not ready after retries');
    }

    isHandlingCall = false;
  }

  // ── Called by IncomingCallScreen when it joins itself ──
  static void markAsHandled() {
    _instance._hasConnected = true;
    _instance._autoConnectTimer?.cancel();
    isHandlingCall = false;
  }

  // ── Cold start ─────────────────────────────────────────
  Future<void> handleColdStartIfNeeded() async {
    try {
      final calls =
          await FlutterCallkitIncoming.activeCalls();
      if (calls == null || calls.isEmpty) return;

      final call = calls.first as Map<dynamic, dynamic>;
      final extra =
          call['extra'] as Map<dynamic, dynamic>? ?? {};

      final callId = extra['callId'] as String? ?? '';
      if (callId.isEmpty) return;

      final channel =
          extra['agoraChannel'] as String? ?? '';
      final token = extra['agoraToken'] as String? ?? '';
      final callerRole =
          extra['callerRole'] as String? ?? 'child';

      debugPrint(
          '[CallKitHandler] Cold start callId=$callId');

      _pendingCallId = callId;
      _pendingChannel = channel;
      _pendingToken = token;
      _pendingCallerRole = callerRole;

      isHandlingCall = true;
      await _doConnect(
        callId: callId,
        channel: channel,
        token: token,
        callerRole: callerRole,
      );
    } catch (e) {
      debugPrint('[CallKitHandler] Cold start error: $e');
      isHandlingCall = false;
    }
  }

  Future<Map<String, dynamic>?> getInitialCallData() async {
    try {
      final calls =
          await FlutterCallkitIncoming.activeCalls();
      if (calls == null || calls.isEmpty) return null;
      final call = calls.first as Map<dynamic, dynamic>;
      final extra =
          call['extra'] as Map<dynamic, dynamic>? ?? {};
      final callId = extra['callId'] as String? ?? '';
      if (callId.isEmpty) return null;
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