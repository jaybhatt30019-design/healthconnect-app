// lib/features/dashboard/setup_checklist_dialog.dart
// Shows daily until all items are complete
// User can snooze for 3 days
// Tapping items navigates to that screen

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthconnect/theme/app_design_system.dart';

// ── Data model for each checklist item ─────────────
class _CheckItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDone;
  final VoidCallback? onTap; // null if done

  const _CheckItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDone,
    this.onTap,
  });
}

// ── Main dialog class ───────────────────────────────
class SetupChecklistDialog {

  // ── Show if needed ──────────────────────────────
  // Call this from MainDashboard initState
  static Future<void> showIfNeeded({
    required BuildContext context,
    required bool isCaregiver,
    required Function(int) switchTab,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final data = doc.data() ?? {};

      // ── Check snooze ──────────────────────────
      final snoozeUntil =
          data['checklistSnoozeUntil'] as String?;
      if (snoozeUntil != null) {
        final snoozeDate = DateTime.tryParse(snoozeUntil);
        if (snoozeDate != null &&
            snoozeDate.isAfter(DateTime.now())) {
          debugPrint(
              '[Checklist] Snoozed until $snoozeUntil');
          return; // Still in snooze period
        }
      }

      if (!context.mounted) return;

      // ── Build checklist items ─────────────────
      final items = await _buildItems(
        uid: uid,
        data: data,
        isCaregiver: isCaregiver,
        context: context,
        switchTab: switchTab,
      );

      // ── All done → never show ─────────────────
      final allDone = items.every((i) => i.isDone);
      if (allDone) {
        debugPrint('[Checklist] All done — not showing');
        return;
      }

      if (!context.mounted) return;

      // ── Show dialog ───────────────────────────
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ChecklistDialog(
          isCaregiver: isCaregiver,
          items: items,
          onSnooze: () => _snooze(uid),
          userName: data['name'] as String? ?? 'there',
        ),
      );
    } catch (e) {
      debugPrint('[Checklist] Error: $e');
    }
  }

  // ── Save snooze for 3 days ────────────────────────
  static Future<void> _snooze(String uid) async {
    final snoozeUntil = DateTime.now()
        .add(const Duration(days: 3))
        .toIso8601String();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'checklistSnoozeUntil': snoozeUntil});

    debugPrint('[Checklist] Snoozed for 3 days');
  }

  // ── Build items based on role and Firestore data ──
  static Future<List<_CheckItem>> _buildItems({
    required String uid,
    required Map<String, dynamic> data,
    required bool isCaregiver,
    required BuildContext context,
    required Function(int) switchTab,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final items = <_CheckItem>[];

    if (isCaregiver) {
      // ── CAREGIVER ITEMS ───────────────────────

      // 1. Parent connected
      final parentLinked =
          data['parentLinked'] as bool? ?? false;
      items.add(_CheckItem(
        title: 'Connect your parent',
        subtitle: parentLinked
            ? 'Parent is connected'
            : 'Share pairing code with your parent',
        icon: Icons.link,
        isDone: parentLinked,
        onTap: parentLinked
            ? null
            : () {
                Navigator.of(context).pop();
                switchTab(4); // More tab
              },
      ));

      // 2. Medicines added
      String? parentUid;
      try {
        final parentSnap = await firestore
            .collection('users')
            .where('caregiverId', isEqualTo: uid)
            .where('role', isEqualTo: 'parent')
            .limit(1)
            .get();
        if (parentSnap.docs.isNotEmpty) {
          parentUid = parentSnap.docs.first.id;
        }
      } catch (_) {}

      int medCount = 0;
      if (parentUid != null) {
        try {
          final medsSnap = await firestore
              .collection('medicines')
              .where('parentUid', isEqualTo: parentUid)
              .get();
          medCount = medsSnap.docs.length;
        } catch (_) {}
      }

      items.add(_CheckItem(
        title: 'Add medicines',
        subtitle: medCount > 0
            ? '$medCount medicine${medCount > 1 ? 's' : ''} added'
            : 'No medicines added yet',
        icon: Icons.medication_outlined,
        isDone: medCount > 0,
        onTap: medCount > 0
            ? null
            : () {
                Navigator.of(context).pop();
                switchTab(1); // Medicines tab
              },
      ));

      // 3. Appointment added
      int apptCount = 0;
      if (parentUid != null) {
        try {
          final apptSnap = await firestore
              .collection('appointments')
              .where('parentUid', isEqualTo: parentUid)
              .get();
          apptCount = apptSnap.docs.length;
        } catch (_) {}
      }

      items.add(_CheckItem(
        title: 'Add appointments',
        subtitle: apptCount > 0
            ? '$apptCount appointment${apptCount > 1 ? 's' : ''} added'
            : 'No appointments added yet',
        icon: Icons.calendar_today_outlined,
        isDone: apptCount > 0,
        onTap: apptCount > 0
            ? null
            : () {
                Navigator.of(context).pop();
                switchTab(2); // Appointments tab
              },
      ));

      // 4. Emergency contact
      bool hasContact = false;
      try {
        final contactDoc = await firestore
            .collection('emergency_contacts')
            .doc(uid)
            .get();
        hasContact = contactDoc.exists &&
            contactDoc.data()?['secondary'] != null;
      } catch (_) {}

      items.add(_CheckItem(
        title: 'Add emergency contact',
        subtitle: hasContact
            ? 'Emergency contact saved'
            : 'Add a fallback contact number',
        icon: Icons.contact_phone_outlined,
        isDone: hasContact,
        onTap: hasContact
            ? null
            : () {
                Navigator.of(context).pop();
                switchTab(3); // Emergency tab
              },
      ));

      // 5. Health passport
      bool passportFilled = false;
      if (parentUid != null) {
        try {
          final passDoc = await firestore
              .collection('health_passport')
              .doc(parentUid)
              .get();
          passportFilled = passDoc.exists &&
              passDoc.data()?['bloodPressureSystolic'] !=
                  null;
        } catch (_) {}
      }

      items.add(_CheckItem(
        title: "Fill parent's Health Passport",
        subtitle: passportFilled
            ? 'Health passport filled'
            : 'Add BP, oxygen, heart rate readings',
        icon: Icons.badge_outlined,
        isDone: passportFilled,
        onTap: passportFilled
            ? null
            : () {
                Navigator.of(context).pop();
                switchTab(4); // More → Health Passport
              },
      ));
    } else {
      // ── PARENT ITEMS ──────────────────────────

      // 1. Caregiver connected
      final caregiverId =
          data['caregiverId'] as String?;
      final isConnected = caregiverId != null &&
          caregiverId.isNotEmpty;

      items.add(_CheckItem(
        title: 'Connect with caregiver',
        subtitle: isConnected
            ? 'Connected to your caregiver'
            : 'Enter the pairing code from your child',
        icon: Icons.link,
        isDone: isConnected,
        onTap: isConnected
            ? null
            : () {
                Navigator.of(context).pop();
                switchTab(4); // More tab
              },
      ));

      // 2. Health passport
      bool passportFilled = false;
      try {
        final passDoc = await firestore
            .collection('health_passport')
            .doc(uid)
            .get();
        passportFilled = passDoc.exists &&
            passDoc.data()?['bloodPressureSystolic'] !=
                null;
      } catch (_) {}

      items.add(_CheckItem(
        title: 'Fill your Health Passport',
        subtitle: passportFilled
            ? 'Health passport filled'
            : 'Add your BP, oxygen, blood group etc.',
        icon: Icons.badge_outlined,
        isDone: passportFilled,
        onTap: passportFilled
            ? null
            : () {
                Navigator.of(context).pop();
                switchTab(4); // More → Health Passport
              },
      ));

      // 3. Emergency contact
      bool hasContact = false;
      try {
        final contactDoc = await firestore
            .collection('emergency_contacts')
            .doc(uid)
            .get();
        hasContact = contactDoc.exists &&
            contactDoc.data()?['secondary'] != null;
      } catch (_) {}

      items.add(_CheckItem(
        title: 'Add emergency contact',
        subtitle: hasContact
            ? 'Emergency contact saved'
            : 'Add a fallback contact number',
        icon: Icons.contact_phone_outlined,
        isDone: hasContact,
        onTap: hasContact
            ? null
            : () {
                Navigator.of(context).pop();
                switchTab(3); // Emergency tab
              },
      ));

      // 4. Medical history
      bool hasHistory = false;
      try {
        final histDoc = await firestore
            .collection('medical_history')
            .doc(uid)
            .get();
        hasHistory = histDoc.exists;
      } catch (_) {}

      items.add(_CheckItem(
        title: 'Add medical history',
        subtitle: hasHistory
            ? 'Medical history added'
            : 'Add past illnesses and surgeries',
        icon: Icons.history_edu_outlined,
        isDone: hasHistory,
        onTap: hasHistory
            ? null
            : () {
                Navigator.of(context).pop();
                switchTab(4); // More → Medical History
              },
      ));
    }

    return items;
  }
}

// ── Dialog widget ───────────────────────────────────
class _ChecklistDialog extends StatelessWidget {
  final bool isCaregiver;
  final List<_CheckItem> items;
  final VoidCallback onSnooze;
  final String userName;

  const _ChecklistDialog({
    required this.isCaregiver,
    required this.items,
    required this.onSnooze,
    required this.userName,
  });

  int get _doneCount => items.where((i) => i.isDone).length;
  int get _totalCount => items.length;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFFFFF3E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Header ─────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '👋 Welcome, $userName!',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      // Progress badge
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.25),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_doneCount/$_totalCount done',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Complete your setup to get '
                    'the most out of HealthConnect.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white
                          .withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Progress bar
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _totalCount > 0
                          ? _doneCount / _totalCount
                          : 0,
                      minHeight: 6,
                      backgroundColor: Colors.white
                          .withValues(alpha: 0.3),
                      valueColor:
                          const AlwaysStoppedAnimation<
                              Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // ── Checklist items ────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    Text(
                      'Setup Checklist',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.hint,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Checklist items
                    ...items.map((item) =>
                        _buildItem(context, item)),

                    const SizedBox(height: 16),

                    // Features section
                    Text(
                      'What you can do',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.hint,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    _featureRow('📞',
                        'CALL HELP — voice call your ${isCaregiver ? 'parent' : 'caregiver'} instantly'),
                    _featureRow('🚨',
                        '108 — call ambulance directly from app'),
                    _featureRow('💊',
                        'Medicine reminders — automatic alerts at dose time'),
                    _featureRow('📍',
                        isCaregiver
                            ? 'Live map — see parent location in real time'
                            : 'Location — your caregiver can see you on map'),
                    _featureRow('📄',
                        'Export health report as PDF anytime'),
                    _featureRow('🔔',
                        'Missed dose alerts sent to caregiver automatically'),
                  ],
                ),
              ),
            ),

            // ── Buttons ────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(
                  16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: 0.6),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  // Snooze button
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 12),
                      ),
                      onPressed: () {
                        onSnooze();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(
                          Icons.snooze_outlined,
                          size: 16),
                      label: Text(
                        'Remind in 3 days',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.hint,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Got it button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () =>
                          Navigator.of(context).pop(),
                      child: Text(
                        'Got it!',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Single checklist item ─────────────────────────
  Widget _buildItem(
      BuildContext context, _CheckItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: item.isDone
              ? Colors.green.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isDone
                ? Colors.green.withValues(alpha: 0.3)
                : item.onTap != null
                    ? AppColors.primary
                        .withValues(alpha: 0.4)
                    : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.isDone
                    ? Colors.green.withValues(alpha: 0.15)
                    : AppColors.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.isDone
                    ? Icons.check_circle
                    : item.icon,
                size: 18,
                color: item.isDone
                    ? Colors.green.shade600
                    : AppColors.primary,
              ),
            ),

            const SizedBox(width: 10),

            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ✅ Strikethrough when done
                  Text(
                    item.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: item.isDone
                          ? AppColors.hint
                          : AppColors.darkPrimary,
                      decoration: item.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: AppColors.hint,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: item.isDone
                          ? Colors.green.shade600
                          : AppColors.hint,
                    ),
                  ),
                ],
              ),
            ),

            // Go arrow — only if pending and tappable
            if (!item.isDone && item.onTap != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: Text(
                  'Go →',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Feature row ───────────────────────────────────
  Widget _featureRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji,
              style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.darkPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}