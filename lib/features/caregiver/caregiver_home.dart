// lib/features/caregiver/caregiver_home.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/core/services/appointment_service.dart';
import 'package:healthconnect/core/services/medicine_service.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/utils/date_time_helper.dart';
import 'package:healthconnect/features/dashboard/add_appointment_screen.dart';
import 'package:healthconnect/features/caregiver/location_map_widget.dart';
import 'package:healthconnect/widgets/notification_badge.dart';
import 'package:healthconnect/features/emergency/calling_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class CaregiverHome extends StatefulWidget {
  final VoidCallback? onAppointmentTap; // add this
  const CaregiverHome({super.key, this.onAppointmentTap});

  @override
  State<CaregiverHome> createState() =>
      _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome> {
  late final Stream<List<Medicine>> _medicineStream;
  late final Stream<List<Appointment>>
      _appointmentStream;

  final _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _isCalling = false;

  @override
  void initState() {
    super.initState();
    _medicineStream = MedicineService().getMedicines();
    _appointmentStream =
        AppointmentService().getAppointments();
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good Morning";
    if (h < 17) return "Good Afternoon";
    return "Good Evening";
  }

  // ── Call Help — initiates emergency call ──────────────
  Future<void> _onCallHelp(
      String caregiverName) async {
    if (_isCalling) return;
    setState(() => _isCalling = true);

    try {
      final callId = await EmergencyService()
          .initiateChildEmergency(
        callerName: caregiverName,
      );

      if (callId != null && mounted) {
        Navigator.of(context, rootNavigator: true)
            .push(
          MaterialPageRoute(
            builder: (_) => CallingScreen(
              callId: callId,
              isChild: true,
              callerName: caregiverName,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No parent connected. Connect a parent first.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalling = false);
    }
  }

  // ── Dial 108 emergency ────────────────────────────────
  Future<void> _dial108() async {
    final uri = Uri.parse('tel:108');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: StreamBuilder<DocumentSnapshot>(
            // ✅ Real-time caregiver name from Firestore
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_uid)
                .snapshots(),
            builder: (context, userSnap) {
              final userData = userSnap.hasData &&
                      userSnap.data!.exists
                  ? userSnap.data!.data()
                      as Map<String, dynamic>
                  : <String, dynamic>{};

              final caregiverName =
                  userData['name'] as String? ??
                      'Caregiver';
              final photoUrl =
                  userData['photoUrl'] as String?;

              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  // ── Header ──────────────────────
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(_getGreeting(),
                              style:
                                  AppTextStyles.small),
                          const SizedBox(height: 4),
                          // ✅ Real name
                          Text(
                            caregiverName,
                            style:
                                AppTextStyles.heading,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const NotificationBadge(),
                          const SizedBox(width: 8),
                          // ✅ Profile photo
                          _profileAvatar(
                              photoUrl, caregiverName,
                              radius: 22),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: AppSpacing.xl),

                  // ── Parent card ──────────────────
                  _parentCard(caregiverName),

                  const SizedBox(
                      height: AppSpacing.xl),

                  Text("Health Summary",
                      style: AppTextStyles.heading),
                  const SizedBox(
                      height: AppSpacing.md),

                  // ── Medicine summary ─────────────
                  StreamBuilder<List<Medicine>>(
                    stream: _medicineStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child:
                                CircularProgressIndicator());
                      }
                      final medicines =
                          snapshot.data ?? [];
                      if (medicines.isEmpty) {
                        return _emptyCard(
                            Icons.medication_outlined,
                            "No medicines added");
                      }
                      return Column(children: [
                        _todayMedicationCard(medicines),
                        const SizedBox(height: 10),
                        _missedDoseCard(medicines),
                      ]);
                    },
                  ),

                  const SizedBox(
                      height: AppSpacing.xl),

                  Text("Upcoming Appointments",
                      style: AppTextStyles.heading),
                  const SizedBox(
                      height: AppSpacing.md),

                  // ── Appointments ─────────────────
                  StreamBuilder<List<Appointment>>(
                    stream: _appointmentStream,
                    builder: (context, snapshot) {
                      final upcoming =
                          (snapshot.data ?? [])
                              .where((a) => a.dateTime
                                  .isAfter(
                                      DateTime.now()))
                              .take(3)
                              .toList();
                      if (upcoming.isEmpty) {
                        return _emptyCard(
                            Icons
                                .calendar_today_outlined,
                            "No upcoming appointments");
                      }
                      return Column(
                        children: upcoming
                            .map((a) =>
                                _appointmentCard(
                                    context, a))
                            .toList(),
                      );
                    },
                  ),

                  const SizedBox(
                      height: AppSpacing.xl),

                  const LocationMapWidget(),

                  const SizedBox(
                      height: AppSpacing.xl),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Parent card with Call Help + Emergency ────────────
  Widget _parentCard(String caregiverName) {
    return StreamBuilder<QuerySnapshot>(
      // Find the linked parent
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('caregiverId', isEqualTo: _uid)
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        String parentName = 'No Parent Connected';
        String? parentPhotoUrl;
        bool isConnected = false;

        if (snap.hasData &&
            snap.data!.docs.isNotEmpty) {
          final data = snap.data!.docs.first.data()
              as Map<String, dynamic>;
          parentName =
              data['name'] as String? ?? 'Parent';
          parentPhotoUrl =
              data['photoUrl'] as String?;
          isConnected = true;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius:
                BorderRadius.circular(AppRadius.md),
            boxShadow: [AppShadows.light],
          ),
          child: Column(
            children: [
              // Parent info row
              Row(
                children: [
                  _profileAvatar(
                      parentPhotoUrl, parentName,
                      radius: 28),
                  const SizedBox(
                      width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(parentName,
                            style: AppTextStyles.body
                                .copyWith(
                                    fontWeight:
                                        FontWeight
                                            .w700)),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isConnected
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isConnected
                                  ? 'Connected'
                                  : 'Not connected',
                              style: AppTextStyles
                                  .small
                                  .copyWith(
                                color: isConnected
                                    ? Colors
                                        .green.shade700
                                    : AppColors.hint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Action buttons row
              Row(
                children: [
                  // CALL HELP
                  Expanded(
                    child: GestureDetector(
                      onTap: isConnected && !_isCalling
                          ? () =>
                              _onCallHelp(caregiverName)
                          : null,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: isConnected
                              ? AppColors.primary
                              : Colors.grey.shade300,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            _isCalling
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                      color:
                                          Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.call,
                                    color: Colors.white,
                                    size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _isCalling
                                  ? "Calling..."
                                  : "Call Help",
                              style: TextStyle(
                                color: isConnected
                                    ? Colors.white
                                    : Colors.grey
                                        .shade600,
                                fontWeight:
                                    FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // EMERGENCY 108
                  Expanded(
                    child: GestureDetector(
                      onTap: _dial108,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_hospital,
                                color: Colors.white,
                                size: 18),
                            SizedBox(width: 6),
                            Text(
                              "Emergency 108",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Profile avatar with initials fallback ─────────────
  Widget _profileAvatar(
      String? photoUrl, String name,
      {double radius = 28}) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: AppColors.iconBg,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _emptyCard(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.hint),
        const SizedBox(width: 12),
        Text(text, style: AppTextStyles.small),
      ]),
    );
  }

Widget _appointmentCard(
    BuildContext context, Appointment appt) {
  return GestureDetector(
    onTap: () => widget.onAppointmentTap?.call(), // switch tab
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
            decoration: const BoxDecoration(
                color: AppColors.iconBg,
                shape: BoxShape.circle),
            child: const Icon(Icons.local_hospital,
                color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appt.doctorName,
                    style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(appt.hospitalName,
                    style: AppTextStyles.small),
                const SizedBox(height: 4),
                Text(
                  DateTimeHelper.format(appt.dateTime),
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppColors.primary, size: 18),
        ],
      ),
    ),
  );
}

  Widget _todayMedicationCard(
      List<Medicine> medicines) {
    int total = 0, taken = 0;
    for (final med in medicines) {
      total += med.takenStatus.length;
      taken += med.takenStatus.where((e) => e).length;
    }
    final progress =
        total == 0 ? 0.0 : taken / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Medication",
              style: AppTextStyles.body),
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
    for (final med in medicines) {
      for (int i = 0; i < med.times.length; i++) {
        final t = med.times[i];
        final isPassed = (t.hour < now.hour) ||
            (t.hour == now.hour &&
                t.minute < now.minute);
        if (isPassed && !med.takenStatus[i]) {
          missed = med.name;
          break;
        }
      }
      if (missed != null) break;
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
          const Icon(Icons.warning_amber_rounded,
              color: Colors.red),
          const SizedBox(width: 8),
          Text("Missed dose: $missed",
              style: AppTextStyles.small
                  .copyWith(color: Colors.red)),
        ],
      ),
    );
  }
}