// lib/core/services/callkit_handler.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/core/services/ringtone_service.dart';
import 'package:healthconnect/features/emergency/active_call_screen.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallKitHandler {
  static final CallKitHandler _instance = CallKitHandler._internal();
  factory CallKitHandler() => _instance;
  CallKitHandler._internal();

  final _emergencyService = EmergencyService();
  final _agoraService = AgoraCallService();
  final _ringtoneService = RingtoneService();

  static GlobalKey<NavigatorState>? navigatorKey;
  static bool isHandlingCall = false;

  // Prevents double listener registration
  bool _initialized = false;

  Timer? _autoConnectTimer;
  bool _hasConnected = false;

  // BUG 2 FIX: in-progress guard so _doConnect can never run twice
  // concurrently for the same call (the -17 "already in channel" error).
  bool _isConnecting = false;

  // Store call data at actionCallIncoming time because the
  // actionCallAccept extra map is often empty
  String _pendingCallId = '';
  String _pendingChannel = '';
  String _pendingToken = '';
  String _pendingCallerRole = '';

  void initialize() {
    if (_initialized) {
      debugPrint('[CallKitHandler] Already initialized — skipping');
      return;
    }
    _initialized = true;

    FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) return;

      final body = event.body as Map<dynamic, dynamic>? ?? {};
      final extra = body['extra'] as Map<dynamic, dynamic>? ?? {};

      final callId =
          extra['callId'] as String? ?? body['id'] as String? ?? '';
      final channel = extra['agoraChannel'] as String? ?? '';
      final token = extra['agoraToken'] as String? ?? '';
      final callerRole = extra['callerRole'] as String? ?? 'child';

      final eventName = event.event.toString();
      debugPrint('[CallKitHandler] event=$eventName callId=$callId');

      // ── Incoming ────────────────────────────────────
      if (eventName.contains('actionCallIncoming')) {
        isHandlingCall = true;
        _hasConnected = false;
        _isConnecting = false; // fresh call — allow a new connect

        _pendingCallId = callId;
        _pendingChannel = channel;
        _pendingToken = token;
        _pendingCallerRole = callerRole;

        await _ringtoneService.startRinging();

        // Android: auto-connect after a short delay (your existing UX).
        // iOS: DO NOT auto-connect — Apple requires user-tap Accept, and
        // background audio auto-join gets the app killed / token revoked.
        if (defaultTargetPlatform == TargetPlatform.android) {
          _autoConnectTimer?.cancel();
          _autoConnectTimer = Timer(
            const Duration(seconds: 4),
            () {
              if (_hasConnected || _isConnecting) return;
              _doConnect(
                callId: _pendingCallId,
                channel: _pendingChannel,
                token: _pendingToken,
                callerRole: _pendingCallerRole,
              );
            },
          );
        }
      }

      // ── Answer tapped ────────────────────────────────
      else if (eventName.contains('actionCallAccept')) {
        _autoConnectTimer?.cancel();
        if (_hasConnected || _isConnecting) return;

        await _doConnect(
          callId: _pendingCallId.isNotEmpty ? _pendingCallId : callId,
          channel: _pendingChannel.isNotEmpty ? _pendingChannel : channel,
          token: _pendingToken.isNotEmpty ? _pendingToken : token,
          callerRole:
              _pendingCallerRole.isNotEmpty ? _pendingCallerRole : callerRole,
        );
      }

      // ── Decline tapped ───────────────────────────────
      else if (eventName.contains('actionCallDecline')) {
        _autoConnectTimer?.cancel();
        isHandlingCall = false;
        await _ringtoneService.stopRinging();
        if (!_hasConnected) {
          final id = _pendingCallId.isNotEmpty ? _pendingCallId : callId;
          if (id.isNotEmpty) {
            await _emergencyService.endCall(id);
          }
        }
        await FlutterCallkitIncoming.endAllCalls();
        _hasConnected = false;
        _isConnecting = false;
        _clearPending();
      }

      // ── Call ended ───────────────────────────────────
      else if (eventName.contains('actionCallEnded')) {
        // If already connected — this is fired by our own endAllCalls()
        // call after navigation. Ignore it.
        if (_hasConnected) {
          debugPrint(
              '[CallKitHandler] actionCallEnded ignored — already connected');
          await _ringtoneService.stopRinging();
          return;
        }

        if (_hasConnected || _agoraService.isInCall) {
          debugPrint('[CallKitHandler] actionCallEnded blocked: App is actively handling a live call pipeline.');
          await _ringtoneService.stopRinging();
          return;
        }
        _autoConnectTimer?.cancel();
        isHandlingCall = false;
        _hasConnected = false;
        _isConnecting = false;
        await _ringtoneService.stopRinging();
        final id = _pendingCallId.isNotEmpty ? _pendingCallId : callId;
        if (id.isNotEmpty) {
          await _emergencyService.endCall(id);
        }
        await _agoraService.leaveChannel();
        _clearPending();
      }

      // ── Timeout ──────────────────────────────────────
      else if (eventName.contains('actionCallTimeout')) {
        _autoConnectTimer?.cancel();
        _isConnecting = false;
        _hasConnected = false;
      }
    });
  }

  void _clearPending() {
    _pendingCallId = '';
    _pendingChannel = '';
    _pendingToken = '';
    _pendingCallerRole = '';
    _isConnecting = false;
  }

  // Build a minimal call object from the data we already hold, so
  // navigation can proceed even if Firestore never returns the doc
  // on a slow cold start.
  EmergencyCall _fallbackCall({
    required String callId,
    required String channel,
    required String token,
    required String callerRole,
  }) {
    return EmergencyCall(
      id: callId,
      callerId: '',
      callerName:
          callerRole == 'child' ? 'Child Emergency' : 'Parent Emergency',
      callerRole:
          callerRole == 'parent' ? CallerRole.parent : CallerRole.child,
      receiverId: '',
      caregiverId: '',
      status: CallStatus.accepted,
      agoraChannel: channel,
      agoraToken: token,
      fallbackAttempt: 0,
      createdAt: DateTime.now(),
    );
  }

  // ── Core connect ──────────────────────────────────────
//   Future<void> _doConnect({
//     required String callId,
//     required String channel,
//     required String token,
//     required String callerRole,
//   }) async {
//     // BUG 2 FIX: hard guard at the very top, before any await.
//     // If a join is already in progress, bail instantly so we never
//     // call joinChannel twice for the same call (the -17 error).


//     _autoConnectTimer?.cancel();


//     if (_isConnecting) {
//       debugPrint('[CallKitHandler] _doConnect ignored — already connecting');
//       return;
//     }
//     _isConnecting = true;
//     _hasConnected = true;

//     await _ringtoneService.stopRinging();

//     if (callId.isEmpty || channel.isEmpty) {
//       debugPrint('[CallKitHandler] Missing callId or channel — aborting');
//       isHandlingCall = false;
//       _hasConnected = false;
//       _isConnecting = false;
//       return;
//     }

//     // await _emergencyService.acceptCall(callId);
// try {
//       await _agoraService.initialize();
//     } catch (e) {
//       debugPrint('[CallKitHandler] Agora init warning: $e');
//     }

// //   i have changed here .......


//     // try {
//     //   await _agoraService.initialize();
//     // } catch (e) {
//     //   debugPrint('[CallKitHandler] Agora init warning: $e');
//     // }

//     // BUG 3 FIX: receiver joins with its OWN uid so it never collides
//     // with the caller's uid (which is what stops onUserJoined firing).
//     final joined = await AgoraCallService().joinChannel(
//       channelName: channel,
//       token: token,
//       uid: FirebaseAuth.instance.currentUser?.uid ?? callId,
//     );

//     if (!joined) {
//       debugPrint('[CallKitHandler] Join failed');
//       isHandlingCall = false;
//       _hasConnected = false;
//       _isConnecting = false;
//       return;
//     }

//     // Wait for the call doc; fall back to a minimal object so we never
//     // strand the user in a channel with no UI on a slow cold start.
//     EmergencyCall? call;
//     for (int i = 0; i < 10; i++) {
//       try {
//         call = await _emergencyService
//             .callStream(callId)
//             .first
//             .timeout(const Duration(seconds: 5));
//         if (call != null) break;
//       } catch (_) {}
//       await Future.delayed(const Duration(seconds: 1));
//     }

//     call ??= _fallbackCall(
//       callId: callId,
//       channel: channel,
//       token: token,
//       callerRole: callerRole,
//     );

//     final isCaregiverCalling = callerRole == 'child';

//     // Navigate with retry loop (navigator may not be ready on cold start)
//     bool navigated = false;
//     for (int i = 0; i < 20; i++) {
//       final context = navigatorKey?.currentContext;
//       if (context != null && context.mounted) {


//         Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
//           MaterialPageRoute(
//             builder: (_) => ActiveCallScreen(
//               call: call!,
//               agoraService: _agoraService,
//               isIncoming: true,
//               showFallbackButton: false,
//               playArrivalSound: isCaregiverCalling,
//             ),
//           ),
//           (route) => false,
//         );
//         navigated = true;
//         debugPrint('[CallKitHandler] Navigated to ActiveCallScreen');

//         // endAllCalls AFTER navigation so actionCallEnded fires
//         // AFTER _hasConnected=true blocks it.

//         // commmented
//       //  await FlutterCallkitIncoming.endAllCalls();
//       await FlutterCallkitIncoming.endCall(callId);
//         break;
//       }
//       await Future.delayed(const Duration(milliseconds: 500));
//     }

//     if (!navigated) {
//       debugPrint('[CallKitHandler] Navigator not ready after retries');
//     }

//     // isHandlingCall = false;


//     await Future.delayed(const Duration(milliseconds: 400));
//     isHandlingCall = false;
//     _isConnecting = false;
//   }



// ── Core connect ──────────────────────────────────────
  Future<void> _doConnect({
    required String callId,
    required String channel,
    required String token,
    required String callerRole,
  }) async {
    // ✅ FIX 1: Cancel the timer instantly before ANY async suspension points
    _autoConnectTimer?.cancel();

    // ✅ FIX 2: Hard synchronous thread lock. 
    // This must be checked and set BEFORE any await line to completely close the timing gap.
    if (_isConnecting) {
      debugPrint('[CallKitHandler] _doConnect blocked duplicate concurrent stream call thread.');
      return;
    }
    _isConnecting = true;
    _hasConnected = true;

    // Async operations can safely run below now that the door is locked shut
    await _ringtoneService.stopRinging();

    if (callId.isEmpty || channel.isEmpty) {
      debugPrint('[CallKitHandler] Missing callId or channel — aborting');
      isHandlingCall = false;
      _hasConnected = false;
      _isConnecting = false;
      return;
    }

    try {
      await _agoraService.initialize();
    } catch (e) {
      debugPrint('[CallKitHandler] Agora init warning: $e');
    }

    // ✅ FIX 3: Unique String UID construction to prevent local test collisions
    // Appending '_receiver' guarantees that when _resolveUid() hashes this string 
    // into an integer, it will be completely different from the caller's integer UID.
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final receiverUidString = currentUserId.isNotEmpty ? "${currentUserId}_receiver" : "${callId}_receiver";

    final joined = await AgoraCallService().joinChannel(
      channelName: channel,
      token: token,
      uid: receiverUidString, // <-- Pass the unique receiver identity string
    );

    if (!joined) {
      debugPrint('[CallKitHandler] Join failed');
      isHandlingCall = false;
      _hasConnected = false;
      _isConnecting = false;
      return;
    }

    // Wait for the call doc; fall back to a minimal object so we never
    // strand the user in a channel with no UI on a slow cold start.
    EmergencyCall? call;
    for (int i = 0; i < 10; i++) {
      try {
        call = await _emergencyService
            .callStream(callId)
            .first
            .timeout(const Duration(seconds: 5));
        if (call != null) break;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }

    call ??= _fallbackCall(
      callId: callId,
      channel: channel,
      token: token,
      callerRole: callerRole,
    );

    final isCaregiverCalling = callerRole == 'child';

    // Navigate with retry loop (navigator may not be ready on cold start)
    bool navigated = false;
    for (int i = 0; i < 20; i++) {
      final context = navigatorKey?.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ActiveCallScreen(
              call: call!,
              agoraService: _agoraService,
              isIncoming: true,
              showFallbackButton: false,
              playArrivalSound: isCaregiverCalling,
            ),
          ),
          (route) => false,
        );
        navigated = true;
        debugPrint('[CallKitHandler] Navigated to ActiveCallScreen');

       // await FlutterCallkitIncoming.endCall(callId);
        break;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!navigated) {
      debugPrint('[CallKitHandler] Navigator not ready after retries');
    }

    await Future.delayed(const Duration(milliseconds: 600));
    isHandlingCall = false;
    _isConnecting = false;
  }

  // ── Called when the call fully ends ────────────────────
  // Resets all flags so the NEXT call can connect. Call this from
  // ActiveCallScreen when the call screen is torn down, OR rely on the
  // actionCallEnded/decline branches above which already reset.
  void resetCallState() {
    _autoConnectTimer?.cancel();
    _hasConnected = false;
    _isConnecting = false;
    isHandlingCall = false;
    _clearPending();
  }

  // ── Called by IncomingCallScreen when it joins itself ──
  static void markAsHandled() {
    _instance._hasConnected = true;
    _instance._isConnecting = true;
    _instance._autoConnectTimer?.cancel();
    isHandlingCall = false;
  }

  // ── Cold start ─────────────────────────────────────────
  Future<void> handleColdStartIfNeeded() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls == null || calls.isEmpty) return;

      final call = calls.first as Map<dynamic, dynamic>;
      final extra = call['extra'] as Map<dynamic, dynamic>? ?? {};

      final callId = extra['callId'] as String? ?? '';
      if (callId.isEmpty) return;

      final channel = extra['agoraChannel'] as String? ?? '';
      final token = extra['agoraToken'] as String? ?? '';
      final callerRole = extra['callerRole'] as String? ?? 'child';

      debugPrint('[CallKitHandler] Cold start callId=$callId');

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
      _isConnecting = false;
    }
  }

  Future<Map<String, dynamic>?> getInitialCallData() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls == null || calls.isEmpty) return null;
      final call = calls.first as Map<dynamic, dynamic>;
      final extra = call['extra'] as Map<dynamic, dynamic>? ?? {};
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