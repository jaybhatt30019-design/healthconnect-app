// lib/core/services/agora_token_service.dart
//
// IMPORTANT: For production, generate tokens on your Cloud Function / backend.
// For development/testing, use a temp token from Agora console OR
// set your app certificate to "Testing mode" (no token needed).


import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

class AgoraConfig {
  static String get appId => dotenv.env['AGORA_APP_ID'] ?? '';
  static String get appCertificate => dotenv.env['AGORA_APP_CERTIFICATE'] ?? '';

  static String generateChannelName() {
    return 'emergency_${const Uuid().v4().replaceAll('-', '')}';
  }

  static Future<String> getToken(String channelName, String uid) async {
    return '';
  }
}