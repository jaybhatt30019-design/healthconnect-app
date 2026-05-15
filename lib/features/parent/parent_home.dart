import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/core/services/appointment_service.dart';
import 'package:healthconnect/utils/date_time_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParentHome extends StatefulWidget {
  final Map<String, dynamic>? parentData;

  const ParentHome({super.key, this.parentData});

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  final _appointmentService = AppointmentService();

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  String caregiverName = "Loading...";
bool isLoadingCaregiver = true;

Future<void> loadCaregiverData() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    final parentQuery = await FirebaseFirestore.instance
        .collection('parents')
        .where('phone', isEqualTo: currentUser.phoneNumber)
        .limit(1)
        .get();

    if (parentQuery.docs.isEmpty) {
      setState(() {
        caregiverName = 'No Caregiver Connected';
        isLoadingCaregiver = false;
      });
      return;
    }

    final parentData = parentQuery.docs.first.data();

    final caregiverId = parentData['caregiverId'];

    if (caregiverId == null) {
      setState(() {
        caregiverName = 'No Caregiver Connected';
        isLoadingCaregiver = false;
      });
      return;
    }

    final caregiverDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(caregiverId)
        .get();

    final caregiverData = caregiverDoc.data();

    setState(() {
      caregiverName = caregiverData?['name'] ?? 'Caregiver';
      isLoadingCaregiver = false;
    });
  } catch (e) {
    setState(() {
      caregiverName = 'Caregiver';
      isLoadingCaregiver = false;
    });
  }
}

@override
void initState() {
  super.initState();
  loadCaregiverData();
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

                  /// HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(getGreeting(), style: AppTextStyles.subtitle),
                          const SizedBox(height: 6),
                          Text("Parent",
                              style: AppTextStyles.heading
                                  .copyWith(color: AppColors.darkPrimary)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child:
                            Icon(Icons.notifications_none, color: AppColors.primary),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  /// PROFILE CARD
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
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
                            const SizedBox(width: AppSpacing.md),
                            Text(
  isLoadingCaregiver ? "Loading..." : caregiverName,
  style: AppTextStyles.heading
      .copyWith(color: AppColors.darkPrimary),
),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _actionBtn(Icons.videocam, "VIDEO SOS", true),
                            _actionBtn(Icons.call, "CALL HELP", false),
                            _actionBtn(
                                Icons.local_hospital, "EMERGENCY", false),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  

                  /// 💊 MEDICINES
                  Text("Today's Medications", style: AppTextStyles.heading),
                  const SizedBox(height: AppSpacing.md),


                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('medicines')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return Text("No medications scheduled yet.",
                            style: AppTextStyles.body);
                      }

                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          List<TimeOfDay> times =
                              (data['times'] as List? ?? []).map((t) {
                            final p = t.split(":");
                            return TimeOfDay(
                                hour: int.parse(p[0]),
                                minute: int.parse(p[1]));
                          }).toList();

                          List<bool> takenStatus = List<bool>.from(
                              data['takenStatus'] ??
                                  List.filled(times.length, false));
                          if (takenStatus.length < times.length) {
                            takenStatus = List.filled(times.length, false);
                          }

                          final med = Medicine(
                              id: doc.id,
                              name: data['name'],
                              dosage: data['dosage'],
                              times: times,
                              takenStatus: takenStatus);

                          return Column(
                            children: List.generate(times.length, (i) {
                              return _medicineCard(med, times[i], i);
                            }),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  /// 📅 APPOINTMENTS
                  Text("Upcoming Doctor Visit", style: AppTextStyles.heading),
                  const SizedBox(height: AppSpacing.md),

                  StreamBuilder<List<Appointment>>(
                    stream: _appointmentService.getAppointments(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final all = snapshot.data ?? [];
                      final upcoming = all
                          .where((a) => a.dateTime.isAfter(DateTime.now()))
                          .toList();

                      if (upcoming.isEmpty) {
                        return Text("No upcoming appointments.",
                            style: AppTextStyles.body);
                      }

                      return Column(
                        children: upcoming.map((appt) {
                          return Container(
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              boxShadow: [AppShadows.light],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                      color: AppColors.iconBg,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.local_hospital,
                                      color: AppColors.primary),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(appt.doctorName,
                                          style: AppTextStyles.body),
                                      Text(appt.hospitalName,
                                          style: AppTextStyles.small),
                                      if (appt.reason.isNotEmpty)
                                        Text(appt.reason,
                                            style: AppTextStyles.small),
                                    ],
                                  ),
                                ),
                                Text(
                                  DateTimeHelper.format(appt.dateTime),
                                  style: AppTextStyles.small.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600),
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

  Widget _actionBtn(IconData icon, String label, bool isPrimary) {
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
              color: isPrimary ? Colors.white : AppColors.primary,
              size: 28),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: AppTextStyles.body.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _medicineCard(Medicine med, TimeOfDay time, int index) {
    final now = TimeOfDay.now();
    final isTimePassed = (time.hour < now.hour) ||
        (time.hour == now.hour && time.minute <= now.minute);
    final isTaken = med.takenStatus[index];

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
            const Icon(Icons.medication, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(med.name, style: AppTextStyles.body),
                  Text("${med.dosage} • ${time.format(context)}",
                      style: AppTextStyles.small),
                ],
              ),
            ),
            if (isTimePassed && !isTaken)
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      med.takenStatus[index] = true;
                      await FirebaseFirestore.instance
                          .collection('medicines')
                          .doc(med.id)
                          .update({"takenStatus": med.takenStatus});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text("Taken",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.iconBg,
                      borderRadius: BorderRadius.circular(20),
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