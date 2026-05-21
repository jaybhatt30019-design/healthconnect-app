// lib/features/parent/parent_home.dart

import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/core/services/appointment_service.dart';
import 'package:healthconnect/core/services/medicine_service.dart';
import 'package:healthconnect/core/services/notification_service.dart';
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

  // ✅ FIX #3 — remind state stored in Firestore
  // Key: "medicineId:slotIndex"
  // Survives tab switches and screen rebuilds
  final Map<String, DateTime> _remindPending = {};

  @override
  void initState() {
    super.initState();
    _medicineStream = _medicineService.getMedicines();
    _appointmentStream =
        _appointmentService.getAppointments();
    _loadCaregiverName();
    _loadRemindStates();
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good Morning";
    if (h < 17) return "Good Afternoon";
    return "Good Evening";
  }

  Future<void> _loadCaregiverName() async {
    try {
      final uid =
          FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = userDoc.data() ?? {};
      final caregiverId =
          data['caregiverId'] as String?;
      if (caregiverId == null || caregiverId.isEmpty) {
        if (mounted) {
          setState(() {
            caregiverName = "No Caregiver Connected";
            _isLoadingCaregiver = false;
          });
        }
        return;
      }
      final caregiverDoc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(caregiverId)
          .get();
      if (mounted) {
        setState(() {
          caregiverName =
              caregiverDoc.data()?['name']
                      as String? ??
                  'Caregiver';
          _isLoadingCaregiver = false;
        });
      }
    } catch (e) {
      debugPrint('[ParentHome] Caregiver name: $e');
      if (mounted) {
        setState(() {
          caregiverName = "Caregiver";
          _isLoadingCaregiver = false;
        });
      }
    }
  }

  // ✅ FIX #3 — load remind states from Firestore
  // So state survives tab switches
  Future<void> _loadRemindStates() async {
    try {
      final uid =
          FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('remind_states')
          .doc(uid)
          .get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final now = DateTime.now();
      final Map<String, DateTime> active = {};
      data.forEach((key, value) {
        if (value is Timestamp) {
          final expiresAt = value.toDate();
          // Only keep if reminder hasn't expired yet
          if (expiresAt.isAfter(now)) {
            active[key] = expiresAt;
          }
        }
      });
      if (mounted && active.isNotEmpty) {
        setState(() =>
            _remindPending.addAll(active));
      }
    } catch (e) {
      debugPrint(
          '[ParentHome] Load remind states: $e');
    }
  }

  // ✅ FIX #3 — save remind state to Firestore
  Future<void> _saveRemindState(
      String key, DateTime expiresAt) async {
    try {
      final uid =
          FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('remind_states')
          .doc(uid)
          .set({
        key: Timestamp.fromDate(expiresAt),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
          '[ParentHome] Save remind state: $e');
    }
  }

  Future<void> _clearRemindState(String key) async {
    try {
      final uid =
          FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('remind_states')
          .doc(uid)
          .update({key: FieldValue.delete()});
    } catch (e) {
      debugPrint(
          '[ParentHome] Clear remind state: $e');
    }
  }

  Future<void> _onRemindTap(
      Medicine med, int index) async {
    final key = '${med.id}:$index';
    if (_remindPending.containsKey(key)) return;

    final expiresAt = DateTime.now()
        .add(const Duration(minutes: 15));

    setState(() => _remindPending[key] = expiresAt);

    // ✅ FIX #3 — persist to Firestore
    await _saveRemindState(key, expiresAt);

    try {
      await NotificationService().remindLater(
        medicineId: med.id,
        medicineName: med.name,
        dosage: med.dosage,
        slotIndex: index,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.alarm,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reminder set for ${med.name} in 15 minutes',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Auto-clear after 15 min
      Future.delayed(
        const Duration(minutes: 15),
        () async {
          if (mounted) {
            setState(
                () => _remindPending.remove(key));
          }
          await _clearRemindState(key);
        },
      );
    } catch (e) {
      debugPrint('[ParentHome] Remind error: $e');
      if (mounted) {
        setState(() => _remindPending.remove(key));
        await _clearRemindState(key);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not set reminder. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await _loadCaregiverName();
              await _loadRemindStates();
            },
            child: SingleChildScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                              style: AppTextStyles
                                  .subtitle),
                          const SizedBox(height: 6),
                          Text("Parent",
                              style: AppTextStyles
                                  .heading
                                  .copyWith(
                                color:
                                    AppColors.darkPrimary,
                              )),
                        ],
                      ),
                      const NotificationBadge(),
                    ],
                  ),

                  const SizedBox(
                      height: AppSpacing.xl),

                  Container(
                    padding: const EdgeInsets.all(
                        AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                              AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundImage:
                                  NetworkImage(
                                "https://i.pravatar.cc/150?img=3",
                              ),
                            ),
                            const SizedBox(
                                width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                _isLoadingCaregiver
                                    ? "Loading..."
                                    : caregiverName,
                                style: AppTextStyles
                                    .heading
                                    .copyWith(
                                  color: AppColors
                                      .darkPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                            height: AppSpacing.xl),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            _actionBtn(Icons.videocam,
                                "VIDEO SOS", true),
                            _actionBtn(Icons.call,
                                "CALL HELP", false),
                            _actionBtn(
                                Icons.local_hospital,
                                "EMERGENCY",
                                false),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                      height: AppSpacing.xl),

                  Text("Today's Medications",
                      style: AppTextStyles.heading),
                  const SizedBox(
                      height: AppSpacing.md),

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
                        return Text(
                          "No medications scheduled yet.",
                          style: AppTextStyles.body,
                        );
                      }
                      return Column(
                        children:
                            medicines.expand((med) {
                          return List.generate(
                            med.times.length,
                            (i) => _medicineCard(
                                med, med.times[i], i),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(
                      height: AppSpacing.xl),

                  Text("Upcoming Doctor Visit",
                      style: AppTextStyles.heading),
                  const SizedBox(
                      height: AppSpacing.md),

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
                          style: AppTextStyles.body,
                        );
                      }
                      return Column(
                        children: upcoming.map((appt) {
                          return Container(
                            margin: const EdgeInsets.only(
                                bottom: AppSpacing.sm),
                            padding:
                                const EdgeInsets.all(
                                    AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius:
                                  BorderRadius.circular(
                                      AppRadius.md),
                              boxShadow: [
                                AppShadows.light
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 45,
                                  height: 45,
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        AppColors.iconBg,
                                    shape:
                                        BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.local_hospital,
                                    color:
                                        AppColors.primary,
                                  ),
                                ),
                                const SizedBox(
                                    width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        appt.doctorName,
                                        style: AppTextStyles
                                            .body,
                                      ),
                                      Text(
                                        appt.hospitalName,
                                        style: AppTextStyles
                                            .small,
                                      ),
                                      if (appt.reason
                                          .isNotEmpty)
                                        Text(
                                          appt.reason,
                                          style: AppTextStyles
                                              .small,
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  DateTimeHelper.format(
                                      appt.dateTime),
                                  style: AppTextStyles
                                      .small
                                      .copyWith(
                                    color:
                                        AppColors.primary,
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

                  const SizedBox(
                      height: AppSpacing.xl),
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
                : AppColors.primary
                    .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isPrimary
                ? Colors.white
                : AppColors.primary,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
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

    final remindKey = '${med.id}:$index';
    final remindExpiry = _remindPending[remindKey];

    // ✅ FIX #3 — check if remind is still active
    final isRemindActive = remindExpiry != null &&
        remindExpiry.isAfter(DateTime.now());

    // Calculate minutes remaining for display
    final minutesLeft = isRemindActive
        ? remindExpiry!
            .difference(DateTime.now())
            .inMinutes
        : 0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isTaken ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius:
              BorderRadius.circular(AppRadius.md),
          border: isRemindActive
              ? Border.all(
                  color: Colors.orange.shade400,
                  width: 1.5)
              : null,
          boxShadow: [AppShadows.light],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                // Medicine icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isTaken
                        ? Colors.green.shade50
                        : AppColors.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTaken
                        ? Icons.check_circle
                        : Icons.medication,
                    color: isTaken
                        ? Colors.green.shade600
                        : AppColors.primary,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 12),

                // Medicine info
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // ✅ FIX #2 — dark text, larger
                      Text(
                        med.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF004D40),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${med.dosage}  •  ${time.format(context)}",
                        style: const TextStyle(
                          // ✅ FIX #2 — darker, readable
                          fontSize: 14,
                          color: Color(0xFF546E7A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge — taken
                if (isTaken)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              Colors.green.shade300),
                    ),
                    child: Text(
                      "✓ Taken",
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),

            // ✅ FIX #3 — remind active label
            if (isRemindActive) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius:
                      BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.alarm,
                        size: 14,
                        color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Text(
                      minutesLeft <= 1
                          ? "Reminder due soon"
                          : "Reminder in ~${minutesLeft} min",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ✅ FIX #1 — action buttons in their own
            // row BELOW medicine info — no overflow
            if (!isTaken && isTimePassed) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  // TAKEN button
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          await _medicineService
                              .markTaken(med, index);
                          // Clear remind state
                          setState(() => _remindPending
                              .remove(remindKey));
                          await _clearRemindState(
                              remindKey);
                        } catch (e) {
                          debugPrint(
                              '[ParentHome] markTaken: $e');
                        }
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius:
                              BorderRadius.circular(
                                  12),
                        ),
                        child: const Center(
                          child: Text(
                            "✓  Taken",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // REMIND button
                  Expanded(
                    child: GestureDetector(
                      onTap: isRemindActive
                          ? null
                          : () =>
                              _onRemindTap(med, index),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isRemindActive
                              ? Colors.grey.shade100
                              : Colors.orange.shade50,
                          borderRadius:
                              BorderRadius.circular(
                                  12),
                          border: Border.all(
                            color: isRemindActive
                                ? Colors.grey.shade300
                                : Colors.orange.shade400,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            isRemindActive
                                ? "⏰  Reminder Set"
                                : "⏰  Remind Me",
                            style: TextStyle(
                              color: isRemindActive
                                  ? Colors.grey.shade500
                                  : Colors.orange
                                      .shade800,
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}