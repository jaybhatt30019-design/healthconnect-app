// lib/models/health_passport_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum BloodGroup { aPos, aNeg, bPos, bNeg, oPos, oNeg, abPos, abNeg, unknown }

extension BloodGroupLabel on BloodGroup {
  String get label {
    switch (this) {
      case BloodGroup.aPos: return 'A+';
      case BloodGroup.aNeg: return 'A-';
      case BloodGroup.bPos: return 'B+';
      case BloodGroup.bNeg: return 'B-';
      case BloodGroup.oPos: return 'O+';
      case BloodGroup.oNeg: return 'O-';
      case BloodGroup.abPos: return 'AB+';
      case BloodGroup.abNeg: return 'AB-';
      case BloodGroup.unknown: return 'Unknown';
    }
  }

  static BloodGroup fromString(String? s) {
    switch (s) {
      case 'A+': return BloodGroup.aPos;
      case 'A-': return BloodGroup.aNeg;
      case 'B+': return BloodGroup.bPos;
      case 'B-': return BloodGroup.bNeg;
      case 'O+': return BloodGroup.oPos;
      case 'O-': return BloodGroup.oNeg;
      case 'AB+': return BloodGroup.abPos;
      case 'AB-': return BloodGroup.abNeg;
      default: return BloodGroup.unknown;
    }
  }
}

class HealthPassport {
  final String caregiverId;

  // ── Basic vitals ─────────────────────────────────
  final BloodGroup bloodGroup;
  final double? heightCm;
  final double? weightKg;

  // ── Readings ─────────────────────────────────────
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? oxygenLevel;       // SpO2 %
  final int? heartRate;         // bpm
  final int? bloodSugarFasting; // mg/dL
  final int? bloodSugarPostMeal;
  final int? cholesterol;
  final double? temperatureF;
  final DateTime? readingsUpdatedAt;

  // ── Lists ─────────────────────────────────────────
  final List<String> allergies;
  final List<String> chronicConditions;
  final String disabilities;

  final DateTime? updatedAt;
  final String? updatedBy;

  HealthPassport({
    required this.caregiverId,
    this.bloodGroup = BloodGroup.unknown,
    this.heightCm,
    this.weightKg,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.oxygenLevel,
    this.heartRate,
    this.bloodSugarFasting,
    this.bloodSugarPostMeal,
    this.cholesterol,
    this.temperatureF,
    this.readingsUpdatedAt,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.disabilities = '',
    this.updatedAt,
    this.updatedBy,
  });

  // ── BMI auto-calculated ───────────────────────────
  double? get bmi {
    if (heightCm == null || weightKg == null) return null;
    if (heightCm! <= 0) return null;
    final heightM = heightCm! / 100;
    return weightKg! / (heightM * heightM);
  }

  String get bmiLabel {
    final b = bmi;
    if (b == null) return '';
    if (b < 18.5) return 'Underweight';
    if (b < 25) return 'Normal';
    if (b < 30) return 'Overweight';
    return 'Obese';
  }

  // ── BP display ────────────────────────────────────
  String get bpDisplay {
    if (bloodPressureSystolic == null || bloodPressureDiastolic == null) {
      return '—';
    }
    return '$bloodPressureSystolic/$bloodPressureDiastolic mmHg';
  }

  factory HealthPassport.empty(String caregiverId) => HealthPassport(
        caregiverId: caregiverId,
      );

  factory HealthPassport.fromFirestore(Map<String, dynamic> data) {
    return HealthPassport(
      caregiverId: data['caregiverId'] ?? '',
      bloodGroup: BloodGroupLabel.fromString(data['bloodGroup']),
      heightCm: (data['heightCm'] as num?)?.toDouble(),
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      bloodPressureSystolic: data['bloodPressureSystolic'] as int?,
      bloodPressureDiastolic: data['bloodPressureDiastolic'] as int?,
      oxygenLevel: data['oxygenLevel'] as int?,
      heartRate: data['heartRate'] as int?,
      bloodSugarFasting: data['bloodSugarFasting'] as int?,
      bloodSugarPostMeal: data['bloodSugarPostMeal'] as int?,
      cholesterol: data['cholesterol'] as int?,
      temperatureF: (data['temperatureF'] as num?)?.toDouble(),
      readingsUpdatedAt:
          (data['readingsUpdatedAt'] as Timestamp?)?.toDate(),
      allergies: List<String>.from(data['allergies'] ?? []),
      chronicConditions:
          List<String>.from(data['chronicConditions'] ?? []),
      disabilities: data['disabilities'] ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'],
    );
  }

  Map<String, dynamic> toMap() => {
        'caregiverId': caregiverId,
        'bloodGroup': bloodGroup.label,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'bloodPressureSystolic': bloodPressureSystolic,
        'bloodPressureDiastolic': bloodPressureDiastolic,
        'oxygenLevel': oxygenLevel,
        'heartRate': heartRate,
        'bloodSugarFasting': bloodSugarFasting,
        'bloodSugarPostMeal': bloodSugarPostMeal,
        'cholesterol': cholesterol,
        'temperatureF': temperatureF,
        'allergies': allergies,
        'chronicConditions': chronicConditions,
        'disabilities': disabilities,
      };
}