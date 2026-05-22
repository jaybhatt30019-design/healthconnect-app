// lib/features/parent/parent_home.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/medicine_model.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/core/services/appointment_service.dart';
import 'package:healthconnect/core/services/medicine_service.dart';
import 'package:healthconnect/core/services/notification_service.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/utils/date_time_helper.dart';
import 'package:healthconnect/widgets/notification_badge.dart';
import 'package:healthconnect/features/emergency/calling_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:healthconnect/models/emergency_contact_model.dart';

class ParentHome extends StatefulWidget {
  final Map<String, dynamic>? parentData;
  const ParentHome({super.key, this.parentData});

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  final _medicineService = MedicineService();
  final _appointmentService = AppointmentService();
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  late final Stream<List<Medicine>> _medicineStream;
  late final Stream<List<Appointment>> _appointmentStream;

  final Map<String, DateTime> _remindPending = {};
  bool _isCalling = false;

  @override
  void initState() {
    super.initState();
    _medicineStream = _medicineService.getMedicines();
    _appointmentStream =
        _appointmentService.getAppointments();
    _loadRemindStates();
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good Morning";
    if (h < 17) return "Good Afternoon";
    return "Good Evening";
  }

  Future<void> _loadRemindStates() async {
    try {
      if (_uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('remind_states')
          .doc(_uid)
          .get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final now = DateTime.now();
      final Map<String, DateTime> active = {};
      data.forEach((key, value) {
        if (value is Timestamp) {
          final exp = value.toDate();
          if (exp.isAfter(now)) active[key] = exp;
        }
      });
      if (mounted && active.isNotEmpty) {
        setState(() => _remindPending.addAll(active));
      }
    } catch (e) {
      debugPrint('[ParentHome] Load remind: $e');
    }
  }

  Future<void> _saveRemindState(
      String key, DateTime exp) async {
    try {
      if (_uid == null) return;
      await FirebaseFirestore.instance
          .collection('remind_states')
          .doc(_uid)
          .set({key: Timestamp.fromDate(exp)},
              SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ParentHome] Save remind: $e');
    }
  }

  Future<void> _clearRemindState(String key) async {
    try {
      if (_uid == null) return;
      await FirebaseFirestore.instance
          .collection('remind_states')
          .doc(_uid)
          .update({key: FieldValue.delete()});
    } catch (e) {
      debugPrint('[ParentHome] Clear remind: $e');
    }
  }

  Future<void> _onRemindTap(
      Medicine med, int index) async {
    final key = '${med.id}:$index';
    if (_remindPending.containsKey(key)) return;
    final exp = DateTime.now()
        .add(const Duration(minutes: 15));
    setState(() => _remindPending[key] = exp);
    await _saveRemindState(key, exp);
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
          content: Row(children: [
            const Icon(Icons.alarm,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reminder set for ${med.name} in 15 min',
                style: const TextStyle(
                    color: Colors.white),
              ),
            ),
          ]),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      Future.delayed(const Duration(minutes: 15), () async {
        if (mounted) setState(() => _remindPending.remove(key));
        await _clearRemindState(key);
      });
    } catch (e) {
      if (mounted) setState(() => _remindPending.remove(key));
      await _clearRemindState(key);
    }
  }

  // ── Call Help — initiates emergency call ──────────────
  Future<void> _onCallHelp(String parentName) async {
    if (_isCalling) return;
    setState(() => _isCalling = true);
    try {
      final contacts =
          await EmergencyService().loadContacts();
      final callId = await EmergencyService()
          .initiateParentEmergency(
        callerName: parentName,
        contacts: contacts ??
            EmergencyContacts(uid: _uid ?? ''),
      );
      if (callId != null && mounted) {
        Navigator.of(context, rootNavigator: true)
            .push(
          MaterialPageRoute(
            builder: (_) => CallingScreen(
              callId: callId,
              isChild: false,
              callerName: parentName,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalling = false);
    }
  }

  // ── Dial 108 ──────────────────────────────────────────
  Future<void> _dial108() async {
    final uri = Uri.parse('tel:108');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ── Profile avatar ────────────────────────────────────
  Widget _profileAvatar(
      String? photoUrl, String name,
      {double radius = 24}) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ')
            .map((w) => w[0])
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await _loadRemindStates();
            },
            child: SingleChildScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.all(AppSpacing.lg),
              child: StreamBuilder<DocumentSnapshot>(
                // ✅ Real-time parent name + photo
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  final userData =
                      userSnap.hasData &&
                              userSnap.data!.exists
                          ? userSnap.data!.data()
                              as Map<String, dynamic>
                          : <String, dynamic>{};

                  final parentName =
                      userData['name'] as String? ??
                          'Parent';
                  final parentPhotoUrl =
                      userData['photoUrl'] as String?;
                  final caregiverId =
                      userData['caregiverId']
                          as String?;

                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      // ── Header ─────────────────
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(_getGreeting(),
                                  style:
                                      AppTextStyles
                                          .subtitle),
                              const SizedBox(height: 6),
                              // ✅ Real parent name
                              Text(
                                parentName,
                                style: AppTextStyles
                                    .heading
                                    .copyWith(
                                        color: AppColors
                                            .darkPrimary),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const NotificationBadge(),
                              const SizedBox(width: 8),
                              // ✅ Parent photo
                              _profileAvatar(
                                  parentPhotoUrl,
                                  parentName),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(
                          height: AppSpacing.xl),

                      // ── Caregiver card ──────────
                      _caregiverCard(
                          caregiverId, parentName),

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
                            children: medicines
                                .expand((med) =>
                                    List.generate(
                                        med.times.length,
                                        (i) => _medicineCard(
                                            med,
                                            med.times[i],
                                            i)))
                                .toList(),
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
                          final upcoming =
                              (snapshot.data ?? [])
                                  .where((a) => a
                                      .dateTime
                                      .isAfter(
                                          DateTime.now()))
                                  .toList();
                          if (upcoming.isEmpty) {
                            return Text(
                                "No upcoming appointments.",
                                style:
                                    AppTextStyles.body);
                          }
                          return Column(
                            children: upcoming.map((appt) {
                              return Container(
                                margin: const EdgeInsets
                                    .only(
                                    bottom: AppSpacing
                                        .sm),
                                padding:
                                    const EdgeInsets.all(
                                        AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                              AppRadius
                                                  .md),
                                  boxShadow: [
                                    AppShadows.light
                                  ],
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 45,
                                    height: 45,
                                    decoration:
                                        const BoxDecoration(
                                      color:
                                          AppColors.iconBg,
                                      shape:
                                          BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons
                                            .local_hospital,
                                        color: AppColors
                                            .primary),
                                  ),
                                  const SizedBox(
                                      width:
                                          AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                            appt.doctorName,
                                            style:
                                                AppTextStyles
                                                    .body),
                                        Text(
                                            appt.hospitalName,
                                            style:
                                                AppTextStyles
                                                    .small),
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
                                ]),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(
                          height: AppSpacing.xl),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Caregiver card shown on parent home ───────────────
  Widget _caregiverCard(
      String? caregiverId, String parentName) {
    if (caregiverId == null || caregiverId.isEmpty) {
      // Not connected
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius:
              BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.light],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person,
                  color: Colors.grey),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text("No Caregiver Connected",
                      style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700)),
                  Text(
                    "Go to Settings → Connect",
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.hasData && snap.data!.exists
            ? snap.data!.data() as Map<String, dynamic>
            : <String, dynamic>{};

        final caregiverName =
            data['name'] as String? ?? 'Caregiver';
        final caregiverPhoto =
            data['photoUrl'] as String?;

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
              // Caregiver info row
              Row(
                children: [
                  _profileAvatar(
                      caregiverPhoto, caregiverName,
                      radius: 28),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(caregiverName,
                            style: AppTextStyles.body
                                .copyWith(
                                    fontWeight:
                                        FontWeight.w700)),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text("Connected",
                                style: AppTextStyles
                                    .small
                                    .copyWith(
                                        color: Colors
                                            .green
                                            .shade700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Action buttons
              Row(
                children: [
                  // CALL HELP
                  Expanded(
                    child: GestureDetector(
                      onTap: _isCalling
                          ? null
                          : () =>
                              _onCallHelp(parentName),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: _isCalling
                              ? Colors.grey
                              : AppColors.primary,
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
                                      color: Colors.white,
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
                              style: const TextStyle(
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

  // ── Medicine card ─────────────────────────────────────
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
    final isRemindActive = remindExpiry != null &&
        remindExpiry.isAfter(DateTime.now());
    final minutesLeft = isRemindActive
        ? remindExpiry
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(med.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF004D40),
                          )),
                      Text(
                          "${med.dosage}  •  ${time.format(context)}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF546E7A),
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
                if (isTaken)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.green.shade300),
                    ),
                    child: Text("✓ Taken",
                        style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            if (isRemindActive) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
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
                          : "Reminder in ~$minutesLeft min",
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            if (!isTaken && isTimePassed) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          await _medicineService
                              .markTaken(med, index);
                          setState(() =>
                              _remindPending
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
                              BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text("✓  Taken",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                              BorderRadius.circular(12),
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
                                  : Colors.orange.shade800,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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