// lib/features/shared/medicines_screen.dart
// All existing code preserved + stock display + restock button

import 'package:flutter/material.dart';
import 'package:Vitanex/theme/app_design_system.dart';
import 'package:Vitanex/features/dashboard/add_medicine_screen.dart';
import 'package:Vitanex/models/medicine_model.dart';
import 'package:Vitanex/core/services/medicine_service.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() =>
      _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  late final Stream<List<Medicine>> _stream;
  final _service = MedicineService();

  @override
  void initState() {
    super.initState();
    _stream = MedicineService().getMedicines();
  }

  // ── Existing info row — unchanged ─────────────────
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
            style: AppTextStyles.small
                .copyWith(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(value.toString(),
                style: AppTextStyles.small),
          ),
        ],
      ),
    );
  }

 Future<void> _openAddMedicine() async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddMedicineScreen(
        onDone: () => setState(() {}),
      ),
    ),
  );
}

Future<void> _openEditMedicine(Medicine med) async {

  if(!med.isCourseCompleted) {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddMedicineScreen(
        docId: med.id,
        existingMedicine: med,
        onDone: () => setState(() {}),
      ),
    ),
  );
}
}
  // ── Restock dialog — NEW ──────────────────────────
  Future<void> _showRestockDialog(Medicine med) async {
    final ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined,
                color: Color(0xFF0E7C6B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Restock ${med.name}",
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Current stock: ${med.stockDisplay}",
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText:
                    "How many ${med.stockUnit} are you adding?",
                hintText: "e.g. 30",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF0E7C6B), width: 1.5),
                ),
                suffixText: med.stockUnit,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E7C6B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final qty = int.tryParse(ctrl.text.trim());
              if (qty == null || qty <= 0) return;

              Navigator.pop(ctx);
              await _service.restock(med, qty);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      "Restocked ${med.name}: +$qty ${med.stockUnit}"),
                  backgroundColor: const Color(0xFF0E7C6B),
                ),
              );
            },
            child: const Text("Restock",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _openAddMedicine,
        child: const Icon(Icons.add, color: Colors.white),
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
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Error loading medicines",
                          style: AppTextStyles.small,
                        ),
                      );
                    }

                    final medicines = snapshot.data ?? [];

                    if (medicines.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      itemCount: medicines.length,
                      itemBuilder: (context, index) {
                        final med = medicines[index];
                        return _medicineCard(med);
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

  // ── Medicine card — existing info + stock row added ─
  Widget _medicineCard(Medicine med) {
    return GestureDetector(
      onTap: () => _openEditMedicine(med),
      child: Container(
        margin:
            const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          // Red border when out of stock
          border: med.isCourseCompleted ? Border.all(
                      color: Colors.grey.shade700,
                      width: 1.5) : med.isOutOfStock
              ? Border.all(color: Colors.red, width: 1.5)
              : med.isLowStock
                  ? Border.all(
                      color: Colors.amber.shade700,
                      width: 1.5) 
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Name row with stock badge ─────────────
            Row(
              children: [
                Expanded(
                  child: Text(med.name,
                      style: AppTextStyles.heading),
                ),
                _stockBadge(med),
              ],
            ),

            const SizedBox(height: 6),

            // ── Existing info rows — unchanged ─────────
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

            // ── Stock row + Restock button — NEW ───────
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 10),

          med.isCourseCompleted? Container():   Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: _stockColor(med),
                ),
                const SizedBox(width: 6),
                Text(
                  med.isOutOfStock
                      ? "Out of stock"
                      : "${med.stockDisplay} remaining",
                  style: AppTextStyles.small.copyWith(
                    color: _stockColor(med),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Restock button
                GestureDetector(
                  onTap: () => _showRestockDialog(med),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.iconBg,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary,
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add,
                            size: 14,
                            color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          "Restock",
                          style:
                              AppTextStyles.small.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Stock badge chip ──────────────────────────────
  Widget _stockBadge(Medicine med) {
    final color = _stockColor(med);
    final label = med.isCourseCompleted ? "Completed" : med.isOutOfStock
        ? "Out"
        : med.isLowStock
            ? "Low"
            :  "OK";

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _stockColor(Medicine med) {
    if(med.isCourseCompleted) return Colors.grey;
    if (med.isOutOfStock) return Colors.red;
    if (med.isLowStock) return Colors.amber.shade700;
   
    return Colors.green;
  }

  // ── Empty state — unchanged ───────────────────────
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
          Text("No Medicines Added",
              style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Text("Tap + to add medicines",
              style: AppTextStyles.small),
        ],
      ),
    );
  }
}