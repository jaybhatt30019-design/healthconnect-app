// lib/features/caregiver/caregiver_home.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/core/services/appointment_service.dart';
import 'package:healthconnect/utils/date_time_helper.dart';
import 'package:healthconnect/features/dashboard/add_appointment_screen.dart';
import 'package:healthconnect/features/caregiver/location_map_widget.dart';
import 'package:healthconnect/widgets/notification_badge.dart';

class CaregiverHome extends StatefulWidget {
  const CaregiverHome({super.key});

  @override
  State<CaregiverHome> createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome> {
  late final Stream<List<Appointment>> _appointmentStream;

  @override
  void initState() {
    super.initState();
    _appointmentStream = AppointmentService().getAppointments();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(getGreeting(), style: AppTextStyles.small),
                      const SizedBox(height: 4),
                      Text("Caregiver", style: AppTextStyles.heading),
                    ],
                  ),
                  const NotificationBadge(),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Patient card ─────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [AppShadows.light],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person,
                              size: 30, color: AppColors.primary),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text("Parent", style: AppTextStyles.body),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _actionBtn(
                            icon: Icons.videocam,
                            label: "VIDEO SOS",
                            isPrimary: true,
                            onTap: () {}),
                        _actionBtn(
                            icon: Icons.phone_android,
                            label: "CALL HELP",
                            isPrimary: false,
                            onTap: () {}),
                        _actionBtn(
                            icon: Icons.local_hospital,
                            label: "EMERGENCY",
                            isPrimary: false,
                            onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Health summary ───────────────────────
              Text("Health Summary", style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.md),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('medicines')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                        child: Text("No medicines",
                            style: AppTextStyles.body));
                  }

                  List<Medicine> medicines = docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    List<TimeOfDay> times =
                        (data['times'] as List? ?? []).map((t) {
                      final parts = t.split(":");
                      return TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1]));
                    }).toList();
                    List<bool> takenStatus =
                        List<bool>.from(data['takenStatus'] ?? []);
                    if (takenStatus.length < times.length) {
                      takenStatus = List.filled(times.length, false);
                    }
                    return Medicine(
                        id: doc.id,
                        name: data['name'] ?? "",
                        dosage: data['dosage'] ?? "",
                        times: times,
                        takenStatus: takenStatus);
                  }).toList();

                  return Column(
                    children: [
                      _todayMedicationCard(medicines),
                      const SizedBox(height: 10),
                      _missedDoseCard(medicines),
                    ],
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Upcoming appointments ────────────────
              // ✅ REMOVED: Add button — title only now
              Text("Upcoming Appointments", style: AppTextStyles.heading),

              const SizedBox(height: AppSpacing.md),

              StreamBuilder<List<Appointment>>(
                stream: _appointmentStream,
                builder: (context, snapshot) {
                  final all = snapshot.data ?? [];
                  final upcoming = all
                      .where((a) => a.dateTime.isAfter(DateTime.now()))
                      .take(3)
                      .toList();

                  if (upcoming.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              color: AppColors.hint),
                          const SizedBox(width: 12),
                          Text("No upcoming appointments",
                              style: AppTextStyles.small),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: upcoming
                        .map((appt) => _appointmentCard(context, appt))
                        .toList(),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── 🗺️ Parent's live location ────────────
              // ✅ MOVED: Location section now last
              const LocationMapWidget(),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appointmentCard(BuildContext context, Appointment appt) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                AddAppointmentScreen(existingAppointment: appt)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.light],
          border: Border.all(color: AppColors.primary, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                  color: AppColors.iconBg, shape: BoxShape.circle),
              child: const Icon(Icons.local_hospital,
                  color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appt.doctorName,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(appt.hospitalName,
                      style: AppTextStyles.small),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateTimeHelper.format(appt.dateTime),
                  style: AppTextStyles.small.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.primary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: isPrimary
                    ? AppColors.darkPrimary
                    : AppColors.iconBg,
                shape: BoxShape.circle,
                boxShadow: [AppShadows.light],
              ),
              child: Icon(icon,
                  color: isPrimary
                      ? Colors.white
                      : AppColors.darkPrimary,
                  size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: AppTextStyles.small.copyWith(
                  color: AppColors.darkPrimary,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _todayMedicationCard(List<Medicine> medicines) {
    int total = 0, taken = 0;
    for (var med in medicines) {
      total += med.takenStatus.length;
      taken += med.takenStatus.where((e) => e).length;
    }
    double progress = total == 0 ? 0 : taken / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Medication", style: AppTextStyles.body),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.iconBg,
            valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text("$taken / $total taken",
              style: AppTextStyles.small),
        ],
      ),
    );
  }

  Widget _missedDoseCard(List<Medicine> medicines) {
    final now = TimeOfDay.now();
    String? missed;
    for (var med in medicines) {
      for (int i = 0; i < med.times.length; i++) {
        final t = med.times[i];
        final isPassed = (t.hour < now.hour) ||
            (t.hour == now.hour && t.minute < now.minute);
        if (isPassed && !med.takenStatus[i]) {
          missed = med.name;
          break;
        }
      }
    }
    if (missed == null) return const SizedBox();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Text("Missed dose: $missed",
              style: AppTextStyles.small
                  .copyWith(color: Colors.red)),
        ],
      ),
    );
  }
}