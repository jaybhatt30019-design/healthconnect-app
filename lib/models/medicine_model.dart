// lib/models/medicine_model.dart

import 'package:flutter/material.dart';

class Medicine {
  final String id;

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

  // ── Restock fields ────────────────────────────────
  // Universal: works for tablets, ml, drops, sachets etc.
  // unit = "tablets" | "ml" | "drops" | "sachets" | "capsules" | "puffs"
  final int stockCount;           // current quantity in hand
  final int lowStockThreshold;    // warn when at or below this
  final String stockUnit;         // what the number represents
  final DateTime? lastRestockedAt;

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
    // Restock — required, defaults keep existing docs working
    this.stockCount = 0,
    this.lowStockThreshold = 5,
    this.stockUnit = 'tablets',
    this.lastRestockedAt,
  }) : takenStatus = takenStatus ?? List.filled(times.length, false);

  // ── Stock status helpers ──────────────────────────
  bool get isLowStock => stockCount <= lowStockThreshold;
  bool get isOutOfStock => stockCount <= 0;

  StockStatus get stockStatus {
    if (isOutOfStock) return StockStatus.out;
    if (isLowStock) return StockStatus.low;
    return StockStatus.ok;
  }

  String get stockDisplay => '$stockCount $stockUnit';

  // ── FROM FIRESTORE ────────────────────────────────
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
      // Restock — safe defaults for existing docs without these fields
      stockCount: (data['stockCount'] as num?)?.toInt() ?? 0,
      lowStockThreshold:
          (data['lowStockThreshold'] as num?)?.toInt() ?? 5,
      stockUnit: data['stockUnit'] as String? ?? 'tablets',
      lastRestockedAt: data['lastRestockedAt'] != null
          ? DateTime.tryParse(data['lastRestockedAt'])
          : null,
    );
  }

  // ── TO FIRESTORE ──────────────────────────────────
  Map<String, dynamic> toMap({bool isNew = false}) {
    final map = <String, dynamic>{
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
      // Restock
      "stockCount": stockCount,
      "lowStockThreshold": lowStockThreshold,
      "stockUnit": stockUnit,
      "lastRestockedAt": lastRestockedAt?.toIso8601String(),
    };

    if (isNew) {
      map["createdAt"] = DateTime.now().toIso8601String();
    }

    return map;
  }

  // ── copyWith for stock updates ────────────────────
  Medicine copyWith({
    int? stockCount,
    int? lowStockThreshold,
    String? stockUnit,
    DateTime? lastRestockedAt,
    List<bool>? takenStatus,
  }) {
    return Medicine(
      id: id,
      name: name,
      dosage: dosage,
      disease: disease,
      intake: intake,
      duration: duration,
      doctor: doctor,
      notes: notes,
      startDate: startDate,
      times: times,
      takenStatus: takenStatus ?? this.takenStatus,
      stockCount: stockCount ?? this.stockCount,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      stockUnit: stockUnit ?? this.stockUnit,
      lastRestockedAt: lastRestockedAt ?? this.lastRestockedAt,
    );
  }
}

enum StockStatus { ok, low, out }