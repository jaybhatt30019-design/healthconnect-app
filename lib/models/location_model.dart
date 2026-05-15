// lib/models/location_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ParentLocation {
  final String caregiverId;
  final double latitude;
  final double longitude;
  final double accuracy;    // meters
  final double? speed;      // m/s, null if stationary
  final DateTime updatedAt;
  final bool isSharing;     // parent can turn off sharing

  ParentLocation({
    required this.caregiverId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speed,
    required this.updatedAt,
    required this.isSharing,
  });

  factory ParentLocation.fromFirestore(Map<String, dynamic> data) {
    return ParentLocation(
      caregiverId: data['caregiverId'] ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      accuracy: (data['accuracy'] as num? ?? 0).toDouble(),
      speed: (data['speed'] as num?)?.toDouble(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isSharing: data['isSharing'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'caregiverId': caregiverId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'updatedAt': FieldValue.serverTimestamp(),
      'isSharing': isSharing,
    };
  }
}