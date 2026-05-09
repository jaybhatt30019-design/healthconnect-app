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
          style: AppTextStyles.small.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value.toString(),
            style: AppTextStyles.small,
          ),
        ),
      ],
    ),
  );
}

  final service = MedicineService();

  /// ➕ ADD
  Future<void> _openAddMedicine() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddMedicineScreen(),
      ),
    );
  }

  /// ✏️ EDIT
Future<void> _openEditMedicine(DocumentSnapshot doc) async {
  final data = doc.data() as Map<String, dynamic>;

  /// ✅ SAFE TIMES
  List<TimeOfDay> times = [];
  if (data['times'] != null) {
    times = (data['times'] as List)
        .map((t) {
          final parts = t.toString().split(":");
          return TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        })
        .toList();
  }

  final med = Medicine(
    id: "", // 🔥 TEMP (when adding new)
    name: data['name'] ?? "",
    dosage: data['dosage'] ?? "",
    disease: data['disease'] ?? "",
    intake: data['intake'] ?? "Before Food",
    duration: data['duration'] ?? "Ongoing",
    doctor: data['doctor'] ?? "",
    notes: data['notes'] ?? "",
    startDate: data['startDate'] != null
        ? DateTime.tryParse(data['startDate']) ?? DateTime.now()
        : DateTime.now(),
    times: times.isEmpty ? [TimeOfDay.now()] : times,
  );

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddMedicineScreen(
        docId: doc.id,
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
              /// TITLE
              Text("Medicines", style: AppTextStyles.heading),

              const SizedBox(height: AppSpacing.xxl),

              /// 🔥 FIREBASE LIST
              Expanded(
                child: StreamBuilder<List<Medicine>>(
                   stream: service.getMedicines(),
                  builder: (context, snapshot) {

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final medicines = snapshot.data!;

                    if (docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        // final doc = docs[index];
                        // final data = doc.data() as Map<String, dynamic>;

                        return GestureDetector(
  onTap: () => _openEditMedicine(doc),
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

        /// 🟢 MEDICINE NAME
        Text(
          data['name'] ?? "",
          style: AppTextStyles.heading,
        ),

        const SizedBox(height: 6),

        /// 🟡 DISEASE
        _infoRow("Disease", data['disease']),

        /// 💊 DOSAGE
        _infoRow("Dosage", data['dosage']),

        /// 🍽 INTAKE TIME
        _infoRow("Intake", data['intake']),

        /// ⏰ EXACT TIMING
        _infoRow(
          "Timing",
          (data['times'] != null)
              ? (data['times'] as List).join(", ")
              : "",
        ),

        /// 📅 START DATE
        _infoRow(
          "Start Date",
          data['startDate'] != null
              ? data['startDate'].toString().split("T")[0]
              : "",
        ),

        /// ⏳ DURATION
        _infoRow("Duration", data['duration']),

        /// 👨‍⚕️ DOCTOR
        _infoRow("Doctor", data['doctor']),

        /// 📝 NOTES
        _infoRow("Notes", data['notes']),
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

  /// EMPTY UI
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