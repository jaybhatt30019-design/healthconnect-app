// lib/features/emergency/active_call_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/features/dashboard/main_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  State<ActiveCallScreen> createState() =>
      _ActiveCallScreenState();
}

class _ActiveCallScreenState
    extends State<ActiveCallScreen> {
  final _emergencyService = EmergencyService();

  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _remoteUserJoined = false;
  int _elapsedSeconds = 0;
  Timer? _durationTimer;
  StreamSubscription? _callSub;
  bool _isEnding = false;

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();

    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() => _elapsedSeconds++);
      },
    );

    widget.agoraService.onUserJoined = (uid) {
      if (mounted) {
        setState(() => _remoteUserJoined = true);
      }
    };

    widget.agoraService.onUserLeft = (uid) {
      if (mounted) {
        setState(() => _remoteUserJoined = false);
      }
    };

    widget.agoraService.onCallEnded = () {
      _leaveAndReturn();
    };

    _callSub = _emergencyService
        .callStream(widget.call.id)
        .listen((call) {
      if (call == null) return;
      if (call.status == CallStatus.ended) {
        _leaveAndReturn();
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
    if (_isEnding) return;
    setState(() => _isEnding = true);
    await _emergencyService.endCall(widget.call.id);
    await _leaveAndReturn();
  }

  // ✅ FIX — returns to MainDashboard on emergency tab
  // instead of popping to a black screen
  Future<void> _leaveAndReturn() async {
    if (!mounted) return;

    await widget.agoraService.leaveChannel();

    // Detect role to pass correct isCaregiver flag
    bool isCaregiver = false;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        isCaregiver =
            (doc.data()?['role'] as String? ?? '') ==
                'caregiver';
      }
    } catch (e) {
      debugPrint('[ActiveCallScreen] Role check: $e');
    }

    if (!mounted) return;

    // ✅ Navigate to MainDashboard with emergency tab (index 3)
    Navigator.of(context, rootNavigator: true)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainDashboard(
          isCaregiver: isCaregiver,
          initialIndex: 3, // Emergency tab
        ),
      ),
      (route) => false, // Remove all previous routes
    );
  }

  Future<void> _toggleMute() async {
    await widget.agoraService.toggleMute();
    if (mounted) {
      setState(
          () => _isMuted = widget.agoraService.isMuted);
    }
  }

  Future<void> _toggleSpeaker() async {
    await widget.agoraService.toggleSpeaker();
    if (mounted) {
      setState(() =>
          _isSpeakerOn = widget.agoraService.isSpeakerOn);
    }
  }

  String get _durationText {
    final m =
        (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s =
        (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ✅ Prevent back button from going to black screen
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.red, width: 1),
                ),
                child: const Text(
                  "🚨 EMERGENCY CALL ACTIVE",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                    color:
                        Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.person,
                    size: 70, color: Colors.white),
              ),

              const SizedBox(height: 24),

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

              Text(
                _remoteUserJoined
                    ? _durationText
                    : "Connecting...",
                style: TextStyle(
                  color: _remoteUserJoined
                      ? Colors.green.shade400
                      : Colors.white60,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

              if (!_remoteUserJoined)
                const Text(
                  "Waiting for other side to connect",
                  style: TextStyle(
                      color: Colors.white38, fontSize: 13),
                ),

              const Spacer(),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      icon: _isMuted
                          ? Icons.mic_off
                          : Icons.mic,
                      label:
                          _isMuted ? "Unmute" : "Mute",
                      color: _isMuted
                          ? Colors.red.shade400
                          : Colors.white24,
                      onTap: _toggleMute,
                    ),
                    _controlButton(
                      icon: _isSpeakerOn
                          ? Icons.volume_up
                          : Icons.volume_off,
                      label: _isSpeakerOn
                          ? "Speaker"
                          : "Earpiece",
                      color: _isSpeakerOn
                          ? Colors.blue.shade400
                          : Colors.white24,
                      onTap: _toggleSpeaker,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ✅ End Call — goes back to emergency tab
              GestureDetector(
                onTap: _isEnding ? null : _endCall,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isEnding
                        ? Colors.grey
                        : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red
                            .withValues(alpha: 0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: _isEnding
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : const Icon(Icons.call_end,
                          color: Colors.white, size: 36),
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                "End Call",
                style: TextStyle(
                    color: Colors.white60, fontSize: 13),
              ),

              const SizedBox(height: 50),
            ],
          ),
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