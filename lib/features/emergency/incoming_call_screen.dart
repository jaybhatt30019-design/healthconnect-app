// lib/features/emergency/incoming_call_screen.dart
// Auto-connect flow: receiver joins immediately
// No accept/decline buttons — call starts automatically

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/core/services/ringtone_service.dart';
import 'package:healthconnect/features/emergency/active_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final EmergencyCall call;

  const IncomingCallScreen(
      {super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() =>
      _IncomingCallScreenState();
}

class _IncomingCallScreenState
    extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  final _emergencyService = EmergencyService();
  final _ringtoneService = RingtoneService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription? _callSub;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();

    _pulseController = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeInOut),
    );

    // ✅ Play alert sound briefly then auto-join
    _ringtoneService.startRinging();

    // ✅ Auto-join after 1 second
    // Short delay lets UI render and sound play
    Future.delayed(
      const Duration(seconds: 1),
      _autoJoin,
    );

    // Listen for call ended by caller
    _callSub = _emergencyService
        .callStream(widget.call.id)
        .listen((call) {
      if (call == null) return;
      if (call.status == CallStatus.ended) {
        _ringtoneService.stopRinging();
        _closeScreen();
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pulseController.dispose();
    _callSub?.cancel();
    _ringtoneService.stopRinging();
    super.dispose();
  }

  // ✅ Auto-join Agora — no button press needed
  Future<void> _autoJoin() async {
    if (_isConnecting || !mounted) return;
    setState(() => _isConnecting = true);

    await _ringtoneService.stopRinging();

    final agoraService = AgoraCallService();

    try {
      await agoraService.initialize();
    } catch (e) {
      // ✅ Agora error -3 (setEnableSpeakerphone)
      // is non-fatal on some devices — continue anyway
      debugPrint(
          '[IncomingCallScreen] Agora init warning: $e');
    }

    try {
      await agoraService.joinChannel(
        channelName: widget.call.agoraChannel,
        token: widget.call.agoraToken,
        uid: widget.call.receiverId,
      );
    } catch (e) {
      debugPrint(
          '[IncomingCallScreen] Join error: $e');
      if (mounted) _closeScreen();
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActiveCallScreen(
          call: widget.call,
          agoraService: agoraService,
          isIncoming: true,
        ),
      ),
    );
  }

  void _closeScreen() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isChildCalling =
        widget.call.callerRole == CallerRole.child;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0000),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                "🚨  EMERGENCY CALL",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 40),

            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(
                      alpha: 0.2),
                  border: Border.all(
                      color: Colors.red, width: 3),
                ),
                child: const Icon(Icons.person,
                    size: 80, color: Colors.white),
              ),
            ),

            const SizedBox(height: 30),

            Text(
              widget.call.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              isChildCalling
                  ? "Your Child Needs Help!"
                  : "Your Parent Needs Help!",
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Auto-connecting message
            // replaces the old Accept/Decline buttons
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Connecting automatically...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Only End Call button — no Decline
            GestureDetector(
              onTap: () async {
                await _ringtoneService.stopRinging();
                await _emergencyService
                    .endCall(widget.call.id);
                _closeScreen();
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red
                          .withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.call_end,
                    color: Colors.white, size: 36),
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "End Call",
              style: TextStyle(
                  color: Colors.white, fontSize: 14),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}