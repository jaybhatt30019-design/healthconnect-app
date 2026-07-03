// lib/core/services/pdf_service.dart
// Fixed: text not rendering — caused by special characters
// (—, °, %, etc.) not supported by default PDF font
// Fix: load Roboto font from assets and use throughout

import 'package:flutter/material.dart' show DayPeriod;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:Vitanex/core/services/report_service.dart';
import 'package:Vitanex/models/health_passport_model.dart';
import 'package:Vitanex/models/medical_history_model.dart';
import 'package:flutter/foundation.dart';

class PdfService {
  static const _teal = PdfColor.fromInt(0xFF0E7C6B);
  static const _darkTeal = PdfColor.fromInt(0xFF004D40);
  static const _lightTeal = PdfColor.fromInt(0xFFE0F2F1);
  static const _red = PdfColor.fromInt(0xFFEF4444);
  static const _amber = PdfColor.fromInt(0xFFF59E0B);
  static const _grey = PdfColor.fromInt(0xFF6B7280);
  static const _lightGrey = PdfColor.fromInt(0xFFF3F4F6);
  static const _border = PdfColor.fromInt(0xFFE5E7EB);

  // ── Loaded fonts — set once per generateAndShare call ──
  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _italic;

  // ── Load fonts from assets ────────────────────────
  // ✅ FIX: using Roboto which supports all Latin
  // extended characters including —, °, %, ©, etc.
  static Future<void> _loadFonts() async {
    try {
      final regularData = await rootBundle
          .load('assets/fonts/Roboto-Regular.ttf');
      final boldData = await rootBundle
          .load('assets/fonts/Roboto-Bold.ttf');
      final italicData = await rootBundle
          .load('assets/fonts/Roboto-Italic.ttf');

      _regular = pw.Font.ttf(regularData);
      _bold = pw.Font.ttf(boldData);
      _italic = pw.Font.ttf(italicData);
    } catch (e) {
      // Fallback to built-in if fonts fail to load
      // Built-in fonts handle basic Latin only
      debugPrint('[PdfService] Font load error: $e');
      _regular = null;
      _bold = null;
      _italic = null;
    }
  }

  // ── Text style helpers using loaded fonts ─────────
  static pw.TextStyle _style({
    double fontSize = 10,
    bool bold = false,
    bool italic = false,
    PdfColor? color,
    double lineSpacing = 1.5,
  }) {
    return pw.TextStyle(
      font: bold ? _bold : (italic ? _italic : _regular),
      fontBold: _bold,
      fontItalic: _italic,
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
      color: color,
      lineSpacing: lineSpacing,
    );
  }

  // ── Clean text — replace problematic characters ───
  // Replaces special chars that some PDF viewers
  // still can't handle even with embedded fonts
  static String _clean(String text) {
    return text
        .replaceAll('\u2014', '-') // em dash —
        .replaceAll('\u2013', '-') // en dash –
        .replaceAll('\u2019', "'") // right single quote
        .replaceAll('\u2018', "'") // left single quote
        .replaceAll('\u201C', '"') // left double quote
        .replaceAll('\u201D', '"') // right double quote
        .replaceAll('\u00B0', ' deg') // degree °
        .replaceAll('\u00A9', '(c)') // copyright ©
        .replaceAll('\u00AE', '(R)') // registered ®
        .trim();
  }

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
      case BloodGroup.unknown: return 'Unknown';
    }
  }

  // ── Main generate function ────────────────────────
  static Future<void> generateAndShare(
      MedicalReport report) async {

    // ✅ Load fonts before building PDF
    await _loadFonts();

    final pdf = pw.Document();

    // ✅ Set default theme with loaded fonts
    final theme = pw.ThemeData.withFont(
      base: _regular ?? pw.Font.helvetica(),
      bold: _bold ?? pw.Font.helveticaBold(),
      italic: _italic ?? pw.Font.helveticaOblique(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
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
            pw.SizedBox(height: 20),
          ],
          _disclaimerSection(report),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'Vitanex_Report_${_clean(report.profile.name).replaceAll(' ', '_')}.pdf',
    );
  }

  // ── Header ────────────────────────────────────────
  static pw.Widget _buildHeader(MedicalReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _teal, width: 2),
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
              pw.Text('Vitanex',
                  style: _style(
                      fontSize: 20,
                      bold: true,
                      color: _darkTeal)),
              pw.Text('Medical Report',
                  style: _style(
                      fontSize: 12, color: _grey)),
            ],
          ),
          pw.Text(
            'Generated: ${_fmt(report.generatedAt)}',
            style: _style(fontSize: 10, color: _grey),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _border, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'For reference only. Consult your doctor.',
            style: _style(fontSize: 8, color: _grey),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: _style(fontSize: 8, color: _grey),
          ),
        ],
      ),
    );
  }

  // ── Patient section ───────────────────────────────
  static pw.Widget _patientSection(
      MedicalReport report) {
    final p = report.profile;
    final pass = report.passport;
    final bloodLabel = pass != null
        ? _bloodGroupToLabel(pass.bloodGroup)
        : 'Unknown';

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
                child: _infoItem(
                    'Name', _clean(p.name))),
            pw.Expanded(
                child: _infoItem(
                    'Phone', _clean(p.phone))),
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
                        : 'N/A')),
            pw.Expanded(
                child: _infoItem(
                    'Weight',
                    pass?.weightKg != null
                        ? '${pass!.weightKg!.toStringAsFixed(1)} kg'
                        : 'N/A')),
            pw.Expanded(
                child: _infoItem(
                    'BMI',
                    pass?.bmi != null
                        ? '${pass!.bmi!.toStringAsFixed(1)} (${pass.bmiLabel})'
                        : 'N/A')),
          ]),
        ],
      ),
    );
  }

  // ── Health readings ───────────────────────────────
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
              // ✅ replace — with N/A for PDF
              p.bpDisplay.replaceAll('—', 'N/A'),
              _bpStatus(p.bloodPressureSystolic),
            ], isAlt: false),
            _tableRow([
              'Oxygen Level (SpO2)',
              p.oxygenLevel != null
                  ? '${p.oxygenLevel}%'
                  : 'N/A',
              _spo2Status(p.oxygenLevel),
            ], isAlt: true),
            _tableRow([
              'Heart Rate',
              p.heartRate != null
                  ? '${p.heartRate} bpm'
                  : 'N/A',
              _pulseStatus(p.heartRate),
            ], isAlt: false),
            _tableRow([
              'Blood Sugar (Fasting)',
              p.bloodSugarFasting != null
                  ? '${p.bloodSugarFasting} mg/dL'
                  : 'N/A',
              _sugarStatus(p.bloodSugarFasting),
            ], isAlt: true),
            _tableRow([
              'Cholesterol',
              p.cholesterol != null
                  ? '${p.cholesterol} mg/dL'
                  : 'N/A',
              _cholStatus(p.cholesterol),
            ], isAlt: false),
            _tableRow([
              'Temperature',
              p.temperatureF != null
                  ? '${p.temperatureF!.toStringAsFixed(1)} deg F'
                  : 'N/A',
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
              style: _style(
                  fontSize: 8, color: _grey),
            ),
          ),
      ],
    );
  }

  // ── Allergies section ─────────────────────────────
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
              style: _style(
                  fontSize: 10, bold: true)),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 6,
            runSpacing: 4,
            children: p.allergies
                .map((a) => _chip(
                    _clean(a), _red))
                .toList(),
          ),
          pw.SizedBox(height: 8),
        ],
        if (p.chronicConditions.isNotEmpty) ...[
          pw.Text('Chronic Conditions:',
              style: _style(
                  fontSize: 10, bold: true)),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 6,
            runSpacing: 4,
            children: p.chronicConditions
                .map((c) => _chip(
                    _clean(c), _amber))
                .toList(),
          ),
        ],
        if (p.disabilities.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Special Needs:',
              style: _style(
                  fontSize: 10, bold: true)),
          pw.SizedBox(height: 4),
          pw.Text(_clean(p.disabilities),
              style: _style(
                  fontSize: 10, color: _grey)),
        ],
      ],
    );
  }

  // ── Medicines section ─────────────────────────────
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
                _clean(med.name),
                _clean(med.dosage),
                timingStr,
                _clean(med.stockDisplay),
                stockStatus,
              ], isAlt: i.isOdd);
            }),
          ],
        ),
      ],
    );
  }

  // ── Appointments section ──────────────────────────
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
                _clean(appt.doctorName),
                _clean(appt.hospitalName),
                _clean(appt.reason),
                _fmt(appt.dateTime),
              ], isAlt: i.isOdd);
            }),
          ],
        ),
      ],
    );
  }

  // ── Illnesses section ─────────────────────────────
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
              return _tableRow([
                _clean(ill.name),
                ill.diagnosedDate ?? 'N/A',
                ill.isOngoing
                    ? 'Ongoing'
                    : (ill.recoveredDate ?? 'N/A'),
                _clean(ill.doctor ?? 'N/A'),
                _severityLabel(ill.severity),
              ], isAlt: i.isOdd);
            }),
          ],
        ),
      ],
    );
  }

  // ── Surgeries section ─────────────────────────────
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
                _clean(s.name),
                s.date ?? 'N/A',
                _clean(s.hospital ?? 'N/A'),
                _clean(s.surgeon ?? 'N/A'),
              ], isAlt: i.isOdd);
            }),
          ],
        ),
      ],
    );
  }

  // ── Disclaimer section ────────────────────────────
  static pw.Widget _disclaimerSection(
      MedicalReport report) {
    final generatedOn =
        '${report.generatedAt.day.toString().padLeft(2, '0')}/'
        '${report.generatedAt.month.toString().padLeft(2, '0')}/'
        '${report.generatedAt.year}  '
        '${report.generatedAt.hour.toString().padLeft(2, '0')}:'
        '${report.generatedAt.minute.toString().padLeft(2, '0')}';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFFBEB),
        borderRadius: const pw.BorderRadius.all(
            pw.Radius.circular(6)),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFF59E0B),
          width: 0.8,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'DISCLAIMER',
                style: _style(
                  fontSize: 10,
                  bold: true,
                  color: const PdfColor.fromInt(
                      0xFF92400E),
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Report generated: $generatedOn',
                style: _style(
                  fontSize: 8,
                  color: const PdfColor.fromInt(
                      0xFF92400E),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'All health data in this report including blood pressure, '
            'oxygen level, heart rate, blood sugar, cholesterol, '
            'temperature, medicines, appointments and medical history '
            'has been manually entered by the user. '
            'This information has NOT been measured, collected, verified '
            'or monitored by Vitanex or any of its services. '
            'Vitanex bears no responsibility for the accuracy, '
            'completeness or correctness of any data in this report. '
            'This document is for personal reference only and does not '
            'constitute medical advice. '
            'Always consult a qualified and licensed medical professional '
            'for diagnosis, treatment and health decisions.',
            style: _style(
              fontSize: 8,
              color: const PdfColor.fromInt(0xFF78350F),
              lineSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Last data edit recorded: $generatedOn  |  '
            'Patient: ${_clean(report.profile.name)}',
            style: _style(
              fontSize: 7,
              italic: true,
              color: _grey,
            ),
          ),
        ],
      ),
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
      child: pw.Text(
        title,
        style: _style(
          fontSize: 12,
          bold: true,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _infoItem(
      String label, String value) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: _style(
                fontSize: 8, color: _grey)),
        pw.Text(value,
            style: _style(
                fontSize: 11,
                bold: true,
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
                child: pw.Text(
                  c,
                  style: _style(
                    fontSize: 9,
                    bold: true,
                    color: PdfColors.white,
                  ),
                ),
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
                child: pw.Text(
                  _clean(c),
                  style: _style(fontSize: 9),
                ),
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
      child: pw.Text(
        label,
        style: _style(
          fontSize: 9,
          bold: true,
          color: color,
        ),
      ),
    );
  }

  // ── Status helpers ────────────────────────────────
  static String _bpStatus(int? s) {
    if (s == null) return 'N/A';
    if (s <= 120) return 'Normal';
    if (s <= 139) return 'Elevated';
    return 'High';
  }

  static String _spo2Status(int? v) {
    if (v == null) return 'N/A';
    if (v >= 95) return 'Normal';
    if (v >= 90) return 'Low';
    return 'Critical';
  }

  static String _pulseStatus(int? v) {
    if (v == null) return 'N/A';
    if (v >= 60 && v <= 100) return 'Normal';
    if (v >= 50 && v <= 110) return 'Borderline';
    return 'Abnormal';
  }

  static String _sugarStatus(int? v) {
    if (v == null) return 'N/A';
    if (v <= 100) return 'Normal';
    if (v <= 125) return 'Pre-diabetic';
    return 'High';
  }

  static String _cholStatus(int? v) {
    if (v == null) return 'N/A';
    if (v < 200) return 'Normal';
    if (v < 240) return 'Borderline';
    return 'High';
  }

  static String _tempStatus(double? v) {
    if (v == null) return 'N/A';
    if (v >= 97 && v <= 99) return 'Normal';
    if (v > 99 && v <= 100.4) return 'Low fever';
    return 'Fever';
  }

  static String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}