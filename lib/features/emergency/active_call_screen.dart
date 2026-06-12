// lib/features/emergency/active_call_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/core/services/ringtone_service.dart';
import 'package:healthconnect/features/dashboard/main_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveCallScreen extends StatefulWidget {
  final EmergencyCall call;
  final AgoraCallService agoraService;
  final bool isIncoming;

  // true → parent who initiated the call sees fallback
  final bool showFallbackButton;

  // true → parent receiving caregiver call, plays 5s sound
  final bool playArrivalSound;

  // pre-loaded fallback number (optional)
  final String? fallbackNumber;

  const ActiveCallScreen({
    super.key,
    required this.call,
    required this.agoraService,
    required this.isIncoming,
    this.showFallbackButton = false,
    this.playArrivalSound = false,
    this.fallbackNumber,
  });

  @override
  State<ActiveCallScreen> createState() =>
      _ActiveCallScreenState();
}

class _ActiveCallScreenState
    extends State<ActiveCallScreen> {
  final _emergencyService = EmergencyService();
  final _ringtoneService = RingtoneService();

  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _remoteUserJoined = false;
  int _elapsedSeconds = 0;
  Timer? _durationTimer;
  Timer? _soundTimer;
  StreamSubscription? _callSub;
  bool _isEnding = false;
  bool _isCallingFallback = false;
  String? _fallbackNumber;

  @override
  void initState() {
    super.initState();


    print("i am at the actuve screen !!"); 
        WakelockPlus.enable();

    _fallbackNumber = widget.fallbackNumber;

    // Load fallback number from Firestore if needed
    if (widget.showFallbackButton &&
        _fallbackNumber == null) {
      _loadFallbackNumber();
    }
    // Play arrival sound for parent when caregiver calls
    if (widget.playArrivalSound) {
      _playArrivalSound();

      print("playying arival sound!!");
    }

    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted && _remoteUserJoined) {
          setState(() => _elapsedSeconds++);
        }
      },
    );

  
    widget.agoraService.onUserJoined = (uid) {
      if (mounted) {
        print("joined!!");
        _remoteUserJoined = true;
        print(_remoteUserJoined.toString() + " yesss");
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

  if (widget.agoraService.isInCall) {
      _remoteUserJoined = true;
    }
    _callSub = _emergencyService
        .callStream(widget.call.id)
        .listen((call) {
      if (call == null) return;
      if (call.status == CallStatus.ended) {
        _leaveAndReturn();
      }
    });
  }

  Future<void> _loadFallbackNumber() async {
    try {
      final contacts =
          await _emergencyService.loadContacts();
      if (contacts?.secondary != null && mounted) {
        setState(() {
          _fallbackNumber =
              contacts!.secondary!.phone;
        });
      }
    } catch (e) {
      debugPrint(
          '[ActiveCallScreen] Load fallback: $e');
    }
  }

  Future<void> _playArrivalSound() async {
    await _ringtoneService.startRinging();
    _soundTimer = Timer(
      const Duration(seconds: 5),
      () => _ringtoneService.stopRinging(),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _durationTimer?.cancel();
    _soundTimer?.cancel();
    _callSub?.cancel();
    _ringtoneService.stopRinging();
    super.dispose();
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    _soundTimer?.cancel();
    await _ringtoneService.stopRinging();
    await _emergencyService.endCall(widget.call.id);
    await _leaveAndReturn();
  }

  Future<void> _callFallback() async {
    if (_isCallingFallback ||
        _fallbackNumber == null) return;
    setState(() => _isCallingFallback = true);

    // End Agora first
    await _emergencyService.endCall(widget.call.id);
    await widget.agoraService.leaveChannel();

    // Open phone dialler
    final uri = Uri.parse('tel:$_fallbackNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }

    if (!mounted) return;
    _goToDashboard(false);
  }

  Future<void> _leaveAndReturn() async {
    if (!mounted) return;
    _soundTimer?.cancel();
    await _ringtoneService.stopRinging();
    await widget.agoraService.leaveChannel();

    // Detect role
    bool isCaregiver = false;
    try {
      final uid =
          FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        isCaregiver =
            (doc.data()?['role'] as String? ?? '') ==
                'caregiver';
      }
    } catch (_) {}

    if (!mounted) return;
    _goToDashboard(isCaregiver);
  }

  void _goToDashboard(bool isCaregiver) {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainDashboard(
          isCaregiver: isCaregiver,
          initialIndex: 0,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _toggleMute() async {
    await widget.agoraService.toggleMute();
    if (mounted) {
      setState(() =>
          _isMuted = widget.agoraService.isMuted);
    }
  }

  Future<void> _toggleSpeaker() async {
    await widget.agoraService.toggleSpeaker();
    if (mounted) {
      setState(() =>
          _isSpeakerOn =
              widget.agoraService.isSpeakerOn);
    }
  }

  String get _durationText {
    final m = (_elapsedSeconds ~/ 60)
        .toString()
        .padLeft(2, '0');
    final s = (_elapsedSeconds % 60)
        .toString()
        .padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
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

              // Emergency badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red
                      .withValues(alpha: 0.2),
                  borderRadius:
                      BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.red, width: 1),
                ),
                child: const Text(
                  '🚨 EMERGENCY CALL ACTIVE',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Avatar
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white
                      .withValues(alpha: 0.1),
                  border: Border.all(
                    color: Colors.white
                        .withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.person,
                    size: 70, color: Colors.white),
              ),

              const SizedBox(height: 24),

              Text(
                widget.call.callerRole ==
                        CallerRole.child
                    ? widget.call.callerName
                    : 'Emergency Call',
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
                    : 'Connecting...',
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
                  'Waiting for other side to connect',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13),
                ),

              const Spacer(),

              // Mute + Speaker controls
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      icon: _isMuted
                          ? Icons.mic_off
                          : Icons.mic,
                      label: _isMuted
                          ? 'Unmute'
                          : 'Mute',
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
                          ? 'Speaker'
                          : 'Earpiece',
                      color: _isSpeakerOn
                          ? Colors.blue.shade400
                          : Colors.white24,
                      onTap: _toggleSpeaker,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Action buttons
              widget.showFallbackButton
                  ? _buildTwoButtons()
                  : _buildEndCallOnly(),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // End Call only — centered
  Widget _buildEndCallOnly() {
    return Column(
      children: [
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
          'End Call',
          style: TextStyle(
              color: Colors.white60, fontSize: 13),
        ),
      ],
    );
  }

  // End Call + Call Fallback side by side
  Widget _buildTwoButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 30),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceEvenly,
        children: [
          // End Call
          Column(
            children: [
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
                          color: Colors.white,
                          size: 36),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'End Call',
                style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13),
              ),
            ],
          ),

          // Call Fallback
          Column(
            children: [
              GestureDetector(
                onTap: (_isCallingFallback ||
                        _fallbackNumber == null)
                    ? null
                    : _callFallback,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _fallbackNumber == null
                        ? Colors.grey.shade700
                        : _isCallingFallback
                            ? Colors.grey
                            : Colors.green.shade700,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_fallbackNumber != null)
                        BoxShadow(
                          color: Colors.green
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                        ),
                    ],
                  ),
                  child: _isCallingFallback
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : const Icon(
                          Icons.phone_forwarded,
                          color: Colors.white,
                          size: 34,
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _fallbackNumber == null
                    ? 'No Fallback'
                    : 'Call Fallback',
                style: TextStyle(
                  color: _fallbackNumber == null
                      ? Colors.white38
                      : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
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
            child: Icon(icon,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12)),
        ],
      ),
    );
  }
}