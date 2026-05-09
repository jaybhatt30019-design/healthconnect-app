import 'package:flutter/material.dart';

class Medicine {
  final String id; // 🔥 REQUIRED FOR FIREBASE

  final String name;
  final String dosage;
  final String? disease;
  final String? intake;
  final String? duration;
  final String? doctor;
  final String? notes;
  final DateTime? startDate;

  final List<TimeOfDay> times;
  final List<bool> takenStatus;

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.times,
    this.disease,
    this.intake,
    this.duration,
    this.doctor,
    this.notes,
    this.startDate,
    List<bool>? takenStatus,
  }) : takenStatus =
            takenStatus ?? List.filled(times.length, false);

  /// 🔥 FROM FIRESTORE
  factory Medicine.fromFirestore(Map<String, dynamic> data, String id) {
    return Medicine(
      id: id,
      name: data['name'] ?? '',
      dosage: data['dosage'] ?? '',
      disease: data['disease'],
      intake: data['intake'],
      duration: data['duration'],
      doctor: data['doctor'],
      notes: data['notes'],
      startDate: data['startDate'] != null
          ? DateTime.tryParse(data['startDate'])
          : null,

      times: (data['times'] as List)
          .map((t) {
            final parts = t.split(":");
            return TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          })
          .toList(),

      takenStatus: List<bool>.from(data['takenStatus'] ?? []),
    );
  }

  /// 🔥 TO FIRESTORE
  Map<String, dynamic> toMap({bool isNew = false}) {
    final map = {
      "name": name,
      "dosage": dosage,
      "disease": disease ?? "",
      "intake": intake ?? "Before Food",
      "duration": duration ?? "Ongoing",
      "doctor": doctor ?? "",
      "notes": notes ?? "",
      "startDate": startDate?.toIso8601String(),

      "times": times
          .map((t) =>
              "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}")
          .toList(),

      "takenStatus": takenStatus,
    };

    if (isNew) {
      map["createdAt"] = DateTime.now().toIso8601String();
    }

    return map;
  }
}