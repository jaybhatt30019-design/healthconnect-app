import 'package:flutter/material.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/core/services/medicine_service.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? existingMedicine;
  final int? index;
  final String? docId;

  const AddMedicineScreen({
    super.key,
    this.existingMedicine,
    this.index,
    this.docId,
  });

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final name = TextEditingController();
  final disease = TextEditingController();
  final dosage = TextEditingController();
  final doctor = TextEditingController();
  final notes = TextEditingController();

  String intake = "Before Food";
  String duration = "Ongoing";

  DateTime selectedDate = DateTime.now();

  /// ✅ Timing controller
  final GlobalKey<_TimingCardState> timingKey = GlobalKey();

  @override
void initState() {
  super.initState();

  if (widget.existingMedicine != null) {
    final med = widget.existingMedicine!;

    name.text = med.name;
    disease.text = med.disease ?? "";
    dosage.text = med.dosage;
    doctor.text = med.doctor ?? "";
    notes.text = med.notes ?? "";

    intake = med.intake ?? "Before Food";
    duration = med.duration ?? "Ongoing";
    selectedDate = med.startDate ?? DateTime.now();

    /// Timing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      timingKey.currentState?.setTimes(med.times);
    });
  }
}

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.docId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF4F3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// HEADER
              Row(
                children: [
                  _circleBack(context),
                  const Spacer(),
                  Text(
                    isEdit ? "Edit Medication" : "Add Medication",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),

              const SizedBox(height: 20),

              _label("Medication Name"),
              AppInputField(
                  controller: name,
                  hint: "e.g., Aspirin",
                  icon: Icons.medication),

              _label("Disease / Condition"),
              AppInputField(
                  controller: disease,
                  hint: "e.g., Hypertension",
                  icon: Icons.monitor_heart),

              /// DOSAGE + INTAKE
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Dosage"),
                        AppInputField(
                            controller: dosage,
                            hint: "e.g., 500mg",
                            icon: Icons.scale),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Intake Time"),
                        AppDropdown(
                          value: intake,
                          items: const ["Before Food", "After Food"],
                          onChanged: (val) => setState(() => intake = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              /// TIMING
              _label("Exact Timing"),
              TimingCard(key: timingKey),

              /// DATE + DURATION
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Start Date"),
                        AppBox(
                          text:
                              "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                          icon: Icons.calendar_today,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Duration"),
                        AppDropdown(
                          value: duration,
                          items: const [
                            "Ongoing",
                            "7 Days",
                            "15 Days",
                            "30 Days"
                          ],
                          onChanged: (val) => setState(() => duration = val),
                          icon: Icons.hourglass_bottom,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              _label("Prescribed By (Optional)"),
              AppInputField(
                  controller: doctor,
                  hint: "e.g., Dr. Smith",
                  icon: Icons.person),

              _label("Special Instructions"),
              AppInputField(
                controller: notes,
                hint: "Take with food...",
                icon: Icons.description,
                maxLines: 3,
              ),

              const SizedBox(height: 20),

              /// SAVE BUTTON
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E7C6B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () async {
  final times = timingKey.currentState?.getTimes() ?? [];

  final med = Medicine(
    name: name.text,
    dosage: dosage.text,
    disease: disease.text,
    intake: intake,
    duration: duration,
    doctor: doctor.text,
    notes: notes.text,
    startDate: selectedDate,
    times: times.isEmpty ? [TimeOfDay.now()] : times,
  );

  final service = MedicineService();

  if (widget.docId != null) {
    await service.updateMedicine(widget.docId!, med);
  } else {
    await service.addMedicine(med);
  }

  Navigator.pop(context);
},
                  child: Text(
                    isEdit ? "Update Medication" : "Save Medication",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              /// ❌ DELETE BUTTON (ONLY EDIT MODE)
              if (isEdit)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () async {
  final service = MedicineService();

  if (widget.docId != null) {
    await service.deleteMedicine(widget.docId!);
  }

  Navigator.pop(context);
},
                      child: const Text("Delete",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleBack(BuildContext context) {
    return GestureDetector(
      onTap: () {
  Navigator.of(context).pop();
},
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
/// ================= TIMING CARD =================

class TimingCard extends StatefulWidget {
  const TimingCard({super.key});

  @override
  State<TimingCard> createState() => _TimingCardState();
}

class _TimingCardState extends State<TimingCard> {
  TimeOfDay? morning = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? afternoon = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay? night;

  String format(TimeOfDay? t) {
    if (t == null) return "Set Time";
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? "AM" : "PM";
    return "$h:$m $p";
  }

  Future<void> pick(Function(TimeOfDay) setTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setTime(picked);
  }

  /// ✅ IMPORTANT METHODS (for saving & editing)
  List<TimeOfDay> getTimes() {
    final list = <TimeOfDay>[];
    if (morning != null) list.add(morning!);
    if (afternoon != null) list.add(afternoon!);
    if (night != null) list.add(night!);
    return list;
  }

  void setTimes(List<TimeOfDay> times) {
    if (times.isNotEmpty) morning = times[0];
    if (times.length > 1) afternoon = times[1];
    if (times.length > 2) night = times[2];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB2DFDB)),
      ),
      child: Column(
        children: [
          _row(
            icon: Icons.wb_sunny_outlined,
            label: "Morning",
            time: morning,
            onTap: () => pick((t) => setState(() => morning = t)),
          ),
          _divider(),
          _row(
            icon: Icons.wb_cloudy_outlined,
            label: "Afternoon",
            time: afternoon,
            onTap: () => pick((t) => setState(() => afternoon = t)),
          ),
          _divider(),
          _row(
            icon: Icons.nightlight_round,
            label: "Night",
            time: night,
            isDashed: true,
            onTap: () => pick((t) => setState(() => night = t)),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
    bool isDashed = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0E7C6B)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: time != null && !isDashed
                    ? const Color(0xFFDCEFEA)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isDashed
                    ? Border.all(color: const Color(0xFF0E7C6B))
                    : null,
              ),
              child: Text(
                format(time),
                style: const TextStyle(
                  color: Color(0xFF0E7C6B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, color: Color(0xFFE0E0E0));
  }
}
/// 🔽 TEMP DROPDOWN (until moved to design system)
class AppDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final Function(String) onChanged;
  final IconData? icon;

  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (val) => onChanged(val!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class AppBox extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const AppBox({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}