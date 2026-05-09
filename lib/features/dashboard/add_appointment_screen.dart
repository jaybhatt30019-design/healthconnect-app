import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/core/appointment_store.dart';

class AddAppointmentScreen extends StatefulWidget {
  final Appointment? existingAppointment;

  const AddAppointmentScreen({super.key, this.existingAppointment});

  @override
  State<AddAppointmentScreen> createState() =>
      _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final doctorController = TextEditingController();
  final hospitalController = TextEditingController();
  final reasonController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  String reminder = "1 hour before";

  @override
  void initState() {
    super.initState();

if (widget.existingAppointment != null) {
    selectedDate = widget.existingAppointment!.dateTime;
    selectedTime =
        TimeOfDay.fromDateTime(widget.existingAppointment!.dateTime);
  }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  void saveAppointment() {
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select date & time")),
      );
      return;
    }

    if (doctorController.text.isEmpty ||
        hospitalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

final combinedDateTime = DateTime(
  selectedDate!.year,
  selectedDate!.month,
  selectedDate!.day,
  selectedTime!.hour,
  selectedTime!.minute,
);

final appointment = Appointment(
  id: widget.existingAppointment?.id ??
      DateTime.now().toString(),
  doctorName: doctorController.text,
  hospitalName: hospitalController.text,
  dateTime: combinedDateTime, // ✅
  reason: reasonController.text,
);

    if (widget.existingAppointment != null) {
      AppointmentStore.updateAppointment(appointment);
    } else {
      AppointmentStore.addAppointment(appointment);
    }

    Navigator.pop(context, true);
  }

  void deleteAppointment() {
    AppointmentStore.deleteAppointment(
        widget.existingAppointment!.id);

    Navigator.pop(context, true);
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
                widget.existingAppointment == null
                    ? "Add Appointment"
                    : "Edit Appointment",
                style: AppTextStyles.heading,
              ),

              const SizedBox(height: AppSpacing.lg),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      AppInputField(
                        hint: "Doctor Name",
                        controller: doctorController,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      AppInputField(
                        hint: "Hospital / Clinic Name",
                        controller: hospitalController,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      GestureDetector(
                        onTap: pickDate,
                        child: _buildPickerField(
                          icon: Icons.calendar_today,
                          text: selectedDate == null
                              ? "Select Date"
                              : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      GestureDetector(
                        onTap: pickTime,
                        child: _buildPickerField(
                          icon: Icons.access_time,
                          text: selectedTime == null
                              ? "Select Time"
                              : selectedTime!.format(context),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      AppInputField(
                        hint: "Reason for Visit",
                        controller: reasonController,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _buildReminderDropdown(),

                      const SizedBox(height: AppSpacing.xl),

                      /// SAVE
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: saveAppointment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          child: Text(
                            "Save Appointment",
                            style: AppTextStyles.body
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),

                      /// DELETE (ONLY EDIT MODE)
                      if (widget.existingAppointment != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: deleteAppointment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text("Delete Appointment"),
                            ),
                          ),
                        ),
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

  Widget _buildPickerField({
    required IconData icon,
    required String text,
  }) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: 12),
          Text(text, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Widget _buildReminderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<String>(
        value: reminder,
        isExpanded: true,
        underline: const SizedBox(),
        style: AppTextStyles.body,
        items: [
          "1 hour before",
          "3 hours before",
          "1 day before",
        ].map((e) {
          return DropdownMenuItem(
            value: e,
            child: Text(e),
          );
        }).toList(),
        onChanged: (val) {
          setState(() => reminder = val!);
        },
      ),
    );
  }
}
