// lib/core/services/location_service.dart
// Always-on version — no toggle, tracks automatically for parent

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:healthconnect/models/location_model.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  // ─────────────────────────────────────────────────────
  // Get caregiverId
  // ─────────────────────────────────────────────────────
  Future<String?> _getCaregiverId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
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

  // ─────────────────────────────────────────────────────
  // Request location permissions
  // ─────────────────────────────────────────────────────
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  // ─────────────────────────────────────────────────────
  // START tracking — called automatically on parent login
  // ─────────────────────────────────────────────────────
  Future<void> startTracking() async {
    if (_isTracking || kIsWeb) return;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('[LocationService] Permission denied — cannot track');
      return;
    }

    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    _isTracking = true;
    debugPrint('[LocationService] Auto-starting location tracking');

    // ── Init and start foreground service ─────────────
    await _initForegroundTask();
    await FlutterForegroundTask.startService(
      notificationTitle: 'HealthConnect',
      notificationText: 'Sharing your location with caregiver',
      callback: locationCallback,
    );

    // ── Location settings per platform ────────────────
    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationChannelName: 'Location Tracking',
          notificationTitle: 'HealthConnect',
          notificationText: 'Sharing your location with caregiver',
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
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

    // ── Start streaming position to Firestore ─────────
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        await _uploadLocation(position, caregiverId);
      },
      onError: (error) {
        debugPrint('[LocationService] Stream error: $error');
      },
    );
  }

  // ─────────────────────────────────────────────────────
  // Upload to Firestore — /locations/{caregiverId}
  // One document per pair, overwrites each update
  // ─────────────────────────────────────────────────────
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
        'speed': position.speed >= 0 ? position.speed : 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
        'isSharing': true,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[LocationService] Upload error: $e');
    }
  }

  // ─────────────────────────────────────────────────────
  // STREAM — caregiver listens to parent location
  // ─────────────────────────────────────────────────────
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
      // location field must exist
      if (data['latitude'] == null) return null;
      return ParentLocation.fromFirestore(data);
    });
  }

  // ─────────────────────────────────────────────────────
  // Foreground task init
  // ─────────────────────────────────────────────────────
  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_channel',
        channelName: 'Location Tracking',
        channelDescription: 'Keeps location tracking active',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        allowWakeLock: true,
      ),
    );
  }

  void dispose() {
    _positionSubscription?.cancel();
  }
}

// ─────────────────────────────────────────────────────
// Foreground task callback — top-level required
// ─────────────────────────────────────────────────────
@pragma('vm:entry-point')
void locationCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Geolocator stream handles uploads — this just keeps service alive
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}