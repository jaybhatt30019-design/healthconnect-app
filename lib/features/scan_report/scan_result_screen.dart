// lib/features/scan_report/scan_result_screen.dart

import 'package:flutter/material.dart';
import 'package:Vitanex/theme/app_design_system.dart';
import 'package:Vitanex/models/scan_result_model.dart';
import 'package:Vitanex/models/medicine_model.dart';
import 'package:Vitanex/models/medical_history_model.dart';
import 'package:Vitanex/models/health_passport_model.dart';
import 'package:Vitanex/core/services/medicine_service.dart';
import 'package:Vitanex/core/services/medical_history_service.dart';
import 'package:Vitanex/core/services/health_passport_service.dart';
import 'package:Vitanex/core/services/fcm_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScanResultScreen extends StatefulWidget {
  final ScanResult result;
  const ScanResultScreen({super.key, required this.result});

  @override
  State<ScanResultScreen> createState() =>
      _ScanResultScreenState();
}

class _ScanResultScreenState
    extends State<ScanResultScreen> {
  bool _isSaving = false;
  bool _savePassport = true;
  static const double _saveBarHeight = 95;

  late ScanResult _result;

  late final List<TextEditingController> _medNameCtrls;
  late final List<TextEditingController> _medDosageCtrls;
  late final List<TextEditingController> _medStockCtrls;
  late final List<String> _medIntakes;
  late final List<String> _medUnits;
  late final List<TextEditingController> _illNameCtrls;
  late final List<TextEditingController> _surgNameCtrls;
  late final List<TextEditingController> _surgHospitalCtrls;
  late final TextEditingController _rawNotesCtrl;

  static const _intakeOptions = ['Before Food', 'After Food'];
  static const _unitOptions = [
    'tablets', 'capsules', 'ml', 'drops',
    'sachets', 'puffs', 'patches', 'units',
  ];

  @override
  void initState() {
    super.initState();
    _result = widget.result;

    _medNameCtrls = _result.medicines
        .map((m) => TextEditingController(text: m.name))
        .toList();
    _medDosageCtrls = _result.medicines
        .map((m) => TextEditingController(text: m.dosage))
        .toList();
    _medStockCtrls = _result.medicines
        .map((m) => TextEditingController(
            text: m.stockCount?.toString() ?? ''))
        .toList();
    _medIntakes = _result.medicines
        .map((m) => _normalizeIntake(m.intake))
        .toList();
    _medUnits = _result.medicines
        .map((m) => _normalizeUnit(m.stockUnit))
        .toList();
    _illNameCtrls = _result.illnesses
        .map((i) => TextEditingController(text: i.name))
        .toList();
    _surgNameCtrls = _result.surgeries
        .map((s) => TextEditingController(text: s.name))
        .toList();
    _surgHospitalCtrls = _result.surgeries
        .map((s) =>
            TextEditingController(text: s.hospital ?? ''))
        .toList();
    _rawNotesCtrl = TextEditingController(
        text: _result.rawNotes ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      ..._medNameCtrls,
      ..._medDosageCtrls,
      ..._medStockCtrls,
      ..._illNameCtrls,
      ..._surgNameCtrls,
      ..._surgHospitalCtrls,
      _rawNotesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _normalizeIntake(String? intake) {
    if (intake == null) return 'Before Food';
    final lower = intake.toLowerCase();
    if (lower.contains('after') ||
        lower.contains('pc') ||
        lower.contains('post')) {
      return 'After Food';
    }
    return 'Before Food';
  }

  String _normalizeUnit(String? unit) {
    if (unit == null) return 'tablets';
    if (_unitOptions.contains(unit)) return unit;
    return 'tablets';
  }

  // ─────────────────────────────────────────────────
  // SAVE ALL
  // ✅ FIXED: single FcmService call inside try block
  // userName declared inside try so it's in scope
  // Removed the three duplicate blocks and the stray
  // call after finally that caused the scope error
  // ─────────────────────────────────────────────────
  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    int savedCount = 0;

    try {
      // 1. Save passport
      if (_result.hasPassportData && _savePassport) {
        await _savePassportData();
        savedCount++;
      }

      // 2. Save medicines
      for (int i = 0;
          i < _result.medicines.length;
          i++) {
        final med = _result.medicines[i];
        if (!med.willSave) continue;
        final name = _medNameCtrls[i].text.trim();
        if (name.isEmpty) continue;

        final stock =
            int.tryParse(_medStockCtrls[i].text.trim()) ??
                0;

        await MedicineService().addMedicine(Medicine(
          id: '',
          name: name,
          dosage: _medDosageCtrls[i].text.trim(),
          disease: med.disease,
          intake: _medIntakes[i],
          duration: med.duration ?? 'Ongoing',
          doctor: med.doctor ?? _result.doctorName,
          notes: null,
          startDate: DateTime.now(),
          times: [const TimeOfDay(hour: 8, minute: 0)],
          stockCount: stock,
          lowStockThreshold: 5,
          stockUnit: _medUnits[i],
          isCourseCompleted:false,
        ));
        savedCount++;
      }

      // 3. Save illnesses
      for (int i = 0;
          i < _result.illnesses.length;
          i++) {
        final ill = _result.illnesses[i];
        if (!ill.willSave) continue;
        final name = _illNameCtrls[i].text.trim();
        if (name.isEmpty) continue;

        await MedicalHistoryService().addIllness(Illness(
          id: '',
          name: name,
          diagnosedDate: ill.diagnosedDate,
          recoveredDate: null,
          severity: ill.severity,
          doctor: ill.doctor ?? _result.doctorName,
          notes: ill.notes,
        ));
        savedCount++;
      }

      // 4. Save surgeries
      for (int i = 0;
          i < _result.surgeries.length;
          i++) {
        final surg = _result.surgeries[i];
        if (!surg.willSave) continue;
        final name = _surgNameCtrls[i].text.trim();
        if (name.isEmpty) continue;

        final hospital =
            _surgHospitalCtrls[i].text.trim().isEmpty
                ? _result.hospitalName
                : _surgHospitalCtrls[i].text.trim();

        await MedicalHistoryService().addSurgery(Surgery(
          id: '',
          name: name,
          date: surg.date,
          hospital: hospital,
          surgeon: surg.surgeon,
          notes: surg.notes,
        ));
        savedCount++;
      }

      // 5. ✅ FIXED: userName declared HERE inside try
      // so it is in scope when passed to FcmService
      // Only ONE call — duplicates removed
      try {
        final uid =
            FirebaseAuth.instance.currentUser?.uid ?? '';
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final userName =
            userDoc.data()?['name'] as String? ?? 'User';
        await FcmService().notifyScanSaved(
          savedByName: userName,
          itemCount: savedCount,
        );
      } catch (_) {
        // FCM failure should not block save success
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$savedCount item${savedCount == 1 ? '' : 's'} saved'),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _savePassportData() async {
    final service = HealthPassportService();
    final existing = await service.loadPassport();
    final p = _result.passport!;

    final merged = HealthPassport(
      caregiverId: existing?.caregiverId ?? '',
      bloodGroup: p.bloodGroup != null
          ? BloodGroupLabel.fromString(p.bloodGroup!)
          : existing?.bloodGroup ?? BloodGroup.unknown,
      heightCm: p.heightCm ?? existing?.heightCm,
      weightKg: p.weightKg ?? existing?.weightKg,
      bloodPressureSystolic: p.bloodPressureSystolic ??
          existing?.bloodPressureSystolic,
      bloodPressureDiastolic: p.bloodPressureDiastolic ??
          existing?.bloodPressureDiastolic,
      oxygenLevel:
          p.oxygenLevel ?? existing?.oxygenLevel,
      heartRate: p.heartRate ?? existing?.heartRate,
      bloodSugarFasting: p.bloodSugarFasting ??
          existing?.bloodSugarFasting,
      bloodSugarPostMeal: p.bloodSugarPostMeal ??
          existing?.bloodSugarPostMeal,
      cholesterol:
          p.cholesterol ?? existing?.cholesterol,
      temperatureF:
          p.temperatureF ?? existing?.temperatureF,
      allergies: _mergeList(
          existing?.allergies ?? [], p.allergies),
      chronicConditions: _mergeList(
          existing?.chronicConditions ?? [],
          p.chronicConditions),
      disabilities:
          p.disabilities?.isNotEmpty == true
              ? p.disabilities!
              : existing?.disabilities ?? '',
    );

    await service.savePassport(merged);
  }

  List<String> _mergeList(
      List<String> existing, List<String> incoming) {
    final result = List<String>.from(existing);
    for (final item in incoming) {
      if (!result.any((e) =>
          e.toLowerCase() == item.toLowerCase())) {
        result.add(item);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    AppBackButton(
                        onTap: () =>
                            Navigator.pop(context)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text("Scan Results",
                          style: AppTextStyles.heading),
                    ),
                  ],
                ),
              ),

              if (_result.hospitalName != null ||
                  _result.documentDate != null ||
                  _result.doctorName != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: _docInfoBar(),
                ),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    top: AppSpacing.sm,
                    bottom: _saveBarHeight + 16,
                  ),
                  children: [
                    _infoBox(),
                    const SizedBox(
                        height: AppSpacing.md),
                    if (_result.hasPassportData)
                      _passportSection(),
                    if (_result.hasMedicines)
                      _medicinesSection(),
                    if (_result.hasIllnesses)
                      _illnessesSection(),
                    if (_result.hasSurgeries)
                      _surgeriesSection(),
                    _rawNotesSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _saveBar(),
    );
  }

  Widget _docInfoBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.iconBg,
        borderRadius:
            BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                _result.documentType
                    .replaceAll('_', ' ')
                    .toUpperCase(),
                if (_result.hospitalName != null)
                  _result.hospitalName!,
                if (_result.doctorName != null)
                  _result.doctorName!,
                if (_result.documentDate != null)
                  _result.documentDate!,
              ].join(' · '),
              style: AppTextStyles.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius:
            BorderRadius.circular(AppRadius.sm),
        border:
            Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note,
              color: Colors.amber.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Review and edit extracted data. "
              "Toggle off items you don't want to save. "
              "Tap Save when ready.",
              style: AppTextStyles.small
                  .copyWith(color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passportSection() {
    final p = _result.passport!;
    final items = <String>[];

    if (p.bloodGroup != null) {
      items.add('Blood Group: ${p.bloodGroup}');
    }
    if (p.heightCm != null) {
      items.add('Height: ${p.heightCm} cm');
    }
    if (p.weightKg != null) {
      items.add('Weight: ${p.weightKg} kg');
    }
    if (p.bloodPressureSystolic != null) {
      items.add(
          'BP: ${p.bloodPressureSystolic}/${p.bloodPressureDiastolic} mmHg');
    }
    if (p.oxygenLevel != null) {
      items.add('SpO2: ${p.oxygenLevel}%');
    }
    if (p.heartRate != null) {
      items.add('Heart Rate: ${p.heartRate} bpm');
    }
    if (p.bloodSugarFasting != null) {
      items.add(
          'Sugar Fasting: ${p.bloodSugarFasting} mg/dL');
    }
    if (p.bloodSugarPostMeal != null) {
      items.add(
          'Sugar Post Meal: ${p.bloodSugarPostMeal} mg/dL');
    }
    if (p.cholesterol != null) {
      items.add('Cholesterol: ${p.cholesterol} mg/dL');
    }
    if (p.temperatureF != null) {
      items.add('Temperature: ${p.temperatureF} °F');
    }
    if (p.allergies.isNotEmpty) {
      items.add('Allergies: ${p.allergies.join(', ')}');
    }
    if (p.chronicConditions.isNotEmpty) {
      items.add(
          'Conditions: ${p.chronicConditions.join(', ')}');
    }

    return _section(
      icon: Icons.monitor_heart_outlined,
      title: 'Health Passport Readings',
      color: AppColors.primary,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Save",
              style: AppTextStyles.small
                  .copyWith(color: AppColors.primary)),
          Switch(
            value: _savePassport,
            onChanged: (v) =>
                setState(() => _savePassport = v),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
      child: Column(
        children: items
            .map((item) => _dataRow(item))
            .toList(),
      ),
    );
  }

  Widget _medicinesSection() {
    return _section(
      icon: Icons.medication_outlined,
      title: 'Medicines Found',
      color: Colors.teal,
      child: Column(
        children: List.generate(
          _result.medicines.length,
          (i) => _editableMedicineCard(
              i, _result.medicines[i]),
        ),
      ),
    );
  }

  Widget _editableMedicineCard(
      int i, ScannedMedicine med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: med.willSave
            ? Colors.teal.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: med.willSave
              ? Colors.teal.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("Medicine ${i + 1}",
                    style: AppTextStyles.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.teal)),
              ),
              const Text("Save"),
              Switch(
                value: med.willSave,
                onChanged: (v) =>
                    setState(() => med.willSave = v),
                activeThumbColor: Colors.teal,
              ),
            ],
          ),
          if (med.willSave) ...[
            const SizedBox(height: 8),
            _editLabel("Medicine Name"),
            _editField(_medNameCtrls[i], "e.g. Aspirin"),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _editLabel("Dosage"),
                    _editField(
                        _medDosageCtrls[i], "e.g. 500mg"),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _editLabel("Intake"),
                    _dropdown(
                      value: _medIntakes[i],
                      items: _intakeOptions,
                      onChanged: (v) => setState(
                          () => _medIntakes[i] = v!),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _editLabel("Stock Count"),
                    _editField(
                      _medStockCtrls[i],
                      "e.g. 30",
                      keyboardType:
                          TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _editLabel("Unit"),
                    _dropdown(
                      value: _medUnits[i],
                      items: _unitOptions,
                      onChanged: (v) => setState(
                          () => _medUnits[i] = v!),
                    ),
                  ],
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _illnessesSection() {
    return _section(
      icon: Icons.sick_outlined,
      title: 'Diagnoses Found',
      color: Colors.orange,
      child: Column(
        children: List.generate(
          _result.illnesses.length,
          (i) {
            final ill = _result.illnesses[i];
            final sevLabel =
                ill.severity == Severity.severe
                    ? 'Severe'
                    : ill.severity == Severity.moderate
                        ? 'Moderate'
                        : 'Mild';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ill.willSave
                    ? Colors.orange
                        .withValues(alpha: 0.05)
                    : Colors.grey.shade50,
                borderRadius:
                    BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: ill.willSave
                      ? Colors.orange
                          .withValues(alpha: 0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                          '$sevLabel · ${ill.isOngoing ? 'Ongoing' : 'Past'}',
                          style: AppTextStyles.small
                              .copyWith(
                                  color: Colors.orange)),
                    ),
                    const Text("Save"),
                    Switch(
                      value: ill.willSave,
                      onChanged: (v) =>
                          setState(() => ill.willSave = v),
                      activeThumbColor: Colors.orange,
                    ),
                  ]),
                  if (ill.willSave) ...[
                    const SizedBox(height: 8),
                    _editLabel("Condition Name"),
                    _editField(_illNameCtrls[i],
                        "e.g. Hypertension"),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _surgeriesSection() {
    return _section(
      icon: Icons.medical_services_outlined,
      title: 'Surgeries Found',
      color: Colors.purple,
      child: Column(
        children: List.generate(
          _result.surgeries.length,
          (i) {
            final surg = _result.surgeries[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surg.willSave
                    ? Colors.purple
                        .withValues(alpha: 0.05)
                    : Colors.grey.shade50,
                borderRadius:
                    BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: surg.willSave
                      ? Colors.purple
                          .withValues(alpha: 0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('Surgery ${i + 1}',
                          style: AppTextStyles.small
                              .copyWith(
                                  color: Colors.purple,
                                  fontWeight:
                                      FontWeight.w700)),
                    ),
                    const Text("Save"),
                    Switch(
                      value: surg.willSave,
                      onChanged: (v) => setState(
                          () => surg.willSave = v),
                      activeThumbColor: Colors.purple,
                    ),
                  ]),
                  if (surg.willSave) ...[
                    const SizedBox(height: 8),
                    _editLabel("Surgery Name"),
                    _editField(_surgNameCtrls[i],
                        "e.g. Knee Replacement"),
                    const SizedBox(height: 10),
                    _editLabel("Hospital"),
                    _editField(_surgHospitalCtrls[i],
                        "e.g. City Hospital"),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _rawNotesSection() {
    return _section(
      icon: Icons.notes_outlined,
      title: 'Additional Findings',
      color: Colors.grey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Edit or add any additional notes. "
            "These are saved for your reference.",
            style: AppTextStyles.small
                .copyWith(fontSize: 11),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rawNotesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Additional findings...",
              hintStyle: AppTextStyles.small,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(
                    color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(
                    color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.light],
        border: Border.all(
            color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _dataRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check,
              size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.small)),
        ],
      ),
    );
  }

  Widget _editLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: AppTextStyles.small
              .copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _editField(
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: AppTextStyles.small
            .copyWith(color: AppColors.darkPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.small
              .copyWith(fontSize: 12),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(AppRadius.sm),
            borderSide:
                const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(AppRadius.sm),
            borderSide:
                const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(
                color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      height: 44,
      padding:
          const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: AppTextStyles.small
              .copyWith(color: AppColors.darkPrimary),
          items: items
              .map((e) => DropdownMenuItem(
                  value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _saveBar() {
    final totalSelected =
        (_result.hasPassportData && _savePassport
                ? 1
                : 0) +
            _result.medicines
                .where((m) => m.willSave)
                .length +
            _result.illnesses
                .where((i) => i.willSave)
                .length +
            _result.surgeries
                .where((s) => s.willSave)
                .length;

    return SafeArea(
      child: Container(
        height: _saveBarHeight,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          boxShadow: [AppShadows.medium],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving || totalSelected == 0
                ? null
                : _saveAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor:
                  Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2),
                  )
                : Text(
                    totalSelected == 0
                        ? 'Nothing Selected'
                        : 'Save $totalSelected '
                            'Item${totalSelected == 1 ? '' : 's'}',
                    style: AppTextStyles.body
                        .copyWith(color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}