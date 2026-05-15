// lib/features/shared/emergency_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/emergency_contact_model.dart';
import 'package:healthconnect/core/services/emergency_service.dart';
import 'package:healthconnect/features/emergency/incoming_call_screen.dart';
import 'package:healthconnect/features/emergency/calling_screen.dart';
import 'package:healthconnect/features/emergency/add_contact_bottom_sheet.dart';

class EmergencyScreen extends StatefulWidget {
  final bool isCaregiver;

  const EmergencyScreen({super.key, required this.isCaregiver});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _emergencyService = EmergencyService();

  EmergencyContacts? _contacts;
  String _userName = '';
  bool _isCalling = false;
  bool _isPaired = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenForIncomingCalls();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    _userName = userDoc.data()?['name'] ?? 'User';

    final paired = await _emergencyService.isPaired();
    final contacts = await _emergencyService.loadContacts();

    if (mounted) {
      setState(() {
        _isPaired = paired;
        _contacts = contacts;
        _isLoading = false;
      });
    }
  }

  void _listenForIncomingCalls() {
    _emergencyService.incomingCallStream().listen((call) {
      if (call == null || !mounted) return;
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallScreen(call: call),
        ),
      );
    });
  }

  Future<void> _onCallHelp() async {
    if (_isCalling) return;

    // Parent alone with NO contacts set — show warning
    if (!widget.isCaregiver && !_isPaired) {
      final hasAnyContact = _contacts?.secondary != null ||
          _contacts?.tertiary != null;
      if (!hasAnyContact) {
        _snack("Please add emergency contacts below before calling");
        return;
      }
    }

    setState(() => _isCalling = true);

    try {
      if (widget.isCaregiver) {
        final callId = await _emergencyService.initiateChildEmergency(
          callerName: _userName,
        );
        if (callId != null && mounted) {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => CallingScreen(
                callId: callId,
                isChild: true,
                callerName: _userName,
              ),
            ),
          );
        }
      } else {
        if (_contacts == null) {
          _snack('No emergency contacts configured');
          return;
        }
        final callId = await _emergencyService.initiateParentEmergency(
          callerName: _userName,
          contacts: _contacts!,
        );
        if (callId != null && mounted) {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => CallingScreen(
                callId: callId,
                isChild: false,
                callerName: _userName,
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isCalling = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Emergency", style: AppTextStyles.heading),
                const SizedBox(height: AppSpacing.lg),

                // ── Pairing status banner (parent only) ──
                if (!widget.isCaregiver && !_isPaired)
                  _buildUnpairedBanner(),

                // ── CALL HELP button ─────────────────────
                _buildCallHelpButton(),
                const SizedBox(height: AppSpacing.xl),

                // ── Primary contact ──────────────────────
                // Only show if paired — otherwise primary is empty
                if (_isPaired) ...[
                  _sectionTitle("Primary Contact (Auto-Connected)"),
                  const SizedBox(height: AppSpacing.sm),
                  _primaryContactCard(),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // ── Secondary contact ─────────────────────
                _sectionTitle(_isPaired
                    ? "Secondary Contact"
                    : "Primary Emergency Contact"),
                const SizedBox(height: AppSpacing.sm),
                _editableContactCard(
                  contact: _contacts?.secondary,
                  label: _isPaired ? "Secondary" : "Primary",
                  onSave: (c) async {
                    final updated = EmergencyContacts(
                      uid: _contacts?.uid ?? '',
                      primary: _contacts?.primary,
                      secondary: c,
                      tertiary: _contacts?.tertiary,
                    );
                    await _emergencyService.saveContacts(updated);
                    setState(() => _contacts = updated);
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Third contact ─────────────────────────
                _sectionTitle(_isPaired
                    ? "Third Contact"
                    : "Secondary Emergency Contact"),
                const SizedBox(height: AppSpacing.sm),
                _editableContactCard(
                  contact: _contacts?.tertiary,
                  label: _isPaired ? "Third" : "Secondary",
                  onSave: (c) async {
                    final updated = EmergencyContacts(
                      uid: _contacts?.uid ?? '',
                      primary: _contacts?.primary,
                      secondary: _contacts?.secondary,
                      tertiary: c,
                    );
                    await _emergencyService.saveContacts(updated);
                    setState(() => _contacts = updated);
                  },
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Fallback info (parent only) ───────────
                if (!widget.isCaregiver) _buildFallbackInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Unpaired banner ────────────────────────────────
  Widget _buildUnpairedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "No caregiver connected",
                  style: AppTextStyles.body.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "You can still add contacts below. "
                  "CALL HELP will dial them in order.",
                  style: AppTextStyles.small
                      .copyWith(color: Colors.amber.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CALL HELP button ────────────────────────────────
  Widget _buildCallHelpButton() {
    // Disable if parent alone has no contacts at all
    final bool canCall = widget.isCaregiver ||
        _isPaired ||
        (_contacts?.secondary != null) ||
        (_contacts?.tertiary != null);

    return GestureDetector(
      onTap: canCall && !_isCalling ? _onCallHelp : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 90,
        decoration: BoxDecoration(
          color: canCall
              ? (_isCalling ? Colors.red.shade800 : Colors.red)
              : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(20),
          boxShadow: canCall
              ? [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCalling)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3),
              )
            else
              const Icon(Icons.call, color: Colors.white, size: 36),
            const SizedBox(width: 14),
            Text(
              _isCalling
                  ? "Connecting..."
                  : canCall
                      ? "CALL HELP"
                      : "ADD CONTACTS FIRST",
              style: TextStyle(
                color: Colors.white,
                fontSize: canCall ? 26 : 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Primary contact (auto, paired only) ─────────────
  Widget _primaryContactCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [AppShadows.light],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: AppColors.iconBg, shape: BoxShape.circle),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isCaregiver
                      ? "Your connected parent"
                      : "Your connected caregiver",
                  style: AppTextStyles.body,
                ),
                Text("Auto-connected via pairing",
                    style: AppTextStyles.small),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.iconBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text("Primary",
                style: AppTextStyles.small.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Editable contact card ────────────────────────────
  Widget _editableContactCard({
    required EmergencyContactEntry? contact,
    required String label,
    required Function(EmergencyContactEntry) onSave,
  }) {
    if (contact == null) {
      return GestureDetector(
        onTap: () => _showAddContactSheet(label: label, onSave: onSave),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.accent, width: 1.5),
            boxShadow: [AppShadows.light],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: AppColors.accent),
                const SizedBox(width: 8),
                Text("Add $label Contact",
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.accent)),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showAddContactSheet(
          label: label, existing: contact, onSave: onSave),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.light],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                  color: AppColors.iconBg, shape: BoxShape.circle),
              child: const Icon(Icons.person_outline,
                  color: AppColors.accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name, style: AppTextStyles.body),
                  Text(contact.phone, style: AppTextStyles.small),
                ],
              ),
            ),
            const Icon(Icons.edit, color: AppColors.hint, size: 18),
          ],
        ),
      ),
    );
  }

  void _showAddContactSheet({
    required String label,
    EmergencyContactEntry? existing,
    required Function(EmergencyContactEntry) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddContactBottomSheet(
        label: label,
        existing: existing,
        onSave: onSave,
      ),
    );
  }

  Widget _buildFallbackInfo() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text("How CALL HELP works",
                style: AppTextStyles.body.copyWith(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(
            _isPaired
                ? "1. Your caregiver is called first\n"
                    "2. No answer in 15s → first added contact\n"
                    "3. No answer in 15s → second added contact\n"
                    "Fully automatic."
                : "1. First added contact is called\n"
                    "2. No answer in 15s → second added contact\n"
                    "Add contacts above to enable this.",
            style:
                AppTextStyles.small.copyWith(color: Colors.blue.shade800),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style:
          AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w700));
}