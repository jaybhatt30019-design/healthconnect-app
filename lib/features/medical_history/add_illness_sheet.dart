// lib/features/medical_history/add_illness_sheet.dart

import 'package:flutter/material.dart';
import 'package:Vitanex/theme/app_design_system.dart';
import 'package:Vitanex/models/medical_history_model.dart';
import 'package:Vitanex/core/services/medical_history_service.dart';

class AddIllnessSheet extends StatefulWidget {
  final Illness? existing; // null = add, non-null = edit

  const AddIllnessSheet({super.key, this.existing});

  @override
  State<AddIllnessSheet> createState() => _AddIllnessSheetState();
}

class _AddIllnessSheetState extends State<AddIllnessSheet> {
  final _service = MedicalHistoryService();

  final _nameCtrl = TextEditingController();
  final _diagnosedCtrl = TextEditingController();
  final _recoveredCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Severity _severity = Severity.mild;
  bool _isOngoing = true;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _diagnosedCtrl.text = e.diagnosedDate ?? '';
      _recoveredCtrl.text = e.recoveredDate ?? '';
      _doctorCtrl.text = e.doctor ?? '';
      _notesCtrl.text = e.notes ?? '';
      _severity = e.severity;
      _isOngoing = e.isOngoing;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _diagnosedCtrl.dispose();
    _recoveredCtrl.dispose();
    _doctorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack("Please enter illness name");
      return;
    }

    if(!_isOngoing){
    if(_recoveredCtrl.text.trim().isEmpty){
      _snack("Please enter Recory Date");
      return;
    }
    }

    setState(() => _isSaving = true);

    try {
      final illness = Illness(
        id: widget.existing?.id ?? '',
        name: _nameCtrl.text.trim(),
        diagnosedDate: _diagnosedCtrl.text.trim(),
        recoveredDate: _isOngoing ? null : _recoveredCtrl.text.trim(),
        severity: _severity,
        doctor: _doctorCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );

      if (_isEdit) {
        await _service.updateIllness(illness);
      } else {
        await _service.addIllness(illness);
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
        title: const Text("Delete Illness"),
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
      await _service.deleteIllness(widget.existing!.id);
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
              _isEdit ? "Edit Illness" : "Add Past Illness",
              style: AppTextStyles.heading,
            ),
            const SizedBox(height: 20),

            // ── Name ─────────────────────────────────
            _label("Illness / Condition *"),
            AppInputField(
              hint: "e.g. Diabetes, Hypertension",
              controller: _nameCtrl,
              icon: Icons.sick_outlined,
            ),

            const SizedBox(height: 14),

            // ── Severity ─────────────────────────────
            _label("Severity"),
            _severitySelector(),

            const SizedBox(height: 14),

            // ── Diagnosed date ────────────────────────
            _label("Diagnosed Date"),
            AppInputField(
              hint: "e.g. Jan 2020 or 2020",
              controller: _diagnosedCtrl,
              icon: Icons.calendar_today_outlined,
            ),

            const SizedBox(height: 14),

            // ── Ongoing toggle ────────────────────────
            _ongoingToggle(),

            const SizedBox(height: 14),

            // ── Recovered date ────────────────────────
            if (!_isOngoing) ...[
              _label("Recovered Date"),
              AppInputField(
                hint: "e.g. Mar 2021",
                controller: _recoveredCtrl,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 14),
            ],

            // ── Doctor ────────────────────────────────
            _label("Diagnosed By (Optional)"),
            AppInputField(
              hint: "e.g. Dr. Patel",
              controller: _doctorCtrl,
              icon: Icons.person_outline,
            ),

            const SizedBox(height: 14),

            // ── Notes ─────────────────────────────────
            _label("Notes (Optional)"),
            AppInputField(
              hint: "Additional details...",
              controller: _notesCtrl,
              icon: Icons.notes_outlined,
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // ── Save button ───────────────────────────
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
                        _isEdit ? "Update" : "Save Illness",
                        style: AppTextStyles.body
                            .copyWith(color: Colors.white),
                      ),
              ),
            ),

            // ── Delete button ─────────────────────────
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

  Widget _severitySelector() {
    return Row(
      children: Severity.values.map((s) {
        final isSelected = _severity == s;
        final color = s == Severity.mild
            ? Colors.green
            : s == Severity.moderate
                ? Colors.amber.shade700
                : Colors.red;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _severity = s),
            child: Container(
              margin: EdgeInsets.only(
                  right: s != Severity.severe ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(
                s.name[0].toUpperCase() + s.name.substring(1),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _ongoingToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isOngoing
            ? Colors.red.shade50
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: _isOngoing
              ? Colors.red.shade200
              : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isOngoing ? Icons.warning_amber : Icons.check_circle,
            color: _isOngoing ? Colors.red : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isOngoing ? "Still ongoing" : "Recovered",
              style: TextStyle(
                color: _isOngoing ? Colors.red : Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: _isOngoing,
            onChanged: (v) => setState(() => _isOngoing = v),
            activeThumbColor: Colors.red,
            inactiveThumbColor: Colors.green,
            inactiveTrackColor: Colors.green.shade200,
          ),
        ],
      ),
    );
  }
}