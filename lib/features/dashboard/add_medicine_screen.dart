// lib/features/dashboard/add_medicine_screen.dart

import 'package:flutter/material.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/core/services/medicine_service.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? existingMedicine;
  final String? docId;
  final VoidCallback? onDone;

  const AddMedicineScreen({
    super.key,
    this.existingMedicine,
    this.docId,
    this.onDone,
  });

  @override
  State<AddMedicineScreen> createState() =>
      _AddMedicineScreenState();
}

class _AddMedicineScreenState
    extends State<AddMedicineScreen> {
  final _service = MedicineService();

  final name = TextEditingController();
  final disease = TextEditingController();
  final dosage = TextEditingController();
  final doctor = TextEditingController();
  final notes = TextEditingController();
  final _stockCountCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();

  String intake = 'Before Food';

  // 0 = Ongoing, 1-31 = custom days
  int _durationDays = 0;

  DateTime selectedDate = DateTime.now();
  String _stockUnit = 'tablets';

  final GlobalKey<_TimingCardState> timingKey =
      GlobalKey();
  bool _isSaving = false;

  static const _units = [
    'tablets',
    'capsules',
    'ml',
    'drops',
    'sachets',
    'puffs',
    'patches',
    'units',
  ];

  static final _durationOptions = [
    'Ongoing',
    ...List.generate(31, (i) {
      final d = i + 1;
      return d == 1 ? '1 Day' : '$d Days';
    }),
  ];

  String get _durationValue {
    if (_durationDays == 0) return 'Ongoing';
    return _durationDays == 1
        ? '1 Day'
        : '$_durationDays Days';
  }

  String get _effectiveDuration {
    if (_durationDays == 0) return 'Ongoing';
    return _durationDays == 1
        ? '1 Day'
        : '$_durationDays Days';
  }

  DateTime? get _endDate {
    if (_durationDays == 0) return null;
    return selectedDate
        .add(Duration(days: _durationDays));
  }

  @override
  void initState() {
    super.initState();

    if (widget.existingMedicine != null) {
      final med = widget.existingMedicine!;
      name.text = med.name;
      disease.text = med.disease ?? '';
      dosage.text = med.dosage;
      doctor.text = med.doctor ?? '';
      notes.text = med.notes ?? '';
      intake = med.intake ?? 'Before Food';
      selectedDate = med.startDate ?? DateTime.now();
      _stockCountCtrl.text = med.stockCount > 0
          ? med.stockCount.toString()
          : '';
      _thresholdCtrl.text =
          med.lowStockThreshold.toString();
      _stockUnit = med.stockUnit;

      final saved = med.duration ?? 'Ongoing';
      if (saved == 'Ongoing') {
        _durationDays = 0;
      } else {
        final n = int.tryParse(
            saved.replaceAll(RegExp(r'[^0-9]'), ''));
        _durationDays =
            (n != null && n >= 1 && n <= 31) ? n : 0;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ✅ Restore using slots so each time lands
        // in its correct row
        timingKey.currentState
            ?.setFromSlots(med.times, med.slots);
      });
    } else {
      _thresholdCtrl.text = '5';
    }
  }

  @override
  void dispose() {
    name.dispose();
    disease.dispose();
    dosage.dispose();
    doctor.dispose();
    notes.dispose();
    _stockCountCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _circleBack(context),
                  const Spacer(),
                  Text(
                    isEdit
                        ? 'Edit Medication'
                        : 'Add Medication',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),

              const SizedBox(height: 20),

              _label('Medication Name'),
              AppInputField(
                controller: name,
                hint: 'e.g., Aspirin',
                icon: Icons.medication,
              ),

              _label('Disease / Condition'),
              AppInputField(
                controller: disease,
                hint: 'e.g., Hypertension',
                icon: Icons.monitor_heart,
              ),

              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _label('Dosage'),
                      AppInputField(
                        controller: dosage,
                        hint: 'e.g., 500mg',
                        icon: Icons.scale,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _label('Intake Time'),
                      AppDropdown(
                        value: intake,
                        items: const [
                          'Before Food',
                          'After Food',
                        ],
                        onChanged: (val) =>
                            setState(() => intake = val),
                      ),
                    ],
                  ),
                ),
              ]),

              _label('Exact Timing'),
              TimingCard(key: timingKey),

              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _label('Start Date'),
                      AppBox(
                        text:
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        icon: Icons.calendar_today,
                        onTap: () async {
                          final picked =
                              await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() =>
                                selectedDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _label('Duration'),
                      _durationDropdown(),
                    ],
                  ),
                ),
              ]),

              if (_endDate != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            const Color(0xFF0E7C6B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                          Icons.event_available,
                          color: Color(0xFF0E7C6B),
                          size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reminders stop after: '
                          '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF004D40),
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              _label('Prescribed By (Optional)'),
              AppInputField(
                controller: doctor,
                hint: 'e.g., Dr. Smith',
                icon: Icons.person,
              ),

              _label('Special Instructions'),
              AppInputField(
                controller: notes,
                hint: 'Take with food...',
                icon: Icons.description,
                maxLines: 3,
              ),

              const SizedBox(height: 20),
              _sectionDivider('Stock & Restock'),

              _label('Medicine Unit'),
              _unitSelector(),

              const SizedBox(height: 14),

              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _label('Current Stock'),
                      _stockField(
                          _stockCountCtrl, 'e.g. 30'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _label('Notify When Below'),
                      _stockField(
                          _thresholdCtrl, 'e.g. 7'),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.info_outline,
                    size: 14,
                    color: Color(0xFF78909C)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Both parent and caregiver notified when stock reaches threshold',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500),
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF0E7C6B),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(30),
                    ),
                  ),
                  onPressed:
                      _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEdit
                              ? 'Update Medication'
                              : 'Save Medication',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16),
                        ),
                ),
              ),

              if (isEdit)
                Padding(
                  padding:
                      const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed:
                          _isSaving ? null : _delete,
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationDropdown() {
    return Container(
      height: 56,
      padding:
          const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFB2DFDB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _durationValue,
          isExpanded: true,
          icon: const Icon(
            Icons.hourglass_bottom,
            color: Color(0xFF0E7C6B),
            size: 20,
          ),
          items: _durationOptions.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 14,
                  color: option == 'Ongoing'
                      ? const Color(0xFF004D40)
                      : const Color(0xFF374151),
                  fontWeight: option == 'Ongoing'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              if (val == 'Ongoing') {
                _durationDays = 0;
              } else {
                final n = int.tryParse(
                  val.replaceAll(
                      RegExp(r'[^0-9]'), ''),
                );
                _durationDays = n ?? 0;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _stockField(
      TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        suffixText: _stockUnit,
        suffixStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
              color: Color(0xFFB2DFDB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
              color: Color(0xFFB2DFDB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF0E7C6B),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _unitSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _units.map((unit) {
        final selected = _stockUnit == unit;
        return GestureDetector(
          onTap: () =>
              setState(() => _stockUnit = unit),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF0E7C6B)
                  : Colors.white,
              borderRadius:
                  BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0E7C6B)
                    : const Color(0xFFB2DFDB),
              ),
            ),
            child: Text(
              unit,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : const Color(0xFF004D40),
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionDivider(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              color: Color(0xFF0E7C6B), size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF004D40),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Divider(
                color: Color(0xFFB2DFDB)),
          ),
        ],
      ),
    );
  }

  // ── Save ──────────────────────────────────────────
  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      _snack('Please enter medication name');
      return;
    }

    final stockCount =
        int.tryParse(_stockCountCtrl.text.trim()) ??
            0;
    final threshold =
        int.tryParse(_thresholdCtrl.text.trim()) ??
            5;

    if (stockCount <= 0) {
      _snack('Please enter current stock quantity');
      return;
    }

    // ✅ Get times WITH their slot labels
    final picked =
        timingKey.currentState?.getTimesWithSlots() ??
            [];

    if (picked.isEmpty) {
      _snack('Please set at least one reminder time');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final times =
          picked.map((e) => e.time).toList();
      final slots =
          picked.map((e) => e.slot).toList();

      final med = Medicine(
        id: widget.docId ?? '',
        name: name.text.trim(),
        dosage: dosage.text.trim(),
        disease: disease.text.trim(),
        intake: intake,
        duration: _effectiveDuration,
        doctor: doctor.text.trim(),
        notes: notes.text.trim(),
        startDate: selectedDate,
        endDate: _endDate,
        times: times,
        slots: slots,
        takenStatus:
            widget.existingMedicine?.takenStatus,
        stockCount: stockCount,
        lowStockThreshold: threshold,
        stockUnit: _stockUnit,
        lastRestockedAt:
            widget.existingMedicine?.lastRestockedAt,
      );

      if (widget.docId != null) {
        await _service.updateMedicine(med);
      } else {
        await _service.addMedicine(med);
      }

      if (!mounted) return;
      widget.onDone?.call();
      Navigator.pop(context);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _isSaving = true);
    try {
      if (widget.docId != null) {
        await _service.deleteMedicine(widget.docId!);
      }
      if (!mounted) return;
      widget.onDone?.call();
      Navigator.pop(context);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _circleBack(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
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
      padding:
          const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w600)),
    );
  }
}

// ═══════════════════════════════════════════════════
// Small holder for a time + its slot label
// ═══════════════════════════════════════════════════
class SlotTime {
  final TimeOfDay time;
  final String slot;
  const SlotTime(this.time, this.slot);
}

// ═══════════════════════════════════════════════════
// TIMING CARD
// ═══════════════════════════════════════════════════

class TimingCard extends StatefulWidget {
  const TimingCard({super.key});

  @override
  State<TimingCard> createState() => _TimingCardState();
}

class _TimingCardState extends State<TimingCard> {
  TimeOfDay? morning;
  TimeOfDay? afternoon;
  TimeOfDay? night;

  String _format(TimeOfDay? t) {
    if (t == null) return 'Set Time';
    final h =
        t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p =
        t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  Future<void> _pick(TimeOfDay? current,
      Function(TimeOfDay) onPicked) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
    );
    if (picked != null) onPicked(picked);
  }

  // ✅ Returns each set time WITH its slot label,
  // in fixed order Morning → Afternoon → Night.
  // Empty slots are skipped but labels are preserved.
  List<SlotTime> getTimesWithSlots() {
    final list = <SlotTime>[];
    if (morning != null) {
      list.add(SlotTime(morning!, 'Morning'));
    }
    if (afternoon != null) {
      list.add(SlotTime(afternoon!, 'Afternoon'));
    }
    if (night != null) {
      list.add(SlotTime(night!, 'Night'));
    }
    return list;
  }

  // ✅ Restore using slot labels so each time goes to
  // its correct row regardless of how many were set.
  void setFromSlots(
      List<TimeOfDay> times, List<String> slots) {
    setState(() {
      morning = null;
      afternoon = null;
      night = null;
      for (int i = 0; i < times.length; i++) {
        final slot = i < slots.length
            ? slots[i]
            : 'Morning';
        switch (slot) {
          case 'Afternoon':
            afternoon = times[i];
            break;
          case 'Night':
            night = times[i];
            break;
          case 'Morning':
          default:
            morning = times[i];
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFB2DFDB)),
      ),
      child: Column(
        children: [
          _row(
            icon: Icons.wb_sunny_outlined,
            label: 'Morning',
            time: morning,
            onTap: () => _pick(morning,
                (t) => setState(() => morning = t)),
            onClear: morning != null
                ? () =>
                    setState(() => morning = null)
                : null,
          ),
          _divider(),
          _row(
            icon: Icons.wb_cloudy_outlined,
            label: 'Afternoon',
            time: afternoon,
            onTap: () => _pick(
                afternoon,
                (t) =>
                    setState(() => afternoon = t)),
            onClear: afternoon != null
                ? () => setState(
                    () => afternoon = null)
                : null,
          ),
          _divider(),
          _row(
            icon: Icons.nightlight_round,
            label: 'Night',
            time: night,
            onTap: () => _pick(night,
                (t) => setState(() => night = t)),
            onClear: night != null
                ? () => setState(() => night = null)
                : null,
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
    VoidCallback? onClear,
  }) {
    final isSet = time != null;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon,
              color: isSet
                  ? const Color(0xFF0E7C6B)
                  : Colors.grey.shade400),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isSet
                  ? const Color(0xFF004D40)
                  : Colors.grey.shade500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSet
                    ? const Color(0xFFDCEFEA)
                    : Colors.grey.shade100,
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                  color: isSet
                      ? const Color(0xFF0E7C6B)
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                _format(time),
                style: TextStyle(
                  color: isSet
                      ? const Color(0xFF0E7C6B)
                      : Colors.grey.shade500,
                  fontWeight: isSet
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClear,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.red.shade200),
                ),
                child: Icon(Icons.close,
                    size: 16,
                    color: Colors.red.shade400),
              ),
            ),
          ] else
            const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
      height: 1, color: Color(0xFFE0E0E0));
}

// ═══════════════════════════════════════════════════
// APP DROPDOWN
// ═══════════════════════════════════════════════════

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
      padding:
          const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon,
                color: AppColors.primary, size: 20),
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
                        child: Text(e)))
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

// ═══════════════════════════════════════════════════
// APP BOX
// ═══════════════════════════════════════════════════

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
        padding: const EdgeInsets.symmetric(
            horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius:
              BorderRadius.circular(AppRadius.sm),
          border:
              Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}