// lib/core/services/agora_call_service.dart

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:healthconnect/core/services/agora_token_service.dart';

class AgoraCallService {
  static final AgoraCallService _instance =
      AgoraCallService._internal();
  factory AgoraCallService() => _instance;
  AgoraCallService._internal();

  RtcEngine? _engine;
  bool _isInitialized = false; // ✅ Guard flag
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  Function(int uid)? onUserJoined;
  Function(int uid)? onUserLeft;
  Function(String error)? onError;
  Function()? onCallEnded;

  // ── Initialize ────────────────────────────────────────
  Future<void> initialize() async {
    // ✅ Skip if already initialized
    // Prevents duplicate event handler registrations
    if (_isInitialized && _engine != null) {
      debugPrint(
          '[AgoraCallService] Already initialized — skipping');
      return;
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: AgoraConfig.appId,
    ));

    try {
      await _engine!.setEnableSpeakerphone(true);
    } catch (e) {
      debugPrint(
          '[AgoraCallService] setEnableSpeakerphone '
          'warning: $e — continuing');
    }

    await _engine!.enableAudio();
    _setupEventHandlers();

    _isInitialized = true;
    debugPrint('[AgoraCallService] Initialized ✅');
  }

  // ── Event handlers ────────────────────────────────────
  void _setupEventHandlers() {
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint(
              '[Agora] Joined: '
              '${connection.channelId}');
          _isInCall = true;
        },
        onUserJoined:
            (connection, remoteUid, elapsed) {
          debugPrint(
              '[Agora] Remote user joined: $remoteUid');
          onUserJoined?.call(remoteUid);
        },
        onUserOffline:
            (connection, remoteUid, reason) {
          debugPrint(
              '[Agora] Remote user left: $remoteUid '
              'reason: $reason');
          onUserLeft?.call(remoteUid);
          if (reason ==
                  UserOfflineReasonType
                      .userOfflineDropped ||
              reason ==
                  UserOfflineReasonType
                      .userOfflineQuit) {
            onCallEnded?.call();
          }
        },
        onError: (err, msg) {
          debugPrint('[Agora] Error: $err $msg');
          onError?.call(msg);
        },
        onLeaveChannel: (connection, stats) {
          debugPrint('[Agora] Left channel');
          _isInCall = false;
        },
        onConnectionLost: (connection) {
          debugPrint('[Agora] Connection lost');
          onError?.call('Connection lost');
        },
      ),
    );
  }

  // ── Join channel ──────────────────────────────────────
  Future<bool> joinChannel({
    required String channelName,
    required String token,
    required String uid,
  }) async {
    final micStatus =
        await Permission.microphone.request();
    if (!micStatus.isGranted) {
      onError?.call('Microphone permission denied');
      return false;
    }

    if (_engine == null || !_isInitialized) {
      await initialize();
    }

    try {
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType:
              ClientRoleType.clientRoleBroadcaster,
        ),
      );
      _isInCall = true;
      _isMuted = false;
      _isSpeakerOn = true;
      return true;
    } catch (e) {
      debugPrint('[Agora] Join failed: $e');
      onError?.call(e.toString());
      return false;
    }
  }

  // ── Leave channel ─────────────────────────────────────
  Future<void> leaveChannel() async {
    if (_engine == null) return;
    await _engine!.leaveChannel();
    _isInCall = false;
  }

  // ── Toggle mute ───────────────────────────────────────
  Future<void> toggleMute() async {
    if (_engine == null) return;
    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
  }

  // ── Toggle speaker ────────────────────────────────────
  Future<void> toggleSpeaker() async {
    if (_engine == null) return;
    _isSpeakerOn = !_isSpeakerOn;
    try {
      await _engine!
          .setEnableSpeakerphone(_isSpeakerOn);
    } catch (e) {
      debugPrint(
          '[AgoraCallService] toggleSpeaker: $e');
    }
  }

  // ── Full cleanup ──────────────────────────────────────
  // Call this when call ends completely
  Future<void> dispose() async {
    await leaveChannel();
    await _engine?.release();
    _engine = null;
    _isInitialized = false; // ✅ Reset so next call re-initializes
    _isInCall = false;
  }
}