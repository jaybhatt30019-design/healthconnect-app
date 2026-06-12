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
  String? _currentChannel;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  // ✅ BUG E FIX — prevents joinChannel running while dispose()
  // is mid-flight (release() can null the engine underneath join)
  bool _isDisposing = false;

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
    await _engine!.initialize(RtcEngineContext(
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
          _currentChannel = null;
        },
        onConnectionLost: (connection) {
          debugPrint('[Agora] Connection lost');
          onError?.call('Connection lost');
        },
      ),
    );
  }

  // ✅ Convert a caller-supplied id (often a Firestore doc id string,
  // or a uid string) into a stable non-negative 32-bit Agora uid.
  // Returns 0 when empty — 0 means "let Agora auto-assign", which is
  // the safe wildcard for non-uid-bound tokens.
  int _resolveUid(String raw) {
    // Delegate to AgoraConfig so the JOIN uid and the TOKEN uid are always
    // identical. If they differ, a real (non-empty) token fails validation.
    return AgoraConfig.resolveUid(raw);
  }

  // ── Join channel ──────────────────────────────────────

  Future<bool> joinChannel({
    required String channelName,
    required String token,
    required String uid,
  }) async {
    // Permission: check first, only prompt if missing (stops repeat dialogs)
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }
    if (!micStatus.isGranted) {

      onError?.call('Microphone permission denied');
      return false;
    }

    int waited = 0;
    while (_isDisposing && waited < 2000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }

    // ✅ IDEMPOTENT GUARD: if we're already in THIS channel, do nothing.
    // This is what stops the -17 "already joined" error and the
    // destructive leave-and-rejoin that was killing live calls.
    if (_isInCall && _currentChannel == channelName) {
      debugPrint('[AgoraCallService] Already in channel $channelName — ignoring duplicate join');
      return true;
    }

    // Only leave if we're in a DIFFERENT channel
    if (_isInCall && _currentChannel != channelName) {
      debugPrint('[AgoraCallService] In different channel — leaving first');
      await leaveChannel();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (_engine == null || !_isInitialized) {
      await initialize();
    }

    final agoraUid = _resolveUid(uid);


    try {

      _isInCall = true;
      _currentChannel = channelName;   // ✅ track current channel
      _isMuted = false;
      _isSpeakerOn = true;


      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: agoraUid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
      
      return true;
    } catch (e) {
      _isInCall = false;
      _currentChannel = null;
      debugPrint('[Agora] Join failed: $e');
      onError?.call(e.toString());
      return false;
    }
  }

  // ── Leave channel ─────────────────────────────────────
  Future<void> leaveChannel() async {
    if (_engine == null) return;
    // await _engine!.leaveChannel();
    //   await _engine!.release();
    //   _engine = null;


    //   // i have changed here ........
    // _isInCall = false;
    // _currentChannel = null;


    try {
      // 1. Tell the native socket loop to drop the transmission pipeline safely
      await _engine!.leaveChannel();
      // 2. Allow a brief 150ms window for the socket pipeline to cycle down cleanly
      await Future.delayed(const Duration(milliseconds: 150));
    } catch (e) {
      debugPrint('[AgoraCallService] Error while leaving channel: $e');
    } finally {
      // Ensure variables clear out completely regardless of hardware snags
      _isInCall = false;
      _currentChannel = null;
    }
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
    _isDisposing = true; // ✅ block any concurrent joinChannel
    try {
      await leaveChannel();
    
      _engine = null;
      _isInitialized = false; // ✅ Reset so next call re-initializes
      _isInCall = false;
       _currentChannel = null;
    } finally {
      _isDisposing = false;
    }
  }
}