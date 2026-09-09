import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Vitanex/core/services/agora_call_service.dart';
import 'package:Vitanex/features/emergency/active_call_screen.dart';
import 'package:Vitanex/models/emergency_call_model.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
// import 'package:audioplayers/audioplayers.dart';
class AutoJoinScreen
    extends StatefulWidget {

  final String channel;
  final String token;
final String callId;
  const AutoJoinScreen({
    super.key,
    required this.channel,
    required this.token,  required this.callId,
  });

  @override
  State<AutoJoinScreen> createState()
      => _AutoJoinScreenState();
}

class _AutoJoinScreenState
    extends State<AutoJoinScreen> {
// final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
   
    super.dispose();
  }
  Future<void> _connect() async {
   FlutterRingtonePlayer().playAlarm(
    looping: true,
    asAlarm: true,   // routes to alarm volume = loudest, audible across the room
    volume: 1.0,
  );


    final agora =
        AgoraCallService();

    await agora.initialize();

    await agora.joinChannel(
      channelName: widget.channel,
      token: widget.token,
      uid: FirebaseAuth
          .instance
          .currentUser!
          .uid,
    );
// Timer(Duration(seconds: 3),(){

FlutterRingtonePlayer().stop();
// });
    if (!mounted) return;
    EmergencyCall? call;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('emergency_calls')
          .doc(widget.callId)
          .get();

      if (doc.exists) {
        call = EmergencyCall.fromFirestore(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint('[AutoJoinScreen] Failed to fetch call doc: $e');
    }

    call ??= EmergencyCall(
      id: widget.callId,
      callerId: '',
      callerName: 'Emergency Call',
      callerRole: CallerRole.child,
      receiverId: '',
      caregiverId: '',
      status: CallStatus.accepted,
      agoraChannel: widget.channel,
      agoraToken: widget.token,
      fallbackAttempt: 0,
      createdAt: DateTime.now(),
    );

    if (!mounted) return;
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => ActiveCallScreen(
      agoraService: agora,
      isIncoming: true,
      call: call!,
      playArrivalSound: true,   // receiver — vibrate/alert once connected
    ),
  ),
);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child:
            CircularProgressIndicator(),
      ),
    );
  }
}