// lib/features/emergency/incoming_call_screen.dart
// Parent calls Caregiver → caregiver sees this screen (isParentReceiving=false)
// Caregiver calls Parent → parent bypasses UI, auto-connects (isParentReceiving=true)
// ✅ No countdown shown on UI
// ✅ Caregiver: auto-connects after 5 seconds, Decline button shown
// ✅ Parent receiving: auto-connects immediately, no Decline button, arrival sound plays
// ✅ If app killed/locked → CallKitHandler handles auto-connect

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/core/services/callkit_handler.dart';
import 'package:healthconnect/core/services/ringtone_service.dart';
import 'package:healthconnect/features/emergency/active_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final EmergencyCall call;

  /// true when the PARENT is the receiver (caregiver called parent).
  /// Skips ringing, connects immediately, plays arrival sound.
  final bool isParentReceiving;

  const IncomingCallScreen({
    super.key,
    required this.call,
    this.isParentReceiving = false,
  });

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

  // ✅ 5 second auto-connect timer — runs silently
  // No countdown shown on screen
  Timer? _autoConnectTimer;

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isParentReceiving) {
      // Parent receives caregiver call — connect immediately, no ringing
      _autoConnectTimer = Timer(Duration.zero, _joinCall);
    } else {
      // Caregiver receives parent call — ring and auto-connect after 5s
      _ringtoneService.startRinging();
      _autoConnectTimer = Timer(
        const Duration(seconds: 5),
        _joinCall,
      );
    }

    // Listen for caller ending the call
    _callSub = _emergencyService
        .callStream(widget.call.id)
        .listen((call) {
      if (call == null) return;
      if (call.status == CallStatus.ended) {
        _autoConnectTimer?.cancel();
        _ringtoneService.stopRinging();
        // if (mounted) Navigator.of(context).pop();


        if(mounted){
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pulseController.dispose();
    _callSub?.cancel();
    _autoConnectTimer?.cancel();
    _ringtoneService.stopRinging();
    super.dispose();
  }

  // ── Join Agora — called immediately (parent) or after 5s (caregiver) ──
  Future<void> _joinCall() async {
    if (_isConnecting || !mounted) return;
    setState(() => _isConnecting = true);

    _autoConnectTimer?.cancel();
    await _ringtoneService.stopRinging();
final agoraService = AgoraCallService();

    // ✅ If CallKit already connected this exact call, skip re-joining
    // (re-joining throws -17 and strands this screen). Just show the UI.
    if (agoraService.isInCall &&
        agoraService.currentChannel == widget.call.agoraChannel) {
      debugPrint('[IncomingCallScreen] Engine already in this call — showing ActiveCallScreen');
     // CallKitHandler.markAsHandled();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(
            call: widget.call,
            agoraService: agoraService,
            isIncoming: true,
            showFallbackButton: false,
            playArrivalSound: widget.isParentReceiving,
          ),
        ),
      );
      return;
    }

// check inittalize method call
    try {
      await agoraService.initialize();
    } catch (e) {
      debugPrint(
          '[IncomingCallScreen] Agora init: $e');
    }

print(widget.call.receiverId + " is the recever id");
    final joined = await agoraService.joinChannel(
      channelName: widget.call.agoraChannel,
      token: widget.call.agoraToken,
      uid: widget.call.receiverId,
    );

    if (!joined) {
      if (mounted) {
        setState(() => _isConnecting = false);
        print("enable to join!!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not connect. Check microphone permission.')),
        );
      }
      return;
    }

    if (!mounted) return;

    // Prevent CallKit 5s timer from double-joining
  //  CallKitHandler.markAsHandled();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActiveCallScreen(
          call: widget.call,
          agoraService: agoraService,
          isIncoming: true,
          showFallbackButton: false,
          playArrivalSound: widget.isParentReceiving,
        ),
      ),
    );
  }

  // ── Decline ───────────────────────────────────────
  Future<void> _decline() async {
    _autoConnectTimer?.cancel();
    await _ringtoneService.stopRinging();
    await _emergencyService.endCall(widget.call.id);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildParentConnecting() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0000),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 24),
            Text(
              'Connecting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isParentReceiving) {
      return _buildParentConnecting();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A0000),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Emergency badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius:
                    BorderRadius.circular(30),
              ),
              child: const Text(
                '🚨  EMERGENCY CALL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Pulsing avatar
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red
                      .withValues(alpha: 0.25),
                  border: Border.all(
                      color: Colors.red, width: 3),
                ),
                child: const Icon(Icons.person,
                    size: 80, color: Colors.white),
              ),
            ),

            const SizedBox(height: 30),

            // Caller name
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
              'Your Parent Needs Help!',
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 24),

            // ✅ Connecting status — no countdown shown
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white
                        .withValues(alpha: 0.3)),
              ),
              child: _isConnecting
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Connecting...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Connecting automatically...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
            ),

            const Spacer(),

            // ✅ Decline only — no Answer button
            // User cannot answer — it auto-connects
            // But can decline if they truly cannot talk
            Column(
              children: [
                GestureDetector(
                  onTap: _isConnecting
                      ? null
                      : _decline,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.shade800,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red
                              .withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 36),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Decline',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}