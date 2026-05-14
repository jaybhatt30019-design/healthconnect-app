// lib/features/shared/emergency_screen.dart
// Uses SosService (renamed from EmergencyService to avoid file conflict)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/emergency_contact_model.dart';
import 'package:healthconnect/core/services/sos_service.dart';
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
  final _sosService = SosService();
  EmergencyContacts? _contacts;
  String _userName = '';
  bool _isCalling = false;

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

    final contacts = await _sosService.loadContacts();
    if (mounted) setState(() => _contacts = contacts);
  }

  void _listenForIncomingCalls() {
    _sosService.incomingCallStream().listen((call) {
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
    setState(() => _isCalling = true);

    try {
      if (widget.isCaregiver) {
        // Caregiver (child role) → notify parent
        final callId = await _sosService.initiateChildEmergency(
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
        // Parent → fallback through contacts
        if (_contacts == null) {
          _snack('No emergency contacts configured');
          return;
        }
        final callId = await _sosService.initiateParentEmergency(
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

                _buildCallHelpButton(),
                const SizedBox(height: AppSpacing.xl),

                _sectionTitle("Primary Contact (Auto-Connected)"),
                const SizedBox(height: AppSpacing.sm),
                _primaryContactCard(),

                const SizedBox(height: AppSpacing.lg),
                _sectionTitle("Secondary Contact"),
                const SizedBox(height: AppSpacing.sm),
                _editableContactCard(
                  contact: _contacts?.secondary,
                  label: "Secondary",
                  onSave: (c) async {
                    final updated = EmergencyContacts(
                      uid: _contacts?.uid ?? '',
                      primary: _contacts?.primary,
                      secondary: c,
                      tertiary: _contacts?.tertiary,
                    );
                    await _sosService.saveContacts(updated);
                    setState(() => _contacts = updated);
                  },
                ),

                const SizedBox(height: AppSpacing.lg),
                _sectionTitle("Third Contact"),
                const SizedBox(height: AppSpacing.sm),
                _editableContactCard(
                  contact: _contacts?.tertiary,
                  label: "Third",
                  onSave: (c) async {
                    final updated = EmergencyContacts(
                      uid: _contacts?.uid ?? '',
                      primary: _contacts?.primary,
                      secondary: _contacts?.secondary,
                      tertiary: c,
                    );
                    await _sosService.saveContacts(updated);
                    setState(() => _contacts = updated);
                  },
                ),

                const SizedBox(height: AppSpacing.xl),
                if (!widget.isCaregiver) _buildFallbackInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallHelpButton() {
    return GestureDetector(
      onTap: _isCalling ? null : _onCallHelp,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 90,
        decoration: BoxDecoration(
          color: _isCalling ? Colors.red.shade800 : Colors.red,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
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
              _isCalling ? "Connecting..." : "CALL HELP",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryContactCard() {
    final primary = _contacts?.primary;
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
            width: 48, height: 48,
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
                  primary?.name ??
                      (widget.isCaregiver
                          ? "Your connected parent"
                          : "Your connected child"),
                  style: AppTextStyles.body,
                ),
                Text("Auto-connected via pairing",
                    style: AppTextStyles.small),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  Widget _editableContactCard({
    required EmergencyContactEntry? contact,
    required String label,
    required Function(EmergencyContactEntry) onSave,
  }) {
    if (contact == null) {
      return GestureDetector(
        onTap: () =>
            _showAddContactSheet(label: label, onSave: onSave),
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
              width: 48, height: 48,
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
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, color: Colors.amber.shade700),
            const SizedBox(width: 8),
            Text("Auto-Fallback Calling",
                style: AppTextStyles.body.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(
            "When you press CALL HELP:\n"
            "1. Primary contact called first\n"
            "2. No answer in 15s → Secondary\n"
            "3. No answer in 15s → Third\n"
            "Fully automatic.",
            style:
                AppTextStyles.small.copyWith(color: Colors.amber.shade900),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: AppTextStyles.subtitle
          .copyWith(fontWeight: FontWeight.w700));
}