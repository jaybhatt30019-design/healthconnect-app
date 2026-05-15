// lib/core/services/ringtone_service.dart
//
// Place at: lib/core/services/ringtone_service.dart

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  factory RingtoneService() => _instance;
  RingtoneService._internal();

  bool _isRinging = false;

  Future<void> startRinging() async {
    if (_isRinging) return;
    _isRinging = true;

    // Vibration — emergency pattern, repeats
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
        pattern: [0, 500, 200, 500, 200, 500, 1000],
        repeat: 0,
      );
    }

    // Fallback system sound
    await SystemSound.play(SystemSoundType.alert);
  }

  Future<void> stopRinging() async {
    if (!_isRinging) return;
    _isRinging = false;
    Vibration.cancel();
  }
}