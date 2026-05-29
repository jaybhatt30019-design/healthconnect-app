// lib/models/medicine_model.dart

import 'package:flutter/material.dart';

/// Fixed slot order used everywhere.
/// Index 0 = Morning, 1 = Afternoon, 2 = Night
const List<String> kMedicineSlots = [
  'Morning',
  'Afternoon',
  'Night',
];

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
  final DateTime? endDate;

  final List<TimeOfDay> times;

  /// ✅ Parallel list to [times]. Each entry is the slot
  /// label ("Morning"/"Afternoon"/"Night") for the time at
  /// the same index. Preserves which slot a time belongs to
  /// so that loading back does not push afternoon into morning.
  final List<String> slots;

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
    List<String>? slots,
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
  })  : slots = slots ??
            // Fallback: assume sequential slots if not provided
            List.generate(
              times.length,
              (i) => i < kMedicineSlots.length
                  ? kMedicineSlots[i]
                  : 'Morning',
            ),
        takenStatus =
            takenStatus ?? List.filled(times.length, false);

  bool get isLowStock => stockCount <= lowStockThreshold;
  bool get isOutOfStock => stockCount <= 0;

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

  /// Slot label for a given index, safe against overflow.
  String slotLabelAt(int index) {
    if (index >= 0 && index < slots.length) {
      return slots[index];
    }
    if (index >= 0 && index < kMedicineSlots.length) {
      return kMedicineSlots[index];
    }
    return 'Morning';
  }

  // ── FROM FIRESTORE ────────────────────────────────
  factory Medicine.fromFirestore(
      Map<String, dynamic> data, String id) {
    // Parse times
    final rawTimes = (data['times'] as List? ?? []);
    final times = rawTimes.map((t) {
      final parts = (t as String).split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }).toList();

    // ✅ Parse slots. Old medicines have no 'slots' field —
    // fall back to sequential mapping so they keep working.
    List<String> slots;
    final rawSlots = data['slots'] as List?;
    if (rawSlots != null &&
        rawSlots.length == times.length) {
      slots = rawSlots.map((s) => s.toString()).toList();
    } else {
      slots = List.generate(
        times.length,
        (i) => i < kMedicineSlots.length
            ? kMedicineSlots[i]
            : 'Morning',
      );
    }

    // takenStatus
    List<bool> takenStatus =
        List<bool>.from(data['takenStatus'] ?? []);

    // Daily reset check
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
          takenStatus = List.filled(times.length, false);
        }
      }
    }

    // Guard: takenStatus length must match times
    if (takenStatus.length != times.length) {
      takenStatus = List.filled(times.length, false);
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
      endDate: data['endDate'] != null
          ? DateTime.tryParse(data['endDate'])
          : null,
      times: times,
      slots: slots,
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
      'endDate': endDate?.toIso8601String(),
      'times': times
          .map((t) =>
              '${t.hour.toString().padLeft(2, '0')}:'
              '${t.minute.toString().padLeft(2, '0')}')
          .toList(),
      // ✅ Save slots parallel to times
      'slots': slots,
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
      slots: slots,
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