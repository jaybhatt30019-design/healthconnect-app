// lib/features/emergency/active_call_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';

class ActiveCallScreen extends StatefulWidget {
  final EmergencyCall call;
  final AgoraCallService agoraService;
  final bool isIncoming;

  const ActiveCallScreen({
    super.key,
    required this.call,
    required this.agoraService,
    required this.isIncoming,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  final _emergencyService = EmergencyService();

  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _remoteUserJoined = false;
  int _elapsedSeconds = 0;
  Timer? _durationTimer;
  StreamSubscription? _callSub;

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();

    // Start duration counter
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    // Listen for remote user
    widget.agoraService.onUserJoined = (uid) {
      if (mounted) setState(() => _remoteUserJoined = true);
    };

    widget.agoraService.onUserLeft = (uid) {
      if (mounted) setState(() => _remoteUserJoined = false);
    };

    widget.agoraService.onCallEnded = () {
      _endCall();
    };

    // Listen for call status change from Firestore
    _callSub = _emergencyService
        .callStream(widget.call.id)
        .listen((call) {
      if (call == null) return;
      if (call.status == CallStatus.ended) {
        _leaveAndClose();
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _durationTimer?.cancel();
    _callSub?.cancel();
    super.dispose();
  }

  Future<void> _endCall() async {
    await _emergencyService.endCall(widget.call.id);
    await _leaveAndClose();
  }

  Future<void> _leaveAndClose() async {
    await widget.agoraService.leaveChannel();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggleMute() async {
    await widget.agoraService.toggleMute();
    if (mounted) setState(() => _isMuted = widget.agoraService.isMuted);
  }

  Future<void> _toggleSpeaker() async {
    await widget.agoraService.toggleSpeaker();
    if (mounted) setState(() => _isSpeakerOn = widget.agoraService.isSpeakerOn);
  }

  String get _durationText {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // ── Emergency label ─────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red, width: 1),
              ),
              child: const Text(
                "🚨 EMERGENCY CALL ACTIVE",
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5),
              ),
            ),

            const SizedBox(height: 40),

            // ── Avatar ──────────────────────────────
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(Icons.person, size: 70, color: Colors.white),
            ),

            const SizedBox(height: 24),

            // ── Name ────────────────────────────────
            Text(
              widget.call.callerRole == CallerRole.child
                  ? widget.call.callerName
                  : "Emergency Call",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // ── Status ──────────────────────────────
            Text(
              _remoteUserJoined ? _durationText : "Connecting...",
              style: TextStyle(
                color: _remoteUserJoined
                    ? Colors.green.shade400
                    : Colors.white60,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            if (!_remoteUserJoined)
              const Text(
                "Waiting for other side to connect",
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),

            const Spacer(),

            // ── Controls ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? "Unmute" : "Mute",
                    color: _isMuted
                        ? Colors.red.shade400
                        : Colors.white24,
                    onTap: _toggleMute,
                  ),
                  _controlButton(
                    icon: _isSpeakerOn
                        ? Icons.volume_up
                        : Icons.volume_off,
                    label: _isSpeakerOn ? "Speaker" : "Earpiece",
                    color: _isSpeakerOn
                        ? Colors.blue.shade400
                        : Colors.white24,
                    onTap: _toggleSpeaker,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── End Call Button ─────────────────────
            GestureDetector(
              onTap: _endCall,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.call_end,
                    color: Colors.white, size: 36),
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              "End Call",
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}