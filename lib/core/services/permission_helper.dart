// lib/core/services/permission_helper.dart
// Requests ALL required permissions on first launch
// Correct order — foreground location before background

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {

  // ── Request all permissions on app launch ─────────
  // Must be called in correct order:
  // 1. Basic permissions first (mic, camera, notification)
  // 2. Foreground location second
  // 3. Background location ONLY after foreground granted
  // 4. Special permissions last (exact alarm, system alert)
  static Future<void> requestAll(
      BuildContext context) async {

    // ── Step 1: Basic permissions ──────────────────
    // Request all at once — Android shows one dialog
    final basicResults = await [
      Permission.microphone,
      Permission.notification,
      Permission.camera,
      Permission.phone,
    ].request();

    debugPrint('[PermissionHelper] Basic permissions: '
        'mic=${basicResults[Permission.microphone]}, '
        'notif=${basicResults[Permission.notification]}, '
        'camera=${basicResults[Permission.camera]}, '
        'phone=${basicResults[Permission.phone]}');

    // ── Step 2: Foreground location ────────────────
    // Must be separate from background location
    final locationResult =
        await Permission.locationWhenInUse.request();

    debugPrint('[PermissionHelper] '
        'Location foreground: $locationResult');

    // ── Step 3: Background location ────────────────
    // ✅ CRITICAL — only request AFTER foreground granted
    // Android blocks background if foreground not granted first
    if (locationResult.isGranted) {
      final bgResult =
          await Permission.locationAlways.request();
      debugPrint('[PermissionHelper] '
          'Location background: $bgResult');
    }

    // ── Step 4: Exact alarm ────────────────────────
    // Needed for medicine reminders to fire exactly on time
    final alarmResult =
        await Permission.scheduleExactAlarm.request();
    debugPrint('[PermissionHelper] '
        'Exact alarm: $alarmResult');

    // ── Step 5: System alert window ───────────────
    // Needed for incoming call screen over lock screen
    if (!await Permission.systemAlertWindow.isGranted) {
      await Permission.systemAlertWindow.request();
    }

    // ── Step 6: Show dialog for critical denials ───
    if (!context.mounted) return;

    final micGranted =
        basicResults[Permission.microphone]?.isGranted ??
            false;
    final notifGranted =
        basicResults[Permission.notification]?.isGranted ??
            false;
    final locationGranted = locationResult.isGranted;

    // Only show dialog if critical permissions denied
    final missing = <String>[];
    if (!micGranted) {
      missing.add("Microphone — needed for voice calls");
    }
    if (!notifGranted) {
      missing.add("Notifications — needed for medicine reminders");
    }
    if (!locationGranted) {
      missing.add("Location — needed to share with caregiver");
    }

    if (missing.isNotEmpty && context.mounted) {
      _showPermissionDialog(context, missing);
    }
  }

  // ── Permission dialog ──────────────────────────────
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
                "Permissions Required",
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
              "HealthConnect needs these permissions "
              "to keep you and your family safe:",
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
                      child: Text(
                        m,
                        style: const TextStyle(
                            fontSize: 13),
                      ),
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
                "Without these, emergency calls and "
                "medicine reminders may not work.",
                style: TextStyle(
                    color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Skip for now",
              style: TextStyle(color: Colors.grey),
            ),
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
              "Open Settings",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}