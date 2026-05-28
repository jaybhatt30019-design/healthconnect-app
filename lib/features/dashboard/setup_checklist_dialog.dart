// lib/features/dashboard/setup_checklist_dialog.dart
// ✅ REWRITTEN: Persistent banner instead of one-time dialog
// Shows at bottom of screen until all items are complete
// Updates in real time — checks Firestore on each tab switch
// Tapping items navigates and banner stays visible

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthconnect/theme/app_design_system.dart';

// ── Data model ──────────────────────────────────────
class _CheckItem {
  final String key; // unique key for this item
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDone;
  final VoidCallback? onTap;

  const _CheckItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDone,
    this.onTap,
  });
}

// ── Persistent checklist banner ─────────────────────
// Add this widget to MainDashboard scaffold body
// It wraps the content and shows banner at bottom
class SetupChecklistBanner extends StatefulWidget {
  final bool isCaregiver;
  final Function(int) switchTab;
  final Widget child;

  const SetupChecklistBanner({
    super.key,
    required this.isCaregiver,
    required this.switchTab,
    required this.child,
  });

  @override
  State<SetupChecklistBanner> createState() =>
      SetupChecklistBannerState();
}

class SetupChecklistBannerState
    extends State<SetupChecklistBanner> {
  List<_CheckItem> _items = [];
  bool _allDone = false;
  bool _dismissed = false;
  bool _expanded = false;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // ✅ Refresh every 3 seconds while banner visible
    // Picks up changes when user completes a step
    // and comes back to any tab
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (!_dismissed && !_allDone) _load();
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Load and check all items ──────────────────────
  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final data = doc.data() ?? {};

final items = await _buildItems(
  uid: uid,
  data: data,
  isCaregiver: widget.isCaregiver,
  switchTab: widget.switchTab,
);

      final allDone = items.every((i) => i.isDone);

      if (mounted) {
        setState(() {
          _items = items;
          _allDone = allDone;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[Checklist] Load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ Public method — call this from MainDashboard
  // when user switches tabs so checklist refreshes
  void refresh() {
    if (!_dismissed && !_allDone) _load();
  }

  int get _doneCount =>
      _items.where((i) => i.isDone).length;
  int get _totalCount => _items.length;

  @override
  Widget build(BuildContext context) {
    // Nothing to show
    if (_loading ||
        _allDone ||
        _dismissed ||
        _items.isEmpty) {
      return widget.child;
    }

    return Column(
      children: [
        // Main content — takes all available space
        Expanded(child: widget.child),

        // ✅ Persistent banner at bottom
        _buildBanner(context),
      ],
    );
  }

  // ── Banner UI ─────────────────────────────────────
  Widget _buildBanner(BuildContext context) {
    final pending =
        _items.where((i) => !i.isDone).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Collapsed header — always visible ────
          GestureDetector(
            onTap: () =>
                setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // Progress circle
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Stack(
                      children: [
                        CircularProgressIndicator(
                          value: _totalCount > 0
                              ? _doneCount / _totalCount
                              : 0,
                          strokeWidth: 3,
                          backgroundColor: Colors.white
                              .withValues(alpha: 0.3),
                          valueColor:
                              const AlwaysStoppedAnimation(
                                  Colors.white),
                        ),
                        Center(
                          child: Text(
                            '$_doneCount',
                            style:
                                const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
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
                        Text(
                          'Setup $_doneCount/$_totalCount complete',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (pending.isNotEmpty)
                          Text(
                            'Next: ${pending.first.title}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white
                                  .withValues(alpha: 0.85),
                            ),
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Expand/collapse arrow
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.white,
                  ),

                  // Dismiss button
                  GestureDetector(
                    onTap: () => setState(
                        () => _dismissed = true),
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 8),
                      child: Icon(
                        Icons.close,
                        color: Colors.white
                            .withValues(alpha: 0.7),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded list of items ────────────────
          if (_expanded)
            Container(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height *
                        0.4,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    12, 8, 12, 12),
                child: Column(
                  children: _items
                      .map((item) =>
                          _buildItem(context, item))
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Single item row ───────────────────────────────
  Widget _buildItem(
      BuildContext context, _CheckItem item) {
    return GestureDetector(
      onTap: item.isDone ? null : item.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: item.isDone
              ? Colors.green.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isDone
                ? Colors.green.withValues(alpha: 0.25)
                : AppColors.primary
                    .withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: item.isDone
                    ? Colors.green
                        .withValues(alpha: 0.12)
                    : AppColors.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.isDone
                    ? Icons.check_circle
                    : item.icon,
                size: 16,
                color: item.isDone
                    ? Colors.green.shade600
                    : AppColors.primary,
              ),
            ),

            const SizedBox(width: 10),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
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

            // Go button
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
}

// ── Build items ─────────────────────────────────────
Future<List<_CheckItem>> _buildItems({
  required String uid,
  required Map<String, dynamic> data,
  required bool isCaregiver,
  required Function(int) switchTab,
}) async {
  final firestore = FirebaseFirestore.instance;
  final items = <_CheckItem>[];

  if (isCaregiver) {
    // 1. Parent connected
    final parentLinked =
        data['parentLinked'] as bool? ?? false;
    items.add(_CheckItem(
      key: 'parent_linked',
      title: 'Connect your parent',
      subtitle: parentLinked
          ? 'Parent is connected ✓'
          : 'Share pairing code with your parent',
      icon: Icons.link,
      isDone: parentLinked,
      onTap: parentLinked
          ? null
          : () => switchTab(4),
    ));

    // Get parentUid for subsequent checks
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

    // 2. Medicines added
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
      key: 'medicines',
      title: 'Add medicines',
      subtitle: medCount > 0
          ? '$medCount medicine${medCount > 1 ? 's' : ''} added ✓'
          : 'No medicines added yet',
      icon: Icons.medication_outlined,
      isDone: medCount > 0,
      onTap: medCount > 0 ? null : () => switchTab(1),
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
      key: 'appointments',
      title: 'Add appointments',
      subtitle: apptCount > 0
          ? '$apptCount appointment${apptCount > 1 ? 's' : ''} added ✓'
          : 'No appointments added yet',
      icon: Icons.calendar_today_outlined,
      isDone: apptCount > 0,
      onTap:
          apptCount > 0 ? null : () => switchTab(2),
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
      key: 'emergency_contact',
      title: 'Add emergency contact',
      subtitle: hasContact
          ? 'Emergency contact saved ✓'
          : 'Add a fallback contact number',
      icon: Icons.contact_phone_outlined,
      isDone: hasContact,
      onTap: hasContact ? null : () => switchTab(3),
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
      key: 'health_passport',
      title: "Fill parent's Health Passport",
      subtitle: passportFilled
          ? 'Health passport filled ✓'
          : 'Add BP, oxygen, heart rate readings',
      icon: Icons.badge_outlined,
      isDone: passportFilled,
      onTap:
          passportFilled ? null : () => switchTab(4),
    ));
  } else {
    // ── PARENT ITEMS ────────────────────────────

    // 1. Caregiver connected
    final caregiverId =
        data['caregiverId'] as String?;
    final isConnected = caregiverId != null &&
        caregiverId.isNotEmpty;
    items.add(_CheckItem(
      key: 'caregiver_linked',
      title: 'Connect with caregiver',
      subtitle: isConnected
          ? 'Connected to your caregiver ✓'
          : 'Enter the pairing code from your child',
      icon: Icons.link,
      isDone: isConnected,
      onTap: isConnected ? null : () => switchTab(4),
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
      key: 'health_passport',
      title: 'Fill your Health Passport',
      subtitle: passportFilled
          ? 'Health passport filled ✓'
          : 'Add your BP, oxygen, blood group etc.',
      icon: Icons.badge_outlined,
      isDone: passportFilled,
      onTap: passportFilled
          ? null
          : () => switchTab(4),
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
      key: 'emergency_contact',
      title: 'Add emergency contact',
      subtitle: hasContact
          ? 'Emergency contact saved ✓'
          : 'Add a fallback contact number',
      icon: Icons.contact_phone_outlined,
      isDone: hasContact,
      onTap: hasContact ? null : () => switchTab(3),
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
      key: 'medical_history',
      title: 'Add medical history',
      subtitle: hasHistory
          ? 'Medical history added ✓'
          : 'Add past illnesses and surgeries',
      icon: Icons.history_edu_outlined,
      isDone: hasHistory,
      onTap: hasHistory ? null : () => switchTab(4),
    ));
  }

  return items;
}

// ── Keep old static class for backward compat ───────
// MainDashboard still calls SetupChecklistDialog.showIfNeeded
// This now does nothing — banner handles everything
class SetupChecklistDialog {
  static Future<void> showIfNeeded({
    required BuildContext context,
    required bool isCaregiver,
    required Function(int) switchTab,
  }) async {
    // No-op — replaced by SetupChecklistBanner widget
    // Remove this call from MainDashboard and use
    // SetupChecklistBanner widget instead
  }
}