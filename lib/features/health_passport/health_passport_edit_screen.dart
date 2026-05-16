// lib/features/health_passport/health_passport_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/health_passport_model.dart';
import 'package:healthconnect/core/services/health_passport_service.dart';

class HealthPassportEditScreen extends StatefulWidget {
  final HealthPassport? existing;

  const HealthPassportEditScreen({super.key, this.existing});

  @override
  State<HealthPassportEditScreen> createState() =>
      _HealthPassportEditScreenState();
}

class _HealthPassportEditScreenState
    extends State<HealthPassportEditScreen> {
  final _service = HealthPassportService();

  // Basic vitals
  BloodGroup _bloodGroup = BloodGroup.unknown;
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  // Readings
  final _bpSysCtrl = TextEditingController();
  final _bpDiaCtrl = TextEditingController();
  final _oxygenCtrl = TextEditingController();
  final _heartRateCtrl = TextEditingController();
  final _sugarFastCtrl = TextEditingController();
  final _sugarPostCtrl = TextEditingController();
  final _cholCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();

  // Lists
  List<String> _allergies = [];
  List<String> _conditions = [];
  final _allergyInputCtrl = TextEditingController();
  final _conditionInputCtrl = TextEditingController();

  // Other
  final _disabilitiesCtrl = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingExisting = false;

  // ✅ Holds the latest loaded passport so we can merge on save
  HealthPassport? _loadedPassport;

  @override
  void initState() {
    super.initState();

    if (widget.existing != null) {
      // Came from passport screen with existing data passed in
      _populateFrom(widget.existing!);
      _loadedPassport = widget.existing;
    } else {
      // Opened directly (e.g. empty state button) — load from Firestore
      _loadExisting();
    }
  }

  // ── Populate all controllers from a HealthPassport ──
  void _populateFrom(HealthPassport p) {
    _bloodGroup = p.bloodGroup;

    // Only set if not null/zero — preserves hint text for empty fields
    if (p.heightCm != null) {
      _heightCtrl.text = p.heightCm!.toStringAsFixed(0);
    }
    if (p.weightKg != null) {
      _weightCtrl.text = p.weightKg!.toStringAsFixed(1);
    }
    if (p.bloodPressureSystolic != null) {
      _bpSysCtrl.text = p.bloodPressureSystolic.toString();
    }
    if (p.bloodPressureDiastolic != null) {
      _bpDiaCtrl.text = p.bloodPressureDiastolic.toString();
    }
    if (p.oxygenLevel != null) {
      _oxygenCtrl.text = p.oxygenLevel.toString();
    }
    if (p.heartRate != null) {
      _heartRateCtrl.text = p.heartRate.toString();
    }
    if (p.bloodSugarFasting != null) {
      _sugarFastCtrl.text = p.bloodSugarFasting.toString();
    }
    if (p.bloodSugarPostMeal != null) {
      _sugarPostCtrl.text = p.bloodSugarPostMeal.toString();
    }
    if (p.cholesterol != null) {
      _cholCtrl.text = p.cholesterol.toString();
    }
    if (p.temperatureF != null) {
      _tempCtrl.text = p.temperatureF!.toStringAsFixed(1);
    }

    _allergies = List<String>.from(p.allergies);
    _conditions = List<String>.from(p.chronicConditions);

    if (p.disabilities.isNotEmpty) {
      _disabilitiesCtrl.text = p.disabilities;
    }
  }

  // ── Load from Firestore when no existing passed ──────
  Future<void> _loadExisting() async {
    setState(() => _isLoadingExisting = true);
    try {
      final passport = await _service.loadPassport();
      if (passport != null && mounted) {
        _loadedPassport = passport;
        setState(() {
          _populateFrom(passport);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _heightCtrl, _weightCtrl, _bpSysCtrl, _bpDiaCtrl,
      _oxygenCtrl, _heartRateCtrl, _sugarFastCtrl,
      _sugarPostCtrl, _cholCtrl, _tempCtrl,
      _allergyInputCtrl, _conditionInputCtrl, _disabilitiesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── SAVE — merges form values with existing data ──────
  // ✅ KEY FIX: fields left empty keep their OLD values
  // Only fields the user actually filled/changed get updated
  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      // Start from existing loaded passport so nothing is lost
      final existing = _loadedPassport;

      final passport = HealthPassport(
        caregiverId: existing?.caregiverId ?? '',

        // Blood group — always use current selection
        bloodGroup: _bloodGroup,

        // Numerics — use form value if filled, else keep existing
        heightCm: _heightCtrl.text.trim().isNotEmpty
            ? double.tryParse(_heightCtrl.text)
            : existing?.heightCm,

        weightKg: _weightCtrl.text.trim().isNotEmpty
            ? double.tryParse(_weightCtrl.text)
            : existing?.weightKg,

        bloodPressureSystolic: _bpSysCtrl.text.trim().isNotEmpty
            ? int.tryParse(_bpSysCtrl.text)
            : existing?.bloodPressureSystolic,

        bloodPressureDiastolic: _bpDiaCtrl.text.trim().isNotEmpty
            ? int.tryParse(_bpDiaCtrl.text)
            : existing?.bloodPressureDiastolic,

        oxygenLevel: _oxygenCtrl.text.trim().isNotEmpty
            ? int.tryParse(_oxygenCtrl.text)
            : existing?.oxygenLevel,

        heartRate: _heartRateCtrl.text.trim().isNotEmpty
            ? int.tryParse(_heartRateCtrl.text)
            : existing?.heartRate,

        bloodSugarFasting: _sugarFastCtrl.text.trim().isNotEmpty
            ? int.tryParse(_sugarFastCtrl.text)
            : existing?.bloodSugarFasting,

        bloodSugarPostMeal: _sugarPostCtrl.text.trim().isNotEmpty
            ? int.tryParse(_sugarPostCtrl.text)
            : existing?.bloodSugarPostMeal,

        cholesterol: _cholCtrl.text.trim().isNotEmpty
            ? int.tryParse(_cholCtrl.text)
            : existing?.cholesterol,

        temperatureF: _tempCtrl.text.trim().isNotEmpty
            ? double.tryParse(_tempCtrl.text)
            : existing?.temperatureF,

        // Lists — always use current state (chips are always in sync)
        allergies: _allergies,
        chronicConditions: _conditions,

        // Text — use form value if not empty, else keep existing
        disabilities: _disabilitiesCtrl.text.trim().isNotEmpty
            ? _disabilitiesCtrl.text.trim()
            : existing?.disabilities ?? '',
      );

      await _service.savePassport(passport);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack("Error saving: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingExisting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    AppBackButton(
                        onTap: () => Navigator.pop(context)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text("Edit Health Passport",
                          style: AppTextStyles.heading),
                    ),
                  ],
                ),
              ),

              // ── Form ───────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      // ── Basic info ────────────────
                      _sectionHeader("Basic Information",
                          Icons.person_outline),

                      _label("Blood Group"),
                      _bloodGroupSelector(),
                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _label("Height (cm)"),
                              AppInputField(
                                hint: "e.g. 165",
                                controller: _heightCtrl,
                                icon: Icons.height,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _label("Weight (kg)"),
                              AppInputField(
                                hint: "e.g. 70",
                                controller: _weightCtrl,
                                icon: Icons.monitor_weight_outlined,
                              ),
                            ],
                          ),
                        ),
                      ]),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Readings ──────────────────
                      _sectionHeader("Current Readings",
                          Icons.monitor_heart_outlined),

                      _label("Blood Pressure"),
                      Row(children: [
                        Expanded(
                          child: AppInputField(
                            hint: "Systolic (120)",
                            controller: _bpSysCtrl,
                            icon: Icons.favorite_outline,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8),
                          child: Text("/",
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight:
                                      FontWeight.bold)),
                        ),
                        Expanded(
                          child: AppInputField(
                            hint: "Diastolic (80)",
                            controller: _bpDiaCtrl,
                            icon: Icons.favorite_outline,
                          ),
                        ),
                      ]),

                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _label("Oxygen Level (%)"),
                              AppInputField(
                                hint: "e.g. 98",
                                controller: _oxygenCtrl,
                                icon: Icons.air,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _label("Heart Rate (bpm)"),
                              AppInputField(
                                hint: "e.g. 72",
                                controller: _heartRateCtrl,
                                icon: Icons.monitor_heart_outlined,
                              ),
                            ],
                          ),
                        ),
                      ]),

                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _label("Sugar Fasting (mg/dL)"),
                              AppInputField(
                                hint: "e.g. 90",
                                controller: _sugarFastCtrl,
                                icon: Icons.water_drop_outlined,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _label("Sugar Post Meal"),
                              AppInputField(
                                hint: "e.g. 140",
                                controller: _sugarPostCtrl,
                                icon: Icons.water_drop_outlined,
                              ),
                            ],
                          ),
                        ),
                      ]),

                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _label("Cholesterol (mg/dL)"),
                              AppInputField(
                                hint: "e.g. 180",
                                controller: _cholCtrl,
                                icon: Icons.science_outlined,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _label("Temperature (°F)"),
                              AppInputField(
                                hint: "e.g. 98.6",
                                controller: _tempCtrl,
                                icon: Icons.thermostat_outlined,
                              ),
                            ],
                          ),
                        ),
                      ]),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Allergies ─────────────────
                      _sectionHeader("Allergies",
                          Icons.warning_amber_outlined),
                      _chipInput(
                        items: _allergies,
                        controller: _allergyInputCtrl,
                        hint: "Type allergy and press Add",
                        chipColor: Colors.red,
                        onAdd: () {
                          final v =
                              _allergyInputCtrl.text.trim();
                          if (v.isNotEmpty &&
                              !_allergies.contains(v)) {
                            setState(
                                () => _allergies.add(v));
                            _allergyInputCtrl.clear();
                          }
                        },
                        onRemove: (item) => setState(
                            () => _allergies.remove(item)),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Chronic Conditions ────────
                      _sectionHeader("Chronic Conditions",
                          Icons.health_and_safety_outlined),
                      _chipInput(
                        items: _conditions,
                        controller: _conditionInputCtrl,
                        hint: "Type condition and press Add",
                        chipColor: Colors.orange,
                        onAdd: () {
                          final v =
                              _conditionInputCtrl.text.trim();
                          if (v.isNotEmpty &&
                              !_conditions.contains(v)) {
                            setState(
                                () => _conditions.add(v));
                            _conditionInputCtrl.clear();
                          }
                        },
                        onRemove: (item) => setState(
                            () => _conditions.remove(item)),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Disabilities ──────────────
                      _sectionHeader(
                          "Disabilities / Special Needs",
                          Icons.accessibility_outlined),
                      AppInputField(
                        hint:
                            "e.g. Hard of hearing, uses wheelchair",
                        controller: _disabilitiesCtrl,
                        icon: Icons.accessibility_outlined,
                        maxLines: 3,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Save button ───────────────
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      AppRadius.md),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2),
                                )
                              : Text("Save Passport",
                                  style: AppTextStyles.body
                                      .copyWith(
                                          color:
                                              Colors.white)),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bloodGroupSelector() {
    final groups = BloodGroup.values
        .where((g) => g != BloodGroup.unknown)
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: groups.map((g) {
        final selected = _bloodGroup == g;
        return GestureDetector(
          onTap: () => setState(() => _bloodGroup = g),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.border,
              ),
              boxShadow: selected ? [] : [AppShadows.light],
            ),
            child: Text(
              g.label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : AppColors.darkPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _chipInput({
    required List<String> items,
    required TextEditingController controller,
    required String hint,
    required Color chipColor,
    required VoidCallback onAdd,
    required Function(String) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppTextStyles.small,
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(
                        color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(
                        color: AppColors.border),
                  ),
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius:
                      BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.add,
                    color: Colors.white),
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          chipColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item,
                        style: TextStyle(
                            color: chipColor
                                .withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => onRemove(item),
                      child: Icon(Icons.close,
                          size: 14,
                          color: chipColor
                              .withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: AppTextStyles.body
                  .copyWith(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: AppTextStyles.small
                .copyWith(fontWeight: FontWeight.w600)),
      );
}