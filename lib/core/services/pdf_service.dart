// lib/core/services/pdf_service.dart

import 'package:flutter/material.dart' show DayPeriod, TimeOfDay;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:healthconnect/core/services/report_service.dart';
import 'package:healthconnect/models/health_passport_model.dart';
import 'package:healthconnect/models/medical_history_model.dart';
import 'package:healthconnect/models/medicine_model.dart';

class PdfService {
  static const _teal = PdfColor.fromInt(0xFF0E7C6B);
  static const _darkTeal = PdfColor.fromInt(0xFF004D40);
  static const _lightTeal = PdfColor.fromInt(0xFFE0F2F1);
  static const _red = PdfColor.fromInt(0xFFEF4444);
  static const _amber = PdfColor.fromInt(0xFFF59E0B);
  static const _grey = PdfColor.fromInt(0xFF6B7280);
  static const _lightGrey = PdfColor.fromInt(0xFFF3F4F6);
  static const _border = PdfColor.fromInt(0xFFE5E7EB);

  // ✅ FIXED: no enum .name — manual switch for web safety
  static String _severityLabel(Severity s) {
    switch (s) {
      case Severity.mild: return 'Mild';
      case Severity.moderate: return 'Moderate';
      case Severity.severe: return 'Severe';
    }
  }

  static String _bloodGroupToLabel(BloodGroup group) {
    switch (group) {
      case BloodGroup.aPos: return 'A+';
      case BloodGroup.aNeg: return 'A-';
      case BloodGroup.bPos: return 'B+';
      case BloodGroup.bNeg: return 'B-';
      case BloodGroup.oPos: return 'O+';
      case BloodGroup.oNeg: return 'O-';
      case BloodGroup.abPos: return 'AB+';
      case BloodGroup.abNeg: return 'AB-';
      case BloodGroup.unknown: return '—';
    }
  }

  static Future<void> generateAndShare(
      MedicalReport report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(report),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _patientSection(report),
          pw.SizedBox(height: 20),
          if (report.passport != null) ...[
            _healthReadingsSection(report),
            pw.SizedBox(height: 20),
          ],
          if (report.passport != null &&
              (report.passport!.allergies.isNotEmpty ||
                  report.passport!.chronicConditions
                      .isNotEmpty)) ...[
            _allergiesSection(report),
            pw.SizedBox(height: 20),
          ],
          if (report.medicines.isNotEmpty) ...[
            _medicinesSection(report),
            pw.SizedBox(height: 20),
          ],
          if (report.appointments.isNotEmpty) ...[
            _appointmentsSection(report),
            pw.SizedBox(height: 20),
          ],
          if ((report.history?.illnesses ?? [])
              .isNotEmpty) ...[
            _illnessesSection(report),
            pw.SizedBox(height: 20),
          ],
          if ((report.history?.surgeries ?? [])
              .isNotEmpty) ...[
            _surgeriesSection(report),
          ],
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'HealthConnect_Report_${report.profile.name.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _buildHeader(MedicalReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom:
              pw.BorderSide(color: _teal, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Text('HealthConnect',
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkTeal)),
              pw.Text('Medical Report',
                  style: pw.TextStyle(
                      fontSize: 12, color: _grey)),
            ],
          ),
          pw.Text(
            'Generated: ${_fmt(report.generatedAt)}',
            style: pw.TextStyle(
                fontSize: 10, color: _grey),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
              color: _border, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'For reference only. Consult your doctor.',
            style: pw.TextStyle(
                fontSize: 8, color: _grey),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
                fontSize: 8, color: _grey),
          ),
        ],
      ),
    );
  }

  static pw.Widget _patientSection(
      MedicalReport report) {
    final p = report.profile;
    final pass = report.passport;
    final bloodLabel = pass != null
        ? _bloodGroupToLabel(pass.bloodGroup)
        : '—';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _lightTeal,
        borderRadius: const pw.BorderRadius.all(
            pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Patient Information'),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            pw.Expanded(
                child: _infoItem('Name', p.name)),
            pw.Expanded(
                child: _infoItem('Phone', p.phone)),
            pw.Expanded(
                child: _infoItem(
                    'Blood Group', bloodLabel)),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Expanded(
                child: _infoItem(
                    'Height',
                    pass?.heightCm != null
                        ? '${pass!.heightCm!.toStringAsFixed(0)} cm'
                        : '—')),
            pw.Expanded(
                child: _infoItem(
                    'Weight',
                    pass?.weightKg != null
                        ? '${pass!.weightKg!.toStringAsFixed(1)} kg'
                        : '—')),
            pw.Expanded(
                child: _infoItem(
                    'BMI',
                    pass?.bmi != null
                        ? '${pass!.bmi!.toStringAsFixed(1)} (${pass.bmiLabel})'
                        : '—')),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _healthReadingsSection(
      MedicalReport report) {
    final p = report.passport!;
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Current Health Readings'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: _border, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
          },
          children: [
            _tableHeader(
                ['Parameter', 'Value', 'Status']),
            _tableRow([
              'Blood Pressure',
              p.bpDisplay,
              _bpStatus(p.bloodPressureSystolic),
            ], isAlt: false),
            _tableRow([
              'Oxygen Level (SpO2)',
              p.oxygenLevel != null
                  ? '${p.oxygenLevel}%'
                  : '—',
              _spo2Status(p.oxygenLevel),
            ], isAlt: true),
            _tableRow([
              'Heart Rate',
              p.heartRate != null
                  ? '${p.heartRate} bpm'
                  : '—',
              _pulseStatus(p.heartRate),
            ], isAlt: false),
            _tableRow([
              'Blood Sugar (Fasting)',
              p.bloodSugarFasting != null
                  ? '${p.bloodSugarFasting} mg/dL'
                  : '—',
              _sugarStatus(p.bloodSugarFasting),
            ], isAlt: true),
            _tableRow([
              'Cholesterol',
              p.cholesterol != null
                  ? '${p.cholesterol} mg/dL'
                  : '—',
              _cholStatus(p.cholesterol),
            ], isAlt: false),
            _tableRow([
              'Temperature',
              p.temperatureF != null
                  ? '${p.temperatureF!.toStringAsFixed(1)} °F'
                  : '—',
              _tempStatus(p.temperatureF),
            ], isAlt: true),
          ],
        ),
        if (p.readingsUpdatedAt != null)
          pw.Padding(
            padding:
                const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              'Last updated: ${_fmt(p.readingsUpdatedAt!)}',
              style: pw.TextStyle(
                  fontSize: 8, color: _grey),
            ),
          ),
      ],
    );
  }

  static pw.Widget _allergiesSection(
      MedicalReport report) {
    final p = report.passport!;
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(
            'Allergies & Chronic Conditions'),
        pw.SizedBox(height: 8),
        if (p.allergies.isNotEmpty) ...[
          pw.Text('Allergies:',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 6,
            runSpacing: 4,
            children: p.allergies
                .map((a) => _chip(a, _red))
                .toList(),
          ),
          pw.SizedBox(height: 8),
        ],
        if (p.chronicConditions.isNotEmpty) ...[
          pw.Text('Chronic Conditions:',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 6,
            runSpacing: 4,
            children: p.chronicConditions
                .map((c) => _chip(c, _amber))
                .toList(),
          ),
        ],
        if (p.disabilities.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Special Needs:',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(p.disabilities,
              style: pw.TextStyle(
                  fontSize: 10, color: _grey)),
        ],
      ],
    );
  }

  static pw.Widget _medicinesSection(
      MedicalReport report) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Current Medications'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: _border, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            _tableHeader([
              'Medicine',
              'Dosage',
              'Timing',
              'Stock',
              'Status',
            ]),
            ...report.medicines
                .asMap()
                .entries
                .map((entry) {
              final i = entry.key;
              final med = entry.value;
              final timingStr = med.times
                  .map((t) =>
                      '${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}')
                  .join(', ');
              final stockStatus = med.isOutOfStock
                  ? 'Out'
                  : med.isLowStock
                      ? 'Low'
                      : 'OK';
              return _tableRow([
                med.name,
                med.dosage,
                timingStr,
                med.stockDisplay,
                stockStatus,
              ], isAlt: i.isOdd);
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _appointmentsSection(
      MedicalReport report) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Doctor Appointments'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: _border, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            _tableHeader([
              'Doctor',
              'Hospital',
              'Reason',
              'Date',
            ]),
            ...report.appointments
                .asMap()
                .entries
                .map((entry) {
              final i = entry.key;
              final appt = entry.value;
              return _tableRow([
                appt.doctorName,
                appt.hospitalName,
                appt.reason,
                _fmt(appt.dateTime),
              ], isAlt: i.isOdd);
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _illnessesSection(
      MedicalReport report) {
    final illnesses = report.history!.illnesses;
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Past Illnesses'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: _border, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            _tableHeader([
              'Condition',
              'Diagnosed',
              'Recovered',
              'Doctor',
              'Severity',
            ]),
            ...illnesses
                .asMap()
                .entries
                .map((entry) {
              final i = entry.key;
              final ill = entry.value;
              // ✅ FIXED: _severityLabel instead of .name
              return _tableRow([
                ill.name,
                ill.diagnosedDate ?? '—',
                ill.isOngoing
                    ? 'Ongoing'
                    : (ill.recoveredDate ?? '—'),
                ill.doctor ?? '—',
                _severityLabel(ill.severity),
              ], isAlt: i.isOdd);
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _surgeriesSection(
      MedicalReport report) {
    final surgeries = report.history!.surgeries;
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Past Surgeries'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: _border, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            _tableHeader([
              'Surgery',
              'Date',
              'Hospital',
              'Surgeon',
            ]),
            ...surgeries
                .asMap()
                .entries
                .map((entry) {
              final i = entry.key;
              final s = entry.value;
              return _tableRow([
                s.name,
                s.date ?? '—',
                s.hospital ?? '—',
                s.surgeon ?? '—',
              ], isAlt: i.isOdd);
            }),
          ],
        ),
      ],
    );
  }

  // ── Reusable widgets ──────────────────────────────

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          vertical: 6, horizontal: 10),
      decoration: const pw.BoxDecoration(
        color: _darkTeal,
        borderRadius: pw.BorderRadius.all(
            pw.Radius.circular(4)),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    );
  }

  static pw.Widget _infoItem(
      String label, String value) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 8, color: _grey)),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _darkTeal)),
      ],
    );
  }

  static pw.TableRow _tableHeader(
      List<String> cells) {
    return pw.TableRow(
      decoration:
          const pw.BoxDecoration(color: _darkTeal),
      children: cells
          .map((c) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(c,
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight:
                            pw.FontWeight.bold,
                        color: PdfColors.white)),
              ))
          .toList(),
    );
  }

  static pw.TableRow _tableRow(List<String> cells,
      {required bool isAlt}) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
          color: isAlt
              ? _lightGrey
              : PdfColors.white),
      children: cells
          .map((c) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(c,
                    style: const pw.TextStyle(
                        fontSize: 9)),
              ))
          .toList(),
    );
  }

  static pw.Widget _chip(
      String label, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: color.shade(0.15),
        borderRadius: const pw.BorderRadius.all(
            pw.Radius.circular(12)),
        border:
            pw.Border.all(color: color, width: 0.5),
      ),
      child: pw.Text(label,
          style: pw.TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: pw.FontWeight.bold)),
    );
  }

  // ── Status helpers ────────────────────────────────
  static String _bpStatus(int? s) {
    if (s == null) return '—';
    if (s <= 120) return 'Normal';
    if (s <= 139) return 'Elevated';
    return 'High';
  }

  static String _spo2Status(int? v) {
    if (v == null) return '—';
    if (v >= 95) return 'Normal';
    if (v >= 90) return 'Low';
    return 'Critical';
  }

  static String _pulseStatus(int? v) {
    if (v == null) return '—';
    if (v >= 60 && v <= 100) return 'Normal';
    if (v >= 50 && v <= 110) return 'Borderline';
    return 'Abnormal';
  }

  static String _sugarStatus(int? v) {
    if (v == null) return '—';
    if (v <= 100) return 'Normal';
    if (v <= 125) return 'Pre-diabetic';
    return 'High';
  }

  static String _cholStatus(int? v) {
    if (v == null) return '—';
    if (v < 200) return 'Normal';
    if (v < 240) return 'Borderline';
    return 'High';
  }

  static String _tempStatus(double? v) {
    if (v == null) return '—';
    if (v >= 97 && v <= 99) return 'Normal';
    if (v > 99 && v <= 100.4) return 'Low fever';
    return 'Fever';
  }

  static String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}