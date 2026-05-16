// lib/features/medical_history/medical_history_screen.dart

import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/medical_history_model.dart';
import 'package:healthconnect/core/services/medical_history_service.dart';
import 'package:healthconnect/features/medical_history/add_illness_sheet.dart';
import 'package:healthconnect/features/medical_history/add_surgery_sheet.dart';

class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  State<MedicalHistoryScreen> createState() =>
      _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState
    extends State<MedicalHistoryScreen> {
  // ✅ Fresh service instance per screen — no shared singleton stream
  late final Stream<MedicalHistory?> _stream;

  @override
  void initState() {
    super.initState();
    // New MedicalHistoryService() each time = new stream each time
    _stream = MedicalHistoryService().historyStream();
  }

  void _showIllnessSheet({Illness? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddIllnessSheet(existing: existing),
    );
  }

  void _showSurgerySheet({Surgery? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSurgerySheet(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ───────────────────────────────
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    AppBackButton(
                        onTap: () => Navigator.pop(context)),
                    const SizedBox(width: AppSpacing.md),
                    Text("Medical History",
                        style: AppTextStyles.heading),
                  ],
                ),
              ),

              // ── Content ──────────────────────────────
              Expanded(
                child: StreamBuilder<MedicalHistory?>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final history = snapshot.data;
                    final illnesses = history?.illnesses ?? [];
                    final surgeries = history?.surgeries ?? [];

                    if (illnesses.isEmpty && surgeries.isEmpty) {
                      return _emptyState();
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      children: [
                        _sectionHeader(
                          title: "Past Illnesses",
                          icon: Icons.sick_outlined,
                          count: illnesses.length,
                          onAdd: () => _showIllnessSheet(),
                        ),
                        if (illnesses.isEmpty)
                          _emptySection("No illnesses recorded")
                        else
                          ...illnesses.map(
                              (ill) => _illnessCard(ill)),

                        const SizedBox(height: AppSpacing.xl),

                        _sectionHeader(
                          title: "Past Surgeries",
                          icon: Icons.medical_services_outlined,
                          count: surgeries.length,
                          onAdd: () => _showSurgerySheet(),
                        ),
                        if (surgeries.isEmpty)
                          _emptySection("No surgeries recorded")
                        else
                          ...surgeries
                              .map((s) => _surgeryCard(s)),

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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'illness',
            onPressed: () => _showIllnessSheet(),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.sick_outlined,
                color: Colors.white),
            label: const Text("Add Illness",
                style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'surgery',
            onPressed: () => _showSurgerySheet(),
            backgroundColor: AppColors.darkPrimary,
            icon: const Icon(Icons.medical_services_outlined,
                color: Colors.white),
            label: const Text("Add Surgery",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _illnessCard(Illness ill) {
    final severityColor = ill.severity == Severity.mild
        ? Colors.green
        : ill.severity == Severity.moderate
            ? Colors.amber.shade700
            : Colors.red;

    final severityLabel = ill.severity.name[0].toUpperCase() +
        ill.severity.name.substring(1);

    return GestureDetector(
      onTap: () => _showIllnessSheet(existing: ill),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.light],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(ill.name,
                      style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(severityLabel,
                      style: TextStyle(
                          color: severityColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                if (ill.isOngoing)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text("Ongoing",
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            if (ill.diagnosedDate?.isNotEmpty == true)
              _infoRow(Icons.calendar_today_outlined,
                  "Diagnosed: ${ill.diagnosedDate}"),
            if (!ill.isOngoing &&
                ill.recoveredDate?.isNotEmpty == true)
              _infoRow(Icons.check_circle_outline,
                  "Recovered: ${ill.recoveredDate}"),
            if (ill.doctor?.isNotEmpty == true)
              _infoRow(Icons.person_outline, ill.doctor!),
            if (ill.notes?.isNotEmpty == true)
              _infoRow(Icons.notes_outlined, ill.notes!),
          ],
        ),
      ),
    );
  }

  Widget _surgeryCard(Surgery surgery) {
    return GestureDetector(
      onTap: () => _showSurgerySheet(existing: surgery),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.light],
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.iconBg,
                      shape: BoxShape.circle),
                  child: const Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.primary,
                      size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(surgery.name,
                      style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.edit,
                    color: AppColors.hint, size: 16),
              ],
            ),
            if (surgery.date?.isNotEmpty == true ||
                surgery.hospital?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              const Divider(
                  height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 10),
            ],
            if (surgery.date?.isNotEmpty == true)
              _infoRow(Icons.calendar_today_outlined,
                  surgery.date!),
            if (surgery.hospital?.isNotEmpty == true)
              _infoRow(Icons.local_hospital_outlined,
                  surgery.hospital!),
            if (surgery.surgeon?.isNotEmpty == true)
              _infoRow(Icons.person_outline, surgery.surgeon!),
            if (surgery.notes?.isNotEmpty == true)
              _infoRow(Icons.notes_outlined, surgery.notes!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: AppColors.hint),
            const SizedBox(width: 6),
            Expanded(
                child: Text(text, style: AppTextStyles.small)),
          ],
        ),
      );

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    required int count,
    required VoidCallback onAdd,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.heading),
            const SizedBox(width: 8),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.iconBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("$count",
                    style: AppTextStyles.small.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
            const Spacer(),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.iconBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 4),
                    Text("Add",
                        style: AppTextStyles.small.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _emptySection(String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline,
              color: AppColors.hint, size: 16),
          const SizedBox(width: 8),
          Text(text, style: AppTextStyles.small),
        ]),
      );

  Widget _emptyState() => Center(
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
                child: const Icon(
                    Icons.health_and_safety_outlined,
                    size: 44,
                    color: AppColors.accent),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text("No Medical History",
                  style: AppTextStyles.body),
              const SizedBox(height: 8),
              Text(
                "Add past illnesses and surgeries\nfor a complete health record",
                style: AppTextStyles.small,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: () => _showIllnessSheet(),
                icon:
                    const Icon(Icons.add, color: Colors.white),
                label: const Text("Add First Entry",
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
}