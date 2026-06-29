// lib/core/services/agora_token_service.dart
//
// FIX (DEFECT 1): getToken() used to always return '' — which only works
// while your Agora project is in "testing mode" (App Certificate disabled).
// The moment you enable the App Certificate (required for any real release),
// every joinChannel with an empty token fails.
//
// This version asks a Cloud Function (getAgoraToken) for a real token. If the
// function isn't deployed yet, it FALLS BACK to '' so your current testing-mode
// build keeps working unchanged. So you can ship this today and turn on real
// tokens later with zero further code changes.

import 'dart:convert';
// import 'package:cloud_functions/cloud_functions.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class AgoraConfig {
  static String get appId => dotenv.env['AGORA_APP_ID'] ?? '0e25036fcf0c4892a1b0c1b834a4ca31';
  static String get appCertificate =>
      dotenv.env['AGORA_APP_CERTIFICATE'] ?? '10f415a51e3641cdb7a2a57dc041188c';

  static String generateChannelName() {
    return 'emergency_${const Uuid().v4().replaceAll('-', '')}';
  }

  /// Returns a real RTC token for [channelName] + [uid], or '' if the token
  /// server isn't available (testing mode).
  ///
  /// NOTE: the uid you pass here MUST match the integer uid actually used in
  /// AgoraCallService.joinChannel. Since your services pass a *string* uid that
  /// AgoraCallService converts via _resolveUid(), we replicate that same hash
  /// here so the token is minted for the exact integer Agora will see.
  static Future<String> getToken(String channelName, String uid) async {
    final intUid = resolveUid(uid);


// i have changes here
  //  print(intUid.toString() + " hello this is my user id in the int ");
    


    // http://straventisglobal.com/token.php

try{
    final response = await http.get(
      Uri.parse(
        'http://straventisglobal.com/token.php'
        '?channel=$channelName'
  '&uid=$uid'
      ),
    );

    return jsonDecode(response.body)['token'] ?? "";
}catch(e){
  return "";

}
return "";
  }

  /// MUST stay identical to AgoraCallService._resolveUid so the token's uid
  /// matches the join uid. Empty → 0 (Agora auto-assign).
  static int resolveUid(String raw) {
    if (raw.isEmpty) return 0;
    final h = raw.hashCode & 0x7FFFFFFF;
    return h == 0 ? 1 : h;
  }
}