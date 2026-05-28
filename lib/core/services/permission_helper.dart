// lib/core/services/permission_helper.dart
// Only shows explanation dialogs when permissions
// are not already granted — never shows again after granted

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {

  static Future<void> requestAll(
      BuildContext context) async {

    // ── Step 1: Basic permissions ──────────────────
    // Check first — only request if not already granted
    final micGranted =
        await Permission.microphone.isGranted;
    final notifGranted =
        await Permission.notification.isGranted;
    final cameraGranted =
        await Permission.camera.isGranted;
    final phoneGranted =
        await Permission.phone.isGranted;

    // Only request the ones not granted
    final toRequest = <Permission>[];
    if (!micGranted) { toRequest.add(Permission.microphone); }
    if (!notifGranted)
      { toRequest.add(Permission.notification); }
    if (!cameraGranted) { toRequest.add(Permission.camera); }
    if (!phoneGranted) { toRequest.add(Permission.phone); }

    Map<Permission, PermissionStatus> basicResults = {};
    if (toRequest.isNotEmpty) {
      basicResults = await toRequest.request();
    }

    debugPrint('[PermissionHelper] Basic: '
        'mic=${micGranted || (basicResults[Permission.microphone]?.isGranted ?? false)}, '
        'notif=${notifGranted || (basicResults[Permission.notification]?.isGranted ?? false)}');

    // ── Step 2: Location — check ALL statuses first ──
    // ✅ Skip EVERYTHING if background already granted
    final bgAlreadyGranted =
        await Permission.locationAlways.isGranted;

    if (!bgAlreadyGranted) {
      if (!context.mounted) return;

      // Check foreground status
      final fgAlreadyGranted =
          await Permission.locationWhenInUse.isGranted;

      // ✅ Show explanation only if foreground not granted
      // i.e. very first time asking for location
      if (!fgAlreadyGranted) {
        if (!context.mounted) return;
        await _showLocationExplanationDialog(context);
        if (!context.mounted) return;
      }

      // Request foreground if not granted
      PermissionStatus locationResult =
          PermissionStatus.denied;
      if (!fgAlreadyGranted) {
        locationResult =
            await Permission.locationWhenInUse.request();
      } else {
        locationResult = PermissionStatus.granted;
      }

      debugPrint('[PermissionHelper] '
          'Location foreground: $locationResult');

      // Request background if foreground granted
      if (locationResult.isGranted) {
        final bgStatus =
            await Permission.locationAlways.status;

        if (!bgStatus.isGranted) {
          // Show explanation before background request
          if (context.mounted) {
            await _showBackgroundLocationDialog(context);
            if (!context.mounted) return;
          }

          final bgResult =
              await Permission.locationAlways.request();
          debugPrint('[PermissionHelper] '
              'Location background: $bgResult');

          // If still denied after request — show settings guide
          if (!bgResult.isGranted && context.mounted) {
            await _showGoToSettingsDialog(context);
          }
        }
      }
    } else {
      debugPrint('[PermissionHelper] '
          'Location already granted — skipping dialogs');
    }

    // ── Step 3: Exact alarm ────────────────────────
    final alarmGranted =
        await Permission.scheduleExactAlarm.isGranted;
    if (!alarmGranted) {
      await Permission.scheduleExactAlarm.request();
    }

    // ── Step 4: System alert window ───────────────
    if (!await Permission.systemAlertWindow.isGranted) {
      await Permission.systemAlertWindow.request();
    }

    // ── Step 5: Show dialog for critical denials ───
    if (!context.mounted) return;

    final finalMicGranted =
        micGranted ||
        (basicResults[Permission.microphone]?.isGranted ??
            false);
    final finalNotifGranted =
        notifGranted ||
        (basicResults[Permission.notification]?.isGranted ??
            false);

    final missing = <String>[];
    if (!finalMicGranted) {
      missing.add(
          'Microphone — needed for voice calls');
    }
    if (!finalNotifGranted) {
      missing.add(
          'Notifications — needed for medicine reminders');
    }

    if (missing.isNotEmpty && context.mounted) {
      _showPermissionDialog(context, missing);
    }
  }

  // ── Location explanation dialog ────────────────────
  // Shows only on FIRST time — before foreground request
  static Future<void> _showLocationExplanationDialog(
      BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFF0E7C6B),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Location Permission',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your caregiver needs to see your '
              'location at all times — even when '
              'HealthConnect is running in the background '
              'or your screen is off.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.touch_app,
                          color: Colors.amber.shade700,
                          size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'On the next screen:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _instructionStep(
                    '1',
                    'Tap "Allow all the time"',
                    isImportant: true,
                  ),
                  const SizedBox(height: 6),
                  _instructionStep(
                    '✗',
                    'Do NOT tap "Allow only while using"',
                    isWarning: true,
                  ),
                  const SizedBox(height: 6),
                  _instructionStep(
                    '✗',
                    'Do NOT tap "Deny"',
                    isWarning: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.shield,
                      color: Color(0xFF2E7D32),
                      size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your location is only shared '
                      'with your caregiver — never '
                      'stored or shared with anyone else.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2E7D32),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E7C6B),
              minimumSize:
                  const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it — Show permission',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Background location dialog ─────────────────────
  // Shows before the background permission request
  static Future<void> _showBackgroundLocationDialog(
      BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.location_searching,
                color: Colors.orange.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'One More Step',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Android needs you to confirm that '
              'HealthConnect can access your location '
              'in the background.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.touch_app,
                          color: Colors.orange.shade700,
                          size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'On the settings screen:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _instructionStep(
                    '1',
                    'Tap "Allow all the time"',
                    isImportant: true,
                  ),
                  const SizedBox(height: 6),
                  _instructionStep(
                    '2',
                    'Then tap the back button to return',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: const [
                Icon(Icons.info_outline,
                    size: 14,
                    color: Color(0xFF78909C)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Without this, your caregiver '
                    'cannot see your location when '
                    'you need help.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78909C),
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              minimumSize:
                  const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Open location settings',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Go to settings dialog ──────────────────────────
  // Shows if background still denied after request
  static Future<void> _showGoToSettingsDialog(
      BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade600),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Location Not Set',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Background location was not granted. '
              'Your caregiver will not be able to '
              'track your location.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'To fix this manually:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _instructionStep(
                      '1', 'Tap "Open Settings" below'),
                  const SizedBox(height: 4),
                  _instructionStep(
                      '2', 'Tap "Permissions"'),
                  const SizedBox(height: 4),
                  _instructionStep('3', 'Tap "Location"'),
                  const SizedBox(height: 4),
                  _instructionStep(
                    '4',
                    'Select "Allow all the time"',
                    isImportant: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip for now',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E7C6B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            icon: const Icon(Icons.settings,
                color: Colors.white, size: 18),
            label: const Text(
              'Open Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Other permissions denied dialog ───────────────
  static void _showPermissionDialog(
    BuildContext context,
    List<String> missing,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.security,
                color: Colors.orange.shade700),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Permissions Required',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HealthConnect needs these permissions '
              'to keep you and your family safe:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...missing.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade600,
                        size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(m,
                          style: const TextStyle(
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Without these, emergency calls and '
                'medicine reminders may not work.',
                style: TextStyle(
                    color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip for now',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            icon: const Icon(Icons.settings,
                color: Colors.white, size: 18),
            label: const Text(
              'Open Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Instruction step helper ────────────────────────
  static Widget _instructionStep(
    String number,
    String text, {
    bool isImportant = false,
    bool isWarning = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isWarning
                ? Colors.red.shade100
                : isImportant
                    ? const Color(0xFF0E7C6B)
                    : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isWarning
                    ? Colors.red.shade700
                    : isImportant
                        ? Colors.white
                        : Colors.grey.shade700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isImportant
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: isWarning
                  ? Colors.red.shade700
                  : isImportant
                      ? const Color(0xFF004D40)
                      : Colors.grey.shade800,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}