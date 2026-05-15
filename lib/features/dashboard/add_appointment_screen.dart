// lib/features/dashboard/add_appointment_screen.dart

import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/core/services/appointment_service.dart';

class AddAppointmentScreen extends StatefulWidget {
  final Appointment? existingAppointment;

  const AddAppointmentScreen({super.key, this.existingAppointment});

  @override
  State<AddAppointmentScreen> createState() =>
      _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _service = AppointmentService();

  final _doctorController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _reminder = '1 hour before';
  bool _isSaving = false;

  bool get _isEdit => widget.existingAppointment != null;

  @override
  void initState() {
    super.initState();

    if (_isEdit) {
      final a = widget.existingAppointment!;
      _doctorController.text = a.doctorName;
      _hospitalController.text = a.hospitalName;
      _reasonController.text = a.reason;
      _notesController.text = a.notes;
      _selectedDate = a.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(a.dateTime);
      _reminder =
          a.reminder.isNotEmpty ? a.reminder : '1 hour before';
    }
  }

  @override
  void dispose() {
    _doctorController.dispose();
    _hospitalController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate:
          DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ─────────────────────────────────────────────────────
  // SAVE
  // ✅ FIXED: addAppointment returns void — removed null check
  // ─────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_doctorController.text.trim().isEmpty) {
      _snack("Please enter doctor name");
      return;
    }
    if (_hospitalController.text.trim().isEmpty) {
      _snack("Please enter hospital/clinic name");
      return;
    }
    if (_selectedDate == null) {
      _snack("Please select a date");
      return;
    }
    if (_selectedTime == null) {
      _snack("Please select a time");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final appointment = Appointment(
        id: widget.existingAppointment?.id ?? '',
        doctorName: _doctorController.text.trim(),
        hospitalName: _hospitalController.text.trim(),
        dateTime: dt,
        reason: _reasonController.text.trim(),
        reminder: _reminder,
        notes: _notesController.text.trim(),
      );

      if (_isEdit) {
        // ✅ updateAppointment is void — just await it
        await _service.updateAppointment(appointment);
        _snack("Appointment updated");
      } else {
        // ✅ addAppointment is void — just await it, no null check
        await _service.addAppointment(appointment);
        _snack("Appointment saved");
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack("Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────
  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Appointment"),
        content: const Text(
            "Are you sure you want to delete this appointment?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await _service.deleteAppointment(
          widget.existingAppointment!.id);
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
    return Scaffold(
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBackButton(onTap: () => Navigator.pop(context)),

              const SizedBox(height: AppSpacing.md),

              Text(
                _isEdit ? "Edit Appointment" : "Add Appointment",
                style: AppTextStyles.heading,
              ),

              const SizedBox(height: AppSpacing.lg),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      _label("Doctor Name *"),
                      AppInputField(
                        hint: "e.g., Dr. Smith",
                        controller: _doctorController,
                        icon: Icons.person_outline,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _label("Hospital / Clinic *"),
                      AppInputField(
                        hint: "e.g., City Hospital",
                        controller: _hospitalController,
                        icon: Icons.local_hospital_outlined,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _label("Date *"),
                      GestureDetector(
                        onTap: _pickDate,
                        child: _pickerField(
                          icon: Icons.calendar_today,
                          text: _selectedDate == null
                              ? "Select Date"
                              : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                          isSet: _selectedDate != null,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _label("Time *"),
                      GestureDetector(
                        onTap: _pickTime,
                        child: _pickerField(
                          icon: Icons.access_time,
                          text: _selectedTime == null
                              ? "Select Time"
                              : _selectedTime!.format(context),
                          isSet: _selectedTime != null,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _label("Reason for Visit"),
                      AppInputField(
                        hint: "e.g., Routine checkup",
                        controller: _reasonController,
                        icon: Icons.medical_information_outlined,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _label("Reminder"),
                      _reminderDropdown(),

                      const SizedBox(height: AppSpacing.md),

                      _label("Additional Notes"),
                      AppInputField(
                        hint: "e.g., Bring previous reports",
                        controller: _notesController,
                        icon: Icons.notes_outlined,
                        maxLines: 3,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Save button ──────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppRadius.md),
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
                                  _isEdit
                                      ? "Update Appointment"
                                      : "Save Appointment",
                                  style: AppTextStyles.body
                                      .copyWith(
                                          color: Colors.white),
                                ),
                        ),
                      ),

                      // ── Delete button (edit only) ────
                      if (_isEdit) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed:
                                _isSaving ? null : _delete,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                        AppRadius.md),
                              ),
                            ),
                            child: const Text(
                              "Delete Appointment",
                              style: TextStyle(
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.lg),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: AppTextStyles.small
              .copyWith(fontWeight: FontWeight.w600),
        ),
      );

  Widget _pickerField({
    required IconData icon,
    required String text,
    required bool isSet,
  }) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isSet ? AppColors.primary : AppColors.border,
          width: isSet ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color:
                  isSet ? AppColors.primary : AppColors.accent),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppTextStyles.body.copyWith(
              color: isSet
                  ? AppColors.darkPrimary
                  : AppColors.hint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderDropdown() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _reminder,
          isExpanded: true,
          style: AppTextStyles.body,
          items: const [
            "1 hour before",
            "3 hours before",
            "1 day before",
          ]
              .map((e) => DropdownMenuItem(
                  value: e, child: Text(e)))
              .toList(),
          onChanged: (val) =>
              setState(() => _reminder = val!),
        ),
      ),
    );
  }
}