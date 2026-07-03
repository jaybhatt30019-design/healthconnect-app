// lib/features/health_passport/health_passport_screen.dart

import 'package:flutter/material.dart';
import 'package:Vitanex/theme/app_design_system.dart';
import 'package:Vitanex/models/health_passport_model.dart';
import 'package:Vitanex/core/services/health_passport_service.dart';
import 'package:Vitanex/features/health_passport/health_passport_edit_screen.dart';

class HealthPassportScreen extends StatefulWidget {
  const HealthPassportScreen({super.key});

  @override
  State<HealthPassportScreen> createState() =>
      _HealthPassportScreenState();
}

class _HealthPassportScreenState
    extends State<HealthPassportScreen> {
  // ✅ Fresh service instance per screen — no shared singleton stream
  late final Stream<HealthPassport?> _stream;

  @override
  void initState() {
    super.initState();
    // New HealthPassportService() each time = new stream each time
    _stream = HealthPassportService().passportStream();
  }

  @override
  Widget build(BuildContext context) {
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
                      child: Text("Health Passport",
                          style: AppTextStyles.heading),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const HealthPassportEditScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.iconBg,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit,
                                color: AppColors.primary,
                                size: 16),
                            const SizedBox(width: 4),
                            Text("Edit",
                                style: AppTextStyles.small
                                    .copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ────────────────────────────
              Expanded(
                child: StreamBuilder<HealthPassport?>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final p = snapshot.data;

                    if (p == null ||
                        (p.bloodGroup == BloodGroup.unknown &&
                            p.heightCm == null &&
                            p.weightKg == null &&
                            p.oxygenLevel == null)) {
                      return _emptyState(context);
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      children: [
                        _sectionTitle("Basic Information",
                            Icons.person_outline),
                        _basicInfoCard(p),
                        const SizedBox(height: AppSpacing.lg),

                        _sectionTitle("Current Readings",
                            Icons.monitor_heart_outlined),
                        if (p.readingsUpdatedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: 8, left: 2),
                            child: Text(
                              "Last updated: ${_fmt(p.readingsUpdatedAt!)}",
                              style: AppTextStyles.small,
                            ),
                          ),
                        _readingsCard(p),
                        const SizedBox(height: AppSpacing.lg),

                        _sectionTitle("Allergies",
                            Icons.warning_amber_outlined),
                        _chipsCard(
                            items: p.allergies,
                            emptyText: "No allergies recorded",
                            chipColor: Colors.red),
                        const SizedBox(height: AppSpacing.lg),

                        _sectionTitle("Chronic Conditions",
                            Icons.health_and_safety_outlined),
                        _chipsCard(
                            items: p.chronicConditions,
                            emptyText:
                                "No chronic conditions recorded",
                            chipColor: Colors.orange),

                        if (p.disabilities.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _sectionTitle(
                              "Disabilities / Special Needs",
                              Icons.accessibility_outlined),
                          _textCard(p.disabilities),
                          // After the last _div() and temperature row, add:
const SizedBox(height: 12),
const Divider(height: 1, color: Color(0xFFF0F0F0)),
const SizedBox(height: 12),
Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: Colors.amber.shade50,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.amber.shade200),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.info_outline,
              size: 14, color: Colors.amber.shade700),
          const SizedBox(width: 6),
          Text(
            "Disclaimer",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.amber.shade800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        "All readings above are manually entered by the user. "
        "This data is not measured or verified by Vitanex. "
        "Always consult a qualified medical professional.",
        style: TextStyle(
          fontSize: 11,
          color: Colors.amber.shade900,
          height: 1.4,
        ),
      ),
    ],
  ),
),
                        ],

                        const SizedBox(height: AppSpacing.xl),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _basicInfoCard(HealthPassport p) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.light],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _statBox(
                      label: "Blood Group",
                      value: p.bloodGroup.label,
                      icon: Icons.bloodtype_outlined,
                      valueColor: AppColors.primary,
                      large: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statBox(
                      label: "Height",
                      value: p.heightCm != null
                          ? "${p.heightCm!.toStringAsFixed(0)} cm"
                          : "—",
                      icon: Icons.height)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statBox(
                      label: "Weight",
                      value: p.weightKg != null
                          ? "${p.weightKg!.toStringAsFixed(1)} kg"
                          : "—",
                      icon: Icons.monitor_weight_outlined)),
            ],
          ),
          if (p.bmi != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calculate_outlined,
                    size: 16, color: AppColors.hint),
                const SizedBox(width: 6),
                Text("BMI: ",
                    style: AppTextStyles.small
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(
                  "${p.bmi!.toStringAsFixed(1)} — ${p.bmiLabel}",
                  style: AppTextStyles.small.copyWith(
                      color: _bmiColor(p.bmi!),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _readingsCard(HealthPassport p) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.light],
      ),
      child: Column(
        children: [
          _row("Blood Pressure", p.bpDisplay,
              Icons.favorite_outline,
              _bpColor(p.bloodPressureSystolic)),
          _div(),
          _row(
              "Oxygen Level (SpO2)",
              p.oxygenLevel != null
                  ? "${p.oxygenLevel}%"
                  : "—",
              Icons.air,
              _spo2Color(p.oxygenLevel)),
          _div(),
          _row(
              "Heart Rate",
              p.heartRate != null
                  ? "${p.heartRate} bpm"
                  : "—",
              Icons.monitor_heart_outlined,
              _pulseColor(p.heartRate)),
          _div(),
          _row(
              "Blood Sugar (Fasting)",
              p.bloodSugarFasting != null
                  ? "${p.bloodSugarFasting} mg/dL"
                  : "—",
              Icons.water_drop_outlined,
              _sugarColor(p.bloodSugarFasting)),
          _div(),
          _row(
              "Blood Sugar (Post Meal)",
              p.bloodSugarPostMeal != null
                  ? "${p.bloodSugarPostMeal} mg/dL"
                  : "—",
              Icons.water_drop_outlined,
              null),
          _div(),
          _row(
              "Cholesterol",
              p.cholesterol != null
                  ? "${p.cholesterol} mg/dL"
                  : "—",
              Icons.science_outlined,
              _cholColor(p.cholesterol)),
          _div(),
          _row(
              "Temperature",
              p.temperatureF != null
                  ? "${p.temperatureF!.toStringAsFixed(1)} °F"
                  : "—",
              Icons.thermostat_outlined,
              _tempColor(p.temperatureF)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, IconData icon,
      Color? dot) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.hint),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label, style: AppTextStyles.small)),
          if (dot != null)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                  color: dot, shape: BoxShape.circle),
            ),
          Text(value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: value == '—'
                    ? AppColors.hint
                    : AppColors.darkPrimary,
              )),
        ],
      ),
    );
  }

  Widget _chipsCard(
      {required List<String> items,
      required String emptyText,
      required Color chipColor}) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.light],
        ),
        child: Row(children: [
          const Icon(Icons.info_outline,
              color: AppColors.hint, size: 16),
          const SizedBox(width: 8),
          Text(emptyText, style: AppTextStyles.small),
        ]),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.light],
      ),
      child: Wrap(
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
                  color: chipColor.withValues(alpha: 0.3)),
            ),
            child: Text(item,
                style: TextStyle(
                    color: chipColor.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          );
        }).toList(),
      ),
    );
  }

  Widget _textCard(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.light],
        ),
        child: Text(text, style: AppTextStyles.body),
      );

  Widget _statBox({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
    bool large = false,
  }) =>
      Column(children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: large ? 22 : 16,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.darkPrimary)),
        const SizedBox(height: 4),
        Text(label,
            style: AppTextStyles.small,
            textAlign: TextAlign.center),
      ]);

  Widget _sectionTitle(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: AppTextStyles.body
                  .copyWith(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _div() =>
      const Divider(height: 1, color: Color(0xFFF5F5F5));

  Widget _emptyState(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                    color: AppColors.iconBg,
                    shape: BoxShape.circle),
                child: const Icon(Icons.badge_outlined,
                    size: 44, color: AppColors.accent),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text("Health Passport Empty",
                  style: AppTextStyles.body),
              const SizedBox(height: 8),
              Text(
                "Add health parameters to create\na complete medical profile",
                style: AppTextStyles.small,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const HealthPassportEditScreen()),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Fill Passport",
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ],
          ),
        ),
      );

  String _fmt(DateTime dt) =>
      "${dt.day}/${dt.month}/${dt.year}";

  Color _bpColor(int? s) {
    if (s == null) return Colors.grey;
    if (s <= 120) return Colors.green;
    if (s <= 139) return Colors.amber.shade700;
    return Colors.red;
  }

  Color _spo2Color(int? v) {
    if (v == null) return Colors.grey;
    if (v >= 95) return Colors.green;
    if (v >= 90) return Colors.amber.shade700;
    return Colors.red;
  }

  Color _pulseColor(int? v) {
    if (v == null) return Colors.grey;
    if (v >= 60 && v <= 100) return Colors.green;
    if (v >= 50 && v <= 110) return Colors.amber.shade700;
    return Colors.red;
  }

  Color _sugarColor(int? v) {
    if (v == null) return Colors.grey;
    if (v <= 100) return Colors.green;
    if (v <= 125) return Colors.amber.shade700;
    return Colors.red;
  }

  Color _cholColor(int? v) {
    if (v == null) return Colors.grey;
    if (v < 200) return Colors.green;
    if (v < 240) return Colors.amber.shade700;
    return Colors.red;
  }

  Color _tempColor(double? v) {
    if (v == null) return Colors.grey;
    if (v >= 97 && v <= 99) return Colors.green;
    if (v > 99 && v <= 100.4) return Colors.amber.shade700;
    return Colors.red;
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.amber.shade700;
    return Colors.red;
  }
}