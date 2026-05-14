// lib/features/emergency/calling_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthconnect/models/emergency_call_model.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/core/services/agora_call_service.dart';
import 'package:healthconnect/features/emergency/active_call_screen.dart';

class CallingScreen extends StatefulWidget {
  final String callId;
  final bool isChild;
  final String callerName;

  const CallingScreen({
    super.key,
    required this.callId,
    required this.isChild,
    required this.callerName,
  });

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen>
    with TickerProviderStateMixin {
  final _emergencyService = EmergencyService();
  late AnimationController _dotController;
  StreamSubscription? _callSub;
  String _statusText = "Calling...";
  int _attempt = 0;

  @override
  void initState() {
    super.initState();

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _listenForAnswer();
  }

  void _listenForAnswer() {
    _callSub = _emergencyService
        .callStream(widget.callId)
        .listen((call) async {
      if (call == null || !mounted) return;

      setState(() => _attempt = call.fallbackAttempt);

      switch (call.status) {
        case CallStatus.accepted:
          _callSub?.cancel();
          // Join Agora
          final agora = AgoraCallService();
          await agora.initialize();
          await agora.joinChannel(
            channelName: call.agoraChannel,
            token: call.agoraToken,
            uid: call.callerId,
          );

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ActiveCallScreen(
                call: call,
                agoraService: agora,
                isIncoming: false,
              ),
            ),
          );
          break;

        case CallStatus.rejected:
          setState(() => _statusText = "Call declined");
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.of(context).pop();
          break;

        case CallStatus.missed:
          setState(() => _statusText = "No answer from any contact");
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.of(context).pop();
          break;

        case CallStatus.ringing:
          setState(() {
            if (_attempt == 0) _statusText = "Calling primary contact...";
            if (_attempt == 1) _statusText = "Trying secondary contact...";
            if (_attempt == 2) _statusText = "Trying third contact...";
          });
          break;

        default:
          break;
      }
    });
  }

  Future<void> _cancelCall() async {
    _callSub?.cancel();
    await _emergencyService.endCall(widget.callId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _dotController.dispose();
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                "🚨 EMERGENCY CALL",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 50),

            // ── Animated calling icon ───────────────
            AnimatedBuilder(
              animation: _dotController,
              builder: (_, __) {
                return Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(
                        alpha: 0.1 + (_dotController.value * 0.2)),
                    border: Border.all(
                      color: Colors.red.withValues(
                          alpha: 0.4 + (_dotController.value * 0.6)),
                      width: 3,
                    ),
                  ),
                  child: const Icon(Icons.call,
                      size: 70, color: Colors.white),
                );
              },
            ),

            const SizedBox(height: 30),

            // ── Status ──────────────────────────────
            Text(
              _statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            // ── Fallback progress (parent flow) ─────
            if (!widget.isChild) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _attemptDot(0, "Primary"),
                  _attemptLine(_attempt >= 1),
                  _attemptDot(1, "Secondary"),
                  _attemptLine(_attempt >= 2),
                  _attemptDot(2, "Third"),
                ],
              ),
            ],

            const Spacer(),

            // ── Cancel button ───────────────────────
            GestureDetector(
              onTap: _cancelCall,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_end,
                    color: Colors.white, size: 36),
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              "Cancel",
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _attemptDot(int index, String label) {
    final isActive = _attempt == index;
    final isDone = _attempt > index;

    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? Colors.grey
                : isActive
                    ? Colors.red
                    : Colors.white24,
          ),
          child: isDone
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white38,
              fontSize: 10,
            )),
      ],
    );
  }

  Widget _attemptLine(bool filled) {
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: filled ? Colors.grey : Colors.white24,
    );
  }
}