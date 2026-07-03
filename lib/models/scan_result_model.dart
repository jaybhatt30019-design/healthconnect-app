// lib/models/scan_result_model.dart

import 'package:Vitanex/models/medical_history_model.dart';

// ── Full scan result from Claude Vision ──────────────
class ScanResult {
  final String documentType;
  final String? documentDate;
  final String? hospitalName;
  final String? doctorName;
  final String? rawNotes;

  // Maps directly to HealthPassport fields
  final ScannedPassportData? passport;

  // Maps to Medicine model
  final List<ScannedMedicine> medicines;

  // Maps to Illness model
  final List<ScannedIllness> illnesses;

  // Maps to Surgery model
  final List<ScannedSurgery> surgeries;

  ScanResult({
    required this.documentType,
    this.documentDate,
    this.hospitalName,
    this.doctorName,
    this.rawNotes,
    this.passport,
    required this.medicines,
    required this.illnesses,
    required this.surgeries,
  });

  bool get hasPassportData =>
      passport != null && passport!.hasAnyData;

  bool get hasMedicines => medicines.isNotEmpty;
  bool get hasIllnesses => illnesses.isNotEmpty;
  bool get hasSurgeries => surgeries.isNotEmpty;
  bool get hasRawNotes =>
      rawNotes != null && rawNotes!.trim().isNotEmpty;

  bool get isEmpty =>
      !hasPassportData &&
      !hasMedicines &&
      !hasIllnesses &&
      !hasSurgeries &&
      !hasRawNotes;

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      documentType:
          json['documentType'] as String? ?? 'other',
      documentDate: json['documentDate'] as String?,
      hospitalName: json['hospitalName'] as String?,
      doctorName: json['doctorName'] as String?,
      rawNotes: json['rawNotes'] as String?,
      passport: json['passport'] != null
          ? ScannedPassportData.fromJson(
              json['passport'] as Map<String, dynamic>)
          : null,
      medicines: (json['medicines'] as List? ?? [])
          .map((e) => ScannedMedicine.fromJson(
              e as Map<String, dynamic>))
          .toList(),
      illnesses: (json['illnesses'] as List? ?? [])
          .map((e) => ScannedIllness.fromJson(
              e as Map<String, dynamic>))
          .toList(),
      surgeries: (json['surgeries'] as List? ?? [])
          .map((e) => ScannedSurgery.fromJson(
              e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Passport data extracted from document ─────────────
class ScannedPassportData {
  final String? bloodGroup;
  final double? heightCm;
  final double? weightKg;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? oxygenLevel;
  final int? heartRate;
  final int? bloodSugarFasting;
  final int? bloodSugarPostMeal;
  final int? cholesterol;
  final double? temperatureF;
  final List<String> allergies;
  final List<String> chronicConditions;
  final String? disabilities;

  ScannedPassportData({
    this.bloodGroup,
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
    required this.allergies,
    required this.chronicConditions,
    this.disabilities,
  });

  bool get hasAnyData =>
      bloodGroup != null ||
      heightCm != null ||
      weightKg != null ||
      bloodPressureSystolic != null ||
      oxygenLevel != null ||
      heartRate != null ||
      bloodSugarFasting != null ||
      bloodSugarPostMeal != null ||
      cholesterol != null ||
      temperatureF != null ||
      allergies.isNotEmpty ||
      chronicConditions.isNotEmpty ||
      disabilities != null;

  factory ScannedPassportData.fromJson(
      Map<String, dynamic> json) {
    return ScannedPassportData(
      bloodGroup: json['bloodGroup'] as String?,
      heightCm: _toDouble(json['heightCm']),
      weightKg: _toDouble(json['weightKg']),
      bloodPressureSystolic:
          _toInt(json['bloodPressureSystolic']),
      bloodPressureDiastolic:
          _toInt(json['bloodPressureDiastolic']),
      oxygenLevel: _toInt(json['oxygenLevel']),
      heartRate: _toInt(json['heartRate']),
      bloodSugarFasting:
          _toInt(json['bloodSugarFasting']),
      bloodSugarPostMeal:
          _toInt(json['bloodSugarPostMeal']),
      cholesterol: _toInt(json['cholesterol']),
      temperatureF: _toDouble(json['temperatureF']),
      allergies: _toStringList(json['allergies']),
      chronicConditions:
          _toStringList(json['chronicConditions']),
      disabilities: json['disabilities'] as String?,
    );
  }
}

// ── Medicine extracted from document ─────────────────
class ScannedMedicine {
  final String name;
  final String dosage;
  final String? disease;
  final String? intake;
  final String? duration;
  final String? doctor;
  final int? stockCount;
  final String? stockUnit;

  // User can toggle whether to save this
  bool willSave;

  ScannedMedicine({
    required this.name,
    required this.dosage,
    this.disease,
    this.intake,
    this.duration,
    this.doctor,
    this.stockCount,
    this.stockUnit,
    this.willSave = true,
  });

  factory ScannedMedicine.fromJson(
      Map<String, dynamic> json) {
    return ScannedMedicine(
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      disease: json['disease'] as String?,
      intake: json['intake'] as String?,
      duration: json['duration'] as String?,
      doctor: json['doctor'] as String?,
      stockCount: _toInt(json['stockCount']),
      stockUnit: json['stockUnit'] as String?,
    );
  }
}

// ── Illness extracted from document ──────────────────
class ScannedIllness {
  final String name;
  final String? diagnosedDate;
  final Severity severity;
  final String? doctor;
  final String? notes;
  final bool isOngoing;

  bool willSave;

  ScannedIllness({
    required this.name,
    this.diagnosedDate,
    required this.severity,
    this.doctor,
    this.notes,
    required this.isOngoing,
    this.willSave = true,
  });

  factory ScannedIllness.fromJson(
      Map<String, dynamic> json) {
    final sevStr =
        (json['severity'] as String? ?? 'mild')
            .toLowerCase();
    final sev = sevStr == 'severe'
        ? Severity.severe
        : sevStr == 'moderate'
            ? Severity.moderate
            : Severity.mild;

    return ScannedIllness(
      name: json['name'] as String? ?? '',
      diagnosedDate:
          json['diagnosedDate'] as String?,
      severity: sev,
      doctor: json['doctor'] as String?,
      notes: json['notes'] as String?,
      isOngoing:
          json['isOngoing'] as bool? ?? true,
    );
  }
}

// ── Surgery extracted from document ──────────────────
class ScannedSurgery {
  final String name;
  final String? date;
  final String? hospital;
  final String? surgeon;
  final String? notes;

  bool willSave;

  ScannedSurgery({
    required this.name,
    this.date,
    this.hospital,
    this.surgeon,
    this.notes,
    this.willSave = true,
  });

  factory ScannedSurgery.fromJson(
      Map<String, dynamic> json) {
    return ScannedSurgery(
      name: json['name'] as String? ?? '',
      date: json['date'] as String?,
      hospital: json['hospital'] as String?,
      surgeon: json['surgeon'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

// ── Safe type conversion helpers ─────────────────────
double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}

List<String> _toStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) {
    return v
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty) 
        .toList();
  }
  return [];
}