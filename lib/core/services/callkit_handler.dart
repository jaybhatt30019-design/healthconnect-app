// lib/core/services/callkit_handler.dart
// Fixed for flutter_callkit_incoming v2.5.8

import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
// ✅ FIXED: Event enum lives in entities in v2.5.8
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/core/services/ringtone_service.dart';

class CallKitHandler {
  static final CallKitHandler _instance = CallKitHandler._internal();
  factory CallKitHandler() => _instance;
  CallKitHandler._internal();

  final _emergencyService = EmergencyService();
  final _agoraService = AgoraCallService();
  final _ringtoneService = RingtoneService();

  static GlobalKey<NavigatorState>? navigatorKey;

  void initialize() {
    FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) return;

      final body = event.body as Map<dynamic, dynamic>? ?? {};
      final extra = body['extra'] as Map<dynamic, dynamic>? ?? {};
      final callId =
          extra['callId'] as String? ?? body['id'] as String? ?? '';
      final channel = extra['agoraChannel'] as String? ?? '';
      final token = extra['agoraToken'] as String? ?? '';

      debugPrint('[CallKitHandler] event=${event.event}  callId=$callId');

      // ✅ Compare against string value of event — most reliable across versions
      final eventName = event.event.toString();

      if (eventName.contains('actionCallAccept')) {
        await _ringtoneService.stopRinging();
        if (callId.isEmpty) return;
        await _emergencyService.acceptCall(callId);
        await _agoraService.initialize();
        await _agoraService.joinChannel(
          channelName: channel,
          token: token,
          uid: callId,
        );
      } else if (eventName.contains('actionCallDecline')) {
        await _ringtoneService.stopRinging();
        if (callId.isNotEmpty) await _emergencyService.rejectCall(callId);
      } else if (eventName.contains('actionCallEnded')) {
        await _ringtoneService.stopRinging();
        if (callId.isNotEmpty) await _emergencyService.endCall(callId);
        await _agoraService.leaveChannel();
      } else if (eventName.contains('actionCallIncoming')) {
        await _ringtoneService.startRinging();
      } else if (eventName.contains('actionCallTimeout')) {
        await _ringtoneService.stopRinging();
        if (callId.isNotEmpty) await _emergencyService.rejectCall(callId);
      }
    });
  }
}