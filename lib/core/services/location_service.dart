// lib/core/services/location_service.dart
// Fixed: background location permission check
// Fixed: immediate first location upload on start
// Fixed: retry if permission not yet granted

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:healthconnect/models/location_model.dart';

class LocationService {
  static final LocationService _instance =
      LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  // ── Get caregiverId ───────────────────────────────
  Future<String?> _getCaregiverId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    final role = data['role'] as String? ?? '';

    if (role == 'caregiver') return uid;
    if (role == 'parent') {
      final cid = data['caregiverId'] as String?;
      return (cid != null && cid.isNotEmpty) ? cid : uid;
    }
    return uid;
  }

  // ── Check permissions properly ────────────────────
  // ✅ FIX: checks both foreground AND background
  // Background location is what makes it work
  // when app is not in foreground
  Future<bool> _checkPermissions() async {
    if (kIsWeb) return false;

    // Check if location service is on
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint(
          '[LocationService] Location service disabled');
      return false;
    }

    // Check foreground location
    final foreground =
        await Permission.locationWhenInUse.status;
    if (!foreground.isGranted) {
      debugPrint(
          '[LocationService] Foreground location not granted');
      return false;
    }

    // ✅ Check background location separately
    // This is what was failing before — Android requires
    // background to be granted for continuous tracking
    final background =
        await Permission.locationAlways.status;
    if (!background.isGranted) {
      debugPrint(
          '[LocationService] Background location not granted '
          '— requesting now');

      // Request background permission
      final result =
          await Permission.locationAlways.request();
      if (!result.isGranted) {
        debugPrint(
            '[LocationService] Background location denied '
            '— tracking with foreground only');
        // ✅ Still continue with foreground-only tracking
        // Better than not tracking at all
        return true;
      }
    }

    return true;
  }

  // ── START tracking ────────────────────────────────
  Future<void> startTracking() async {
    if (_isTracking || kIsWeb) return;

    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      debugPrint(
          '[LocationService] Permission denied — cannot track');
      return;
    }

    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) {
      debugPrint(
          '[LocationService] No caregiverId — skipping');
      return;
    }

    _isTracking = true;
    debugPrint(
        '[LocationService] Starting location tracking '
        'for caregiverId=$caregiverId');

    // ✅ FIX: Upload current location immediately
    // Before the stream starts — this fixes the
    // "location shows after 2-3 restarts" bug
    // First launch: stream takes time to get first position
    // Immediate upload shows location right away
    try {
      final currentPosition =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw Exception('Get position timeout'),
      );
      await _uploadLocation(
          currentPosition, caregiverId);
      debugPrint(
          '[LocationService] ✅ Immediate upload done');
    } catch (e) {
      debugPrint(
          '[LocationService] Immediate upload failed: $e');
      // Continue anyway — stream will upload when ready
    }

    // ── Init foreground task ──────────────────────
    await _initForegroundTask();

    try {
      await FlutterForegroundTask.startService(
        notificationTitle: 'HealthConnect',
        notificationText:
            'Sharing your location with caregiver',
        callback: locationCallback,
      );
    } catch (e) {
      debugPrint(
          '[LocationService] Foreground task error: $e');
      // Continue without foreground task
      // Stream will still work in foreground
    }

    // ── Location settings ─────────────────────────
    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig:
            const ForegroundNotificationConfig(
          notificationChannelName: 'Location Tracking',
          notificationTitle: 'HealthConnect',
          notificationText:
              'Sharing your location with caregiver',
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform ==
        TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    // ── Start position stream ─────────────────────
    _positionSubscription =
        Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        await _uploadLocation(position, caregiverId);
      },
      onError: (error) {
        debugPrint(
            '[LocationService] Stream error: $error');
        // ✅ Reset tracking flag so it can restart
        _isTracking = false;
      },
    );

    debugPrint(
        '[LocationService] ✅ Stream started successfully');
  }

  // ── Upload to Firestore ───────────────────────────
  Future<void> _uploadLocation(
      Position position, String caregiverId) async {
    try {
      await _firestore
          .collection('locations')
          .doc(caregiverId)
          .set({
        'caregiverId': caregiverId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed':
            position.speed >= 0 ? position.speed : 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
        'isSharing': true,
      }, SetOptions(merge: true));

      debugPrint(
          '[LocationService] Uploaded: '
          '${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint(
          '[LocationService] Upload error: $e');
    }
  }

  // ── Stream for caregiver to listen ───────────────
  Stream<ParentLocation?> parentLocationStream() async* {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) {
      yield null;
      return;
    }

    yield* _firestore
        .collection('locations')
        .doc(caregiverId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      final data = snap.data()!;
      if (data['latitude'] == null) return null;
      return ParentLocation.fromFirestore(data);
    });
  }

  // ── Stop tracking ─────────────────────────────────
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;

    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint(
          '[LocationService] Stop service error: $e');
    }

    debugPrint('[LocationService] Tracking stopped');
  }

  // ── Foreground task init ──────────────────────────
  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions:
          AndroidNotificationOptions(
        channelId: 'location_channel',
        channelName: 'Location Tracking',
        channelDescription:
            'Keeps location tracking active',
        channelImportance:
            NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions:
          const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction:
            ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        allowWakeLock: true,
      ),
    );
  }

  void dispose() {
    _positionSubscription?.cancel();
  }
}

// ── Foreground task callback ──────────────────────
@pragma('vm:entry-point')
void locationCallback() {
  FlutterForegroundTask.setTaskHandler(
      LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(
      DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Geolocator stream handles uploads
    // This just keeps foreground service alive
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}