import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/features/dashboard/add_medicine_screen.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthconnect/core/services/medicine_service.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  final service = MedicineService();

  Widget _infoRow(String title, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$title: ",
            style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(value.toString(), style: AppTextStyles.small),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddMedicine() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
    );
  }

  Future<void> _openEditMedicine(Medicine med) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicineScreen(
          docId: med.id,
          existingMedicine: med,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _openAddMedicine,
        child: const Icon(Icons.add),
      ),
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Medicines", style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xxl),
              Expanded(
                child: StreamBuilder<List<Medicine>>(
                  stream: service.getMedicines(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final medicines = snapshot.data!;

                    if (medicines.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      itemCount: medicines.length,
                      itemBuilder: (context, index) {
                        final med = medicines[index];

                        return GestureDetector(
                          onTap: () => _openEditMedicine(med),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(med.name, style: AppTextStyles.heading),
                                const SizedBox(height: 6),
                                _infoRow("Disease", med.disease),
                                _infoRow("Dosage", med.dosage),
                                _infoRow("Intake", med.intake),
                                _infoRow(
                                  "Timing",
                                  med.times
                                      .map((t) =>
                                          "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}")
                                      .join(", "),
                                ),
                                _infoRow(
                                  "Start Date",
                                  med.startDate != null
                                      ? "${med.startDate!.day}/${med.startDate!.month}/${med.startDate!.year}"
                                      : null,
                                ),
                                _infoRow("Duration", med.duration),
                                _infoRow("Doctor", med.doctor),
                                _infoRow("Notes", med.notes),
                              ],
                            ),
                          ),
                        );
                      },
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.iconBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_outlined,
              size: 40,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text("No Medicines Added", style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Text("Tap + to add medicines", style: AppTextStyles.small),
        ],
      ),
    );
  }
}