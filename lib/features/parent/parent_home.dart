// lib/features/parent/parent_home.dart
// Fix #15 — medicines now scoped by caregiverId via MedicineService
// Fix #2  — no print()
// Taken button now calls MedicineService.markTaken()
//           which cancels follow-up reminders

import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/core/services/appointment_service.dart';
import 'package:healthconnect/core/services/medicine_service.dart';
import 'package:healthconnect/utils/date_time_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthconnect/widgets/notification_badge.dart';

class ParentHome extends StatefulWidget {
  final Map<String, dynamic>? parentData;
  const ParentHome({super.key, this.parentData});

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  final _medicineService = MedicineService();
  final _appointmentService = AppointmentService();

  late final Stream<List<Medicine>> _medicineStream;
  late final Stream<List<Appointment>> _appointmentStream;

  String caregiverName = "Caregiver";
  bool _isLoadingCaregiver = true;

  @override
  void initState() {
    super.initState();
    _medicineStream = _medicineService.getMedicines();
    _appointmentStream = _appointmentService.getAppointments();
    _loadCaregiverName();
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good Morning";
    if (h < 17) return "Good Afternoon";
    return "Good Evening";
  }

  Future<void> _loadCaregiverName() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final caregiverId =
          userDoc.data()?['caregiverId'] as String?;

      if (caregiverId == null || caregiverId.isEmpty) {
        if (mounted) {
          setState(() {
            caregiverName = "No Caregiver Connected";
            _isLoadingCaregiver = false;
          });
        }
        return;
      }

      final caregiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverId)
          .get();

      if (mounted) {
        setState(() {
          caregiverName =
              caregiverDoc.data()?['name'] as String? ??
                  'Caregiver';
          _isLoadingCaregiver = false;
        });
      }
    } catch (e) {
      debugPrint('[ParentHome] Caregiver load: $e');
      if (mounted) {
        setState(() {
          caregiverName = "Caregiver";
          _isLoadingCaregiver = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(_getGreeting(),
                              style: AppTextStyles.subtitle),
                          const SizedBox(height: 6),
                          Text("Parent",
                              style: AppTextStyles.heading
                                  .copyWith(
                                      color:
                                          AppColors.darkPrimary)),
                        ],
                      ),
                      const NotificationBadge(),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(
                                  "https://i.pravatar.cc/150?img=3"),
                            ),
                            const SizedBox(
                                width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                _isLoadingCaregiver
                                    ? "Loading..."
                                    : caregiverName,
                                style: AppTextStyles.heading
                                    .copyWith(
                                        color: AppColors
                                            .darkPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                            height: AppSpacing.xl),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _actionBtn(Icons.videocam,
                                "VIDEO SOS", true),
                            _actionBtn(
                                Icons.call, "CALL HELP", false),
                            _actionBtn(Icons.local_hospital,
                                "EMERGENCY", false),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Text("Today's Medications",
                      style: AppTextStyles.heading),
                  const SizedBox(height: AppSpacing.md),

                  StreamBuilder<List<Medicine>>(
                    stream: _medicineStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child:
                                CircularProgressIndicator());
                      }
                      final medicines = snapshot.data ?? [];
                      if (medicines.isEmpty) {
                        return Text(
                            "No medications scheduled yet.",
                            style: AppTextStyles.body);
                      }
                      return Column(
                        children: medicines.expand((med) {
                          return List.generate(
                              med.times.length,
                              (i) => _medicineCard(
                                  med, med.times[i], i));
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Text("Upcoming Doctor Visit",
                      style: AppTextStyles.heading),
                  const SizedBox(height: AppSpacing.md),

                  StreamBuilder<List<Appointment>>(
                    stream: _appointmentStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child:
                                CircularProgressIndicator());
                      }
                      final all = snapshot.data ?? [];
                      final upcoming = all
                          .where((a) => a.dateTime
                              .isAfter(DateTime.now()))
                          .toList();
                      if (upcoming.isEmpty) {
                        return Text(
                            "No upcoming appointments.",
                            style: AppTextStyles.body);
                      }
                      return Column(
                        children: upcoming.map((appt) {
                          return Container(
                            margin: const EdgeInsets.only(
                                bottom: AppSpacing.sm),
                            padding: const EdgeInsets.all(
                                AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius:
                                  BorderRadius.circular(
                                      AppRadius.md),
                              boxShadow: [AppShadows.light],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: AppColors.iconBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.local_hospital,
                                      color: AppColors.primary),
                                ),
                                const SizedBox(
                                    width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(appt.doctorName,
                                          style: AppTextStyles
                                              .body),
                                      Text(appt.hospitalName,
                                          style: AppTextStyles
                                              .small),
                                      if (appt.reason
                                          .isNotEmpty)
                                        Text(appt.reason,
                                            style: AppTextStyles
                                                .small),
                                    ],
                                  ),
                                ),
                                Text(
                                  DateTimeHelper.format(
                                      appt.dateTime),
                                  style: AppTextStyles.small
                                      .copyWith(
                                    color: AppColors.primary,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, String label, bool isPrimary) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.darkPrimary
                : AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              color: isPrimary
                  ? Colors.white
                  : AppColors.primary,
              size: 28),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: AppTextStyles.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _medicineCard(
      Medicine med, TimeOfDay time, int index) {
    final now = TimeOfDay.now();
    final isTimePassed = (time.hour < now.hour) ||
        (time.hour == now.hour &&
            time.minute <= now.minute);
    final isTaken = index < med.takenStatus.length
        ? med.takenStatus[index]
        : false;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isTaken ? 0.4 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.medication,
                color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(med.name, style: AppTextStyles.body),
                  Text(
                      "${med.dosage} • ${time.format(context)}",
                      style: AppTextStyles.small),
                ],
              ),
            ),
            if (isTimePassed && !isTaken)
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      try {
                        await _medicineService.markTaken(
                            med, index);
                      } catch (e) {
                        debugPrint(
                            '[ParentHome] markTaken: $e');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: const Text("Taken",
                          style: TextStyle(
                              color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.iconBg,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: const Text("Remind"),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}