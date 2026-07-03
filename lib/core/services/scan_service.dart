// lib/core/services/scan_service.dart
// ✅ API key loaded from .env file — never hardcoded
// .env is in .gitignore so it never goes to GitHub

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:Vitanex/models/scan_result_model.dart';

class ScanService {
  // ✅ Key loaded from .env at runtime
  // Never hardcoded, never committed to git
  static String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY not found in .env file.\n'
        'Create a .env file in your project root with:\n'
        'GEMINI_API_KEY=your_key_here\n'
        'Get a free key at: https://aistudio.google.com',
      );
    }
    return key;
  }

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const _models = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-flash',
  ];

  static const _prompt = '''
You are a medical document scanner for a health app.

Read this medical document image and extract ALL visible data.
Return ONLY a valid JSON object. No markdown fences. No explanation.
Start directly with { and end with }.

{
  "documentType": "lab_report | prescription | discharge_summary | blood_report | other",
  "documentDate": "YYYY-MM-DD or null",
  "hospitalName": "string or null",
  "doctorName": "string or null",
  "rawNotes": "string or null",
  "passport": {
    "bloodGroup": "A+ | A- | B+ | B- | O+ | O- | AB+ | AB- | null",
    "heightCm": null,
    "weightKg": null,
    "bloodPressureSystolic": null,
    "bloodPressureDiastolic": null,
    "oxygenLevel": null,
    "heartRate": null,
    "bloodSugarFasting": null,
    "bloodSugarPostMeal": null,
    "cholesterol": null,
    "temperatureF": null,
    "allergies": [],
    "chronicConditions": [],
    "disabilities": null
  },
  "medicines": [
    {
      "name": "string",
      "dosage": "string",
      "disease": null,
      "intake": null,
      "duration": null,
      "doctor": null,
      "stockCount": null,
      "stockUnit": null
    }
  ],
  "illnesses": [
    {
      "name": "string",
      "diagnosedDate": null,
      "severity": "mild",
      "doctor": null,
      "notes": null,
      "isOngoing": true
    }
  ],
  "surgeries": [
    {
      "name": "string",
      "date": null,
      "hospital": null,
      "surgeon": null,
      "notes": null
    }
  ]
}

Rules:
- All numbers as plain numbers not strings (120 not "120 mmHg")
- bloodPressureSystolic = higher BP number, bloodPressureDiastolic = lower
- Empty sections: [] for arrays, null for objects
- Allergies anywhere in doc go into passport.allergies array
- Chronic/long-term conditions go into passport.chronicConditions array
- rawNotes: anything that does not fit above fields as plain text
- Never invent data not visible in the document
- Keep all string values short — no long sentences inside string fields
''';

  Future<ScanResult> scanDocument(Uint8List imageBytes) async {
    // _apiKey getter will throw if key not configured
    final key = _apiKey;

    final mimeType = _detectMimeType(imageBytes);
    final base64Image = base64Encode(imageBytes);

    debugPrint(
        '[ScanService] ${(imageBytes.length / 1024).toStringAsFixed(0)}KB $mimeType');

    Exception? lastError;
    for (final model in _models) {
      try {
        debugPrint('[ScanService] Trying: $model');
        return await _callGemini(
          model: model,
          base64Image: base64Image,
          mimeType: mimeType,
          apiKey: key,
        );
      } on _ModelNotFoundException {
        debugPrint('[ScanService] $model → 404, next...');
        lastError = Exception('$model not found');
        continue;
      } catch (e) {
        rethrow;
      }
    }
    throw lastError ?? Exception('No working Gemini model');
  }

  Future<ScanResult> _callGemini({
    required String model,
    required String base64Image,
    required String mimeType,
    required String apiKey,
  }) async {
    final url =
        '$_baseUrl/$model:generateContent?key=$apiKey';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              },
            },
            {'text': _prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 8192,
        'responseMimeType': 'application/json',
      },
    });

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(
          const Duration(seconds: 90),
          onTimeout: () =>
              throw Exception('Timed out. Try again.'),
        );

    debugPrint(
        '[ScanService] $model → ${response.statusCode}');

    if (response.statusCode == 404) {
      throw _ModelNotFoundException(model);
    }
    if (response.statusCode == 429) {
      throw Exception(
          'Rate limit hit. Wait 30 seconds and try again.');
    }
    if (response.statusCode == 400) {
      final decoded = jsonDecode(response.body);
      final msg =
          decoded['error']?['message'] ?? 'Bad request';
      debugPrint('[ScanService] 400: $msg');
      if (msg.contains('responseMimeType') ||
          msg.contains('not supported')) {
        return await _callGeminiPlain(
          model: model,
          base64Image: base64Image,
          mimeType: mimeType,
          apiKey: apiKey,
        );
      }
      throw Exception('Scan error: $msg');
    }
    if (response.statusCode == 403) {
      throw Exception(
          'Invalid API key. Check aistudio.google.com');
    }
    if (response.statusCode != 200) {
      debugPrint('[ScanService] Error: ${response.body}');
      throw Exception(
          'Scan failed (${response.statusCode})');
    }

    return _parseResponse(response.body);
  }

  Future<ScanResult> _callGeminiPlain({
    required String model,
    required String base64Image,
    required String mimeType,
    required String apiKey,
  }) async {
    final url =
        '$_baseUrl/$model:generateContent?key=$apiKey';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              },
            },
            {'text': _prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 8192,
      },
    });

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(
          const Duration(seconds: 90),
          onTimeout: () =>
              throw Exception('Timed out. Try again.'),
        );

    debugPrint(
        '[ScanService] $model plain → ${response.statusCode}');

    if (response.statusCode == 404) {
      throw _ModelNotFoundException(model);
    }
    if (response.statusCode != 200) {
      throw Exception(
          'Scan failed (${response.statusCode})');
    }

    return _parseResponse(response.body);
  }

  ScanResult _parseResponse(String responseBody) {
    final data =
        jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = data['candidates'] as List? ?? [];

    if (candidates.isEmpty) {
      throw Exception(
          'No response from Gemini. Try again.');
    }

    final finishReason =
        candidates[0]['finishReason'] as String? ?? '';
    debugPrint(
        '[ScanService] finishReason: $finishReason');

    if (finishReason == 'SAFETY') {
      throw Exception(
          'Image blocked by safety filters. '
          'Try a different photo.');
    }

    final content = candidates[0]['content']
        as Map<String, dynamic>? ?? {};
    final parts = content['parts'] as List? ?? [];

    if (parts.isEmpty) {
      throw Exception('Empty response. Try again.');
    }

    final rawText = parts[0]['text'] as String? ?? '';
    debugPrint(
        '[ScanService] Response: ${rawText.length} chars');

    if (rawText.isEmpty) {
      throw Exception('No text returned.');
    }

    var cleaned = rawText.trim();
    for (final prefix in [
      '```json\n',
      '```json',
      '```\n',
      '```'
    ]) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length);
        break;
      }
    }
    if (cleaned.endsWith('```')) {
      cleaned =
          cleaned.substring(0, cleaned.length - 3).trim();
    }

    final start = cleaned.indexOf('{');
    if (start == -1) {
      throw Exception(
          'Could not read document data. '
          'Ensure photo shows the full document.');
    }

    final end = cleaned.lastIndexOf('}');
    String jsonStr;

    if (end == -1 || end <= start) {
      debugPrint(
          '[ScanService] Truncated JSON — repairing...');
      jsonStr =
          _repairTruncatedJson(cleaned.substring(start));
    } else {
      jsonStr = cleaned.substring(start, end + 1);
    }

    try {
      final parsed =
          jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = ScanResult.fromJson(parsed);

      debugPrint('[ScanService] ✅ Success — '
          'medicines=${result.medicines.length}, '
          'illnesses=${result.illnesses.length}, '
          'hasPassport=${result.hasPassportData}');

      return result;
    } on FormatException catch (e) {
      debugPrint('[ScanService] JSON error: $e');
      try {
        final minimal = _extractMinimal(cleaned);
        if (minimal != null) return minimal;
      } catch (_) {}
      throw Exception(
          'Could not parse scan results. Please try again.');
    }
  }

  ScanResult? _extractMinimal(String text) {
    final doctorMatch =
        RegExp(r'"doctorName"\s*:\s*"([^"]*)"')
            .firstMatch(text);
    final hospitalMatch =
        RegExp(r'"hospitalName"\s*:\s*"([^"]*)"')
            .firstMatch(text);
    final rawMatch =
        RegExp(r'"rawNotes"\s*:\s*"([^"]*)"')
            .firstMatch(text);
    final typeMatch =
        RegExp(r'"documentType"\s*:\s*"([^"]*)"')
            .firstMatch(text);

    if (rawMatch == null && doctorMatch == null) return null;

    return ScanResult(
      documentType: typeMatch?.group(1) ?? 'other',
      doctorName: doctorMatch?.group(1),
      hospitalName: hospitalMatch?.group(1),
      rawNotes: rawMatch?.group(1) ??
          'Document scanned but could not fully parse.',
      medicines: [],
      illnesses: [],
      surgeries: [],
    );
  }

  String _repairTruncatedJson(String partial) {
    final buffer = StringBuffer(partial);
    int braces = 0;
    int brackets = 0;
    bool inString = false;
    bool escaped = false;

    for (final charCode in partial.runes) {
      final c = String.fromCharCode(charCode);
      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == '\\' && inString) {
        escaped = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (!inString) {
        if (c == '{') braces++;
        if (c == '}') braces--;
        if (c == '[') brackets++;
        if (c == ']') brackets--;
      }
    }

    if (inString) buffer.write('": null');
    for (int i = 0; i < brackets; i++) {
      buffer.write(']');
    }
    for (int i = 0; i < braces; i++) {
      buffer.write('}');
    }

    return buffer.toString();
  }

  String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    return 'image/jpeg';
  }
}

class _ModelNotFoundException implements Exception {
  final String model;
  _ModelNotFoundException(this.model);
}