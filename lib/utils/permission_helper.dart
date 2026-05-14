// lib/core/utils/permission_helper.dart
//
// Call PermissionHelper.requestAll() on first app launch or before
// the first emergency call. Best place: after login in AuthGate.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {

  /// Request all permissions needed for the emergency system.
  /// Returns true if critical permissions (mic + notification) are granted.
  static Future<bool> requestAll(BuildContext context) async {
    final results = await [
      Permission.microphone,
      Permission.notification,
      Permission.phone,         // needed on Android for call state
    ].request();

    final micGranted =
        results[Permission.microphone] == PermissionStatus.granted;
    final notifGranted =
        results[Permission.notification] == PermissionStatus.granted;

    if (!micGranted || !notifGranted) {
      if (context.mounted) {
        _showPermissionDialog(context, micGranted, notifGranted);
      }
    }

    return micGranted && notifGranted;
  }

  static void _showPermissionDialog(
    BuildContext context,
    bool micGranted,
    bool notifGranted,
  ) {
    final missing = <String>[];
    if (!micGranted) missing.add("Microphone (for voice calls)");
    if (!notifGranted) missing.add("Notifications (for emergency alerts)");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Permissions Required"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "HealthConnect needs these permissions for the emergency system:",
            ),
            const SizedBox(height: 12),
            ...missing.map((m) => Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(m),
                  ],
                )),
            const SizedBox(height: 12),
            const Text(
              "Without these, emergency calls cannot work.",
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }
}