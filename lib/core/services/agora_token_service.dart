// lib/core/services/agora_token_service.dart
//
// IMPORTANT: For production, generate tokens on your Cloud Function / backend.
// For development/testing, use a temp token from Agora console OR
// set your app certificate to "Testing mode" (no token needed).
//
// Replace APP_ID and APP_CERTIFICATE below.

import 'package:uuid/uuid.dart';

class AgoraConfig {
  // ─── REPLACE THESE ───────────────────────
  static const String appId = '0e25036fcf0c4892a1b0c1b834a4ca31';
  // In testing mode (no certificate), token = ''
  // In production, generate via Cloud Function
  static const String appCertificate = 'YOUR_AGORA_APP_CERTIFICATE';
  // ─────────────────────────────────────────

  /// Generate a unique channel name for each call
  static String generateChannelName() {
    return 'emergency_${const Uuid().v4().replaceAll('-', '')}';
  }

  /// For development: returns empty token (requires Testing Mode in Agora console)
  /// For production: call your backend / Cloud Function to get a real token
  static Future<String> getToken(String channelName, String uid) async {
    // TODO: Replace with your Cloud Function endpoint in production
    // Example:
    // final resp = await http.get(Uri.parse(
    //   'https://your-function.cloudfunctions.net/generateAgoraToken'
    //   '?channel=$channelName&uid=$uid'
    // ));
    // return jsonDecode(resp.body)['token'];

    // ── DEVELOPMENT: empty token (Agora Testing Mode) ──
    return '';
  }
}