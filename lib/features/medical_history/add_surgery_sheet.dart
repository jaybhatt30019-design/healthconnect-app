// lib/features/medical_history/add_surgery_sheet.dart

import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/medical_history_model.dart';
import 'package:healthconnect/core/services/medical_history_service.dart';

class AddSurgerySheet extends StatefulWidget {
  final Surgery? existing;

  const AddSurgerySheet({super.key, this.existing});

  @override
  State<AddSurgerySheet> createState() => _AddSurgerySheetState();
}

class _AddSurgerySheetState extends State<AddSurgerySheet> {
  final _service = MedicalHistoryService();

  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _surgeonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isSaving = false;
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _dateCtrl.text = e.date ?? '';
      _hospitalCtrl.text = e.hospital ?? '';
      _surgeonCtrl.text = e.surgeon ?? '';
      _notesCtrl.text = e.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    _hospitalCtrl.dispose();
    _surgeonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack("Please enter surgery name");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final surgery = Surgery(
        id: widget.existing?.id ?? '',
        name: _nameCtrl.text.trim(),
        date: _dateCtrl.text.trim(),
        hospital: _hospitalCtrl.text.trim(),
        surgeon: _surgeonCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );

      if (_isEdit) {
        await _service.updateSurgery(surgery);
      } else {
        await _service.addSurgery(surgery);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack("Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Surgery"),
        content: const Text("Remove this from medical history?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete",
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await _service.deleteSurgery(widget.existing!.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack("Error: $e");
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
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ───────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              _isEdit ? "Edit Surgery" : "Add Past Surgery",
              style: AppTextStyles.heading,
            ),
            const SizedBox(height: 20),

            // ── Surgery name ──────────────────────────
            _label("Surgery Name *"),
            AppInputField(
              hint: "e.g. Knee Replacement, Appendectomy",
              controller: _nameCtrl,
              icon: Icons.medical_services_outlined,
            ),

            const SizedBox(height: 14),

            // ── Date ──────────────────────────────────
            _label("Date of Surgery"),
            AppInputField(
              hint: "e.g. June 2019 or 2019",
              controller: _dateCtrl,
              icon: Icons.calendar_today_outlined,
            ),

            const SizedBox(height: 14),

            // ── Hospital ──────────────────────────────
            _label("Hospital / Clinic"),
            AppInputField(
              hint: "e.g. City General Hospital",
              controller: _hospitalCtrl,
              icon: Icons.local_hospital_outlined,
            ),

            const SizedBox(height: 14),

            // ── Surgeon ───────────────────────────────
            _label("Surgeon (Optional)"),
            AppInputField(
              hint: "e.g. Dr. Sharma",
              controller: _surgeonCtrl,
              icon: Icons.person_outline,
            ),

            const SizedBox(height: 14),

            // ── Notes ─────────────────────────────────
            _label("Notes / Complications (Optional)"),
            AppInputField(
              hint: "e.g. Full recovery in 3 months",
              controller: _notesCtrl,
              icon: Icons.notes_outlined,
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // ── Save ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isEdit ? "Update" : "Save Surgery",
                        style: AppTextStyles.body
                            .copyWith(color: Colors.white),
                      ),
              ),
            ),

            if (_isEdit) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text("Delete",
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: AppTextStyles.small
                .copyWith(fontWeight: FontWeight.w600)),
      );
}