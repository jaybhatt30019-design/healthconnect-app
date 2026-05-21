// lib/features/emergency/calling_screen.dart
// Auto-connect flow: both sides join immediately
// No accept/decline buttons on either side

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
  State<CallingScreen> createState() =>
      _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen>
    with TickerProviderStateMixin {
  final _emergencyService = EmergencyService();
  late AnimationController _dotController;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // ✅ Auto-join Agora immediately
    // No waiting for the other side to accept
    _joinCallImmediately();
  }

  Future<void> _joinCallImmediately() async {
    if (_isJoining) return;
    setState(() => _isJoining = true);

    try {
      // Get call data from Firestore
      final call = await _emergencyService
          .callStream(widget.callId)
          .first;

      if (call == null || !mounted) return;

      final agora = AgoraCallService();

      // ✅ Wrap setEnableSpeakerphone in try-catch
      // Agora error -3 on some devices is non-fatal
      try {
        await agora.initialize();
      } catch (e) {
        debugPrint(
            '[CallingScreen] Agora init warning: $e');
        // Continue anyway — call can still work
      }

      try {
        await agora.joinChannel(
          channelName: call.agoraChannel,
          token: call.agoraToken,
          uid: call.callerId,
        );
      } catch (e) {
        debugPrint(
            '[CallingScreen] Join channel error: $e');
        if (mounted) {
          _showError('Could not connect to call');
        }
        return;
      }

      if (!mounted) return;

      // Navigate to active call screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(
            call: call,
            agoraService: agora,
            isIncoming: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[CallingScreen] Error: $e');
      if (mounted) _showError('Call failed. Try again.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
    Navigator.of(context).pop();
  }

  Future<void> _cancelCall() async {
    await _emergencyService.endCall(widget.callId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _dotController.dispose();
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

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
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

            // Animated calling icon
            AnimatedBuilder(
              animation: _dotController,
              builder: (_, __) {
                return Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(
                        alpha: 0.1 +
                            (_dotController.value * 0.2)),
                    border: Border.all(
                      color: Colors.red.withValues(
                          alpha: 0.4 +
                              (_dotController.value * 0.6)),
                      width: 3,
                    ),
                  ),
                  child: const Icon(Icons.call,
                      size: 70, color: Colors.white),
                );
              },
            ),

            const SizedBox(height: 30),

            Text(
              _isJoining
                  ? "Connecting..."
                  : "Starting call...",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              "Emergency contacts are being notified",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
              ),
            ),

            const Spacer(),

            // Cancel button
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
              "End Call",
              style: TextStyle(
                  color: Colors.white60, fontSize: 13),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}