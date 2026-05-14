import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/core/services/sos_notification_service.dart';
import 'package:healthconnect/features/emergency/active_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final EmergencyCall call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  final _emergencyService = EmergencyService();
  final _ringtoneService = RingtoneService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription? _callSub;
  Timer? _autoRejectTimer;

  @override
  void initState() {
    super.initState();

    // Keep screen on
    WakelockPlus.enable();

    // Pulsing animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start ringtone
    _ringtoneService.startRinging();

    // Auto-reject after 45s if not answered
    _autoRejectTimer = Timer(const Duration(seconds: 45), () {
      if (mounted) _onReject();
    });

    // Listen for call ending remotely (caller cancelled)
    _callSub = _emergencyService
        .callStream(widget.call.id)
        .listen((call) {
      if (call == null) return;
      if (call.status == CallStatus.ended ||
          call.status == CallStatus.rejected) {
        _closeScreen();
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pulseController.dispose();
    _callSub?.cancel();
    _autoRejectTimer?.cancel();
    _ringtoneService.stopRinging();
    super.dispose();
  }

  Future<void> _onAccept() async {
    _autoRejectTimer?.cancel();
    await _ringtoneService.stopRinging();
    await _emergencyService.acceptCall(widget.call.id);

    // Join Agora channel
    final agoraService = AgoraCallService();
    await agoraService.initialize();
    await agoraService.joinChannel(
      channelName: widget.call.agoraChannel,
      token: widget.call.agoraToken,
      uid: widget.call.receiverId,
    );

    if (!mounted) return;

    // Replace with active call screen
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

  Future<void> _onReject() async {
    await _ringtoneService.stopRinging();
    await _emergencyService.rejectCall(widget.call.id);
    _closeScreen();
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

            // ── Emergency badge ─────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

            // ── Pulsing avatar ──────────────────────
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.2),
                  border:
                      Border.all(color: Colors.red, width: 3),
                ),
                child: const Icon(
                  Icons.person,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ── Caller info ─────────────────────────
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

            const SizedBox(height: 8),

            Text(
              "Emergency Voice Call",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),

            const Spacer(),

            // ── Accept / Reject buttons ─────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Reject
                  _callButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: "Decline",
                    onTap: _onReject,
                  ),

                  // Accept
                  _callButton(
                    icon: Icons.call,
                    color: Colors.green,
                    label: "Accept",
                    onTap: _onAccept,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _callButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}