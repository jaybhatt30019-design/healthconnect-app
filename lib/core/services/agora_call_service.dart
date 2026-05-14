import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:healthconnect/core/services/agora_token_service.dart';

class AgoraCallService {
  static final AgoraCallService _instance = AgoraCallService._internal();
  factory AgoraCallService() => _instance;
  AgoraCallService._internal();

  RtcEngine? _engine;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  // Callbacks
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserLeft;
  Function(String error)? onError;
  Function()? onCallEnded;

  // ─────────────────────────────────────────────────────
  // Initialize Agora engine
  // ─────────────────────────────────────────────────────
  Future<void> initialize() async {
    _engine = createAgoraRtcEngine();

    await _engine!.initialize(RtcEngineContext(
      appId: AgoraConfig.appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Audio-only setup
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.enableAudio();
    await _engine!.setEnableSpeakerphone(true);
    await _engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    _setupEventHandlers();
  }

  // ─────────────────────────────────────────────────────
  // Event handlers
  // ─────────────────────────────────────────────────────
  void _setupEventHandlers() {
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('[Agora] Joined channel: ${connection.channelId}');
          _isInCall = true;
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('[Agora] Remote user joined: $remoteUid');
          onUserJoined?.call(remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('[Agora] Remote user left: $remoteUid reason: $reason');
          onUserLeft?.call(remoteUid);
          // If remote user left, call ended
          if (reason == UserOfflineReasonType.userOfflineDropped ||
              reason == UserOfflineReasonType.userOfflineQuit) {
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

  // ─────────────────────────────────────────────────────
  // Join a call channel
  // ─────────────────────────────────────────────────────
  Future<bool> joinChannel({
    required String channelName,
    required String token,
    required String uid,
  }) async {
    // Request microphone permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      onError?.call('Microphone permission denied');
      return false;
    }

    if (_engine == null) await initialize();

    try {
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: 0, // 0 = auto-assign
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
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

  // ─────────────────────────────────────────────────────
  // Leave channel
  // ─────────────────────────────────────────────────────
  Future<void> leaveChannel() async {
    if (_engine == null) return;
    await _engine!.leaveChannel();
    _isInCall = false;
  }

  // ─────────────────────────────────────────────────────
  // Toggle mute
  // ─────────────────────────────────────────────────────
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
  }

  // ─────────────────────────────────────────────────────
  // Toggle speaker
  // ─────────────────────────────────────────────────────
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _engine!.setEnableSpeakerphone(_isSpeakerOn);
  }

  // ─────────────────────────────────────────────────────
  // Cleanup
  // ─────────────────────────────────────────────────────
  Future<void> dispose() async {
    await leaveChannel();
    await _engine?.release();
    _engine = null;
  }
}