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
  // ✅ endDate — reminders stop after this date
  // null means Ongoing (no end)
  final DateTime? endDate;

  final List<TimeOfDay> times;
  final List<bool> takenStatus;

  final int stockCount;
  final int lowStockThreshold;
  final String stockUnit;
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
    this.endDate,
    List<bool>? takenStatus,
    this.stockCount = 0,
    this.lowStockThreshold = 5,
    this.stockUnit = 'tablets',
    this.lastRestockedAt,
  }) : takenStatus =
            takenStatus ?? List.filled(times.length, false);

  bool get isLowStock => stockCount <= lowStockThreshold;
  bool get isOutOfStock => stockCount <= 0;

  // ✅ Whether reminders should still fire today
  bool get isActive {
    if (endDate == null) return true;
    return DateTime.now().isBefore(endDate!);
  }

  StockStatus get stockStatus {
    if (isOutOfStock) return StockStatus.out;
    if (isLowStock) return StockStatus.low;
    return StockStatus.ok;
  }

  String get stockDisplay => '$stockCount $stockUnit';

  // ── FROM FIRESTORE ────────────────────────────────
  factory Medicine.fromFirestore(
      Map<String, dynamic> data, String id) {
    final rawTakenStatus =
        List<bool>.from(data['takenStatus'] ?? []);

    // Daily reset check
    List<bool> takenStatus = rawTakenStatus;
    final lastResetStr =
        data['lastResetDate'] as String?;
    if (lastResetStr != null) {
      final lastReset = DateTime.tryParse(lastResetStr);
      if (lastReset != null) {
        final today = DateTime.now();
        final isToday = lastReset.year == today.year &&
            lastReset.month == today.month &&
            lastReset.day == today.day;
        if (!isToday) {
          final times = (data['times'] as List? ?? []);
          takenStatus = List.filled(times.length, false);
        }
      }
    }

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
      // ✅ Parse endDate from Firestore
      endDate: data['endDate'] != null
          ? DateTime.tryParse(data['endDate'])
          : null,
      times: (data['times'] as List)
          .map((t) {
            final parts = (t as String).split(':');
            return TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          })
          .toList(),
      takenStatus: takenStatus,
      stockCount:
          (data['stockCount'] as num?)?.toInt() ?? 0,
      lowStockThreshold:
          (data['lowStockThreshold'] as num?)?.toInt() ??
              5,
      stockUnit:
          data['stockUnit'] as String? ?? 'tablets',
      lastRestockedAt: data['lastRestockedAt'] != null
          ? DateTime.tryParse(data['lastRestockedAt'])
          : null,
    );
  }

  // ── TO FIRESTORE ──────────────────────────────────
  Map<String, dynamic> toMap({bool isNew = false}) {
    final map = <String, dynamic>{
      'name': name,
      'dosage': dosage,
      'disease': disease ?? '',
      'intake': intake ?? 'Before Food',
      'duration': duration ?? 'Ongoing',
      'doctor': doctor ?? '',
      'notes': notes ?? '',
      'startDate': startDate?.toIso8601String(),
      // ✅ Save endDate to Firestore
      // null saved as null — means Ongoing
      'endDate': endDate?.toIso8601String(),
      'times': times
          .map((t) =>
              '${t.hour.toString().padLeft(2, '0')}:'
              '${t.minute.toString().padLeft(2, '0')}')
          .toList(),
      'takenStatus': takenStatus,
      'stockCount': stockCount,
      'lowStockThreshold': lowStockThreshold,
      'stockUnit': stockUnit,
      'lastRestockedAt':
          lastRestockedAt?.toIso8601String(),
    };

    if (isNew) {
      map['createdAt'] =
          DateTime.now().toIso8601String();
      map['lastResetDate'] =
          DateTime.now().toIso8601String();
    }

    return map;
  }

  Medicine copyWith({
    int? stockCount,
    int? lowStockThreshold,
    String? stockUnit,
    DateTime? lastRestockedAt,
    DateTime? endDate,
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
      endDate: endDate ?? this.endDate,
      times: times,
      takenStatus: takenStatus ?? this.takenStatus,
      stockCount: stockCount ?? this.stockCount,
      lowStockThreshold:
          lowStockThreshold ?? this.lowStockThreshold,
      stockUnit: stockUnit ?? this.stockUnit,
      lastRestockedAt:
          lastRestockedAt ?? this.lastRestockedAt,
    );
  }
}

enum StockStatus { ok, low, out }