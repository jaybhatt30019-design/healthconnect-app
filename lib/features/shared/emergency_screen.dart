// lib/features/shared/emergency_screen.dart
// CALL HELP button removed — lives on dashboard only
// Incoming call listener removed — MainDashboard handles it

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Vitanex/theme/app_design_system.dart';
import 'package:Vitanex/models/emergency_contact_model.dart';
import 'package:Vitanex/core/services/emergency_service.dart';
import 'package:Vitanex/features/emergency/add_contact_bottom_sheet.dart';

class EmergencyScreen extends StatefulWidget {
  final bool isCaregiver;

  const EmergencyScreen(
      {super.key, required this.isCaregiver});

  @override
  State<EmergencyScreen> createState() =>
      _EmergencyScreenState();
}

class _EmergencyScreenState
    extends State<EmergencyScreen> {
  final _emergencyService = EmergencyService();

  EmergencyContacts? _contacts;
  bool _isPaired = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    // ✅ No incoming call listener here
    // MainDashboard handles it for all tabs
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final paired = await _emergencyService.isPaired();
    final contacts =
        await _emergencyService.loadContacts();

    if (mounted) {
      setState(() {
        _isPaired = paired;
        _contacts = contacts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding:
                    const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child:  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text("Emergency",
                          style: AppTextStyles.heading),
                      const SizedBox(height: AppSpacing.lg),
                  
                      // Parent not paired
                      if (!widget.isCaregiver && !_isPaired)
                        _buildNotConnectedState()
                      else ...[
                  
                        // ── Info banner ────────────────────
                        _buildInfoBanner(),
                        const SizedBox(height: AppSpacing.xl),
                  
                        // ── Primary contact ────────────────
                        if (_isPaired) ...[
                          _sectionTitle(
                              "Primary Contact (Auto-Connected)"),
                          const SizedBox(
                              height: AppSpacing.sm),
                          _primaryContactCard(),
                          const SizedBox(
                              height: AppSpacing.lg),
                        ],
                  
                        // ── Fallback contact ───────────────
                        _sectionTitle(_isPaired
                            ? "Fallback Contact"
                            : "Emergency Contact"),
                        const SizedBox(height: AppSpacing.sm),
                        _editableContactCard(
                          contact: _contacts?.secondary,
                          label: "Fallback",
                          onSave: (c) async {
                            final updated = EmergencyContacts(
                              uid: _contacts?.uid ?? '',
                              primary: _contacts?.primary,
                              secondary: c,
                              tertiary: null,
                            );
                            await _emergencyService
                                .saveContacts(updated);
                            setState(
                                () => _contacts = updated);
                          },
                        ),
                  
                        const SizedBox(height: AppSpacing.xl),
                  
                        if (!widget.isCaregiver)
                          _buildFallbackInfo(),
                      ],
                    ],
                  ),
      )); }) ),
      ),
    );
  }

  // ── Info banner ───────────────────────────────────
  // Replaces the CALL HELP button
  // Tells user where to find it
  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius:
            BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: const Color(0xFF0E7C6B), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF0E7C6B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.call,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  "CALL HELP is on your Home screen",
                  style: AppTextStyles.body.copyWith(
                    color: const Color(0xFF004D40),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Tap the Home tab and use the "
                  "CALL HELP button to reach your "
                  "${widget.isCaregiver ? 'parent' : 'caregiver'} instantly.",
                  style: AppTextStyles.small.copyWith(
                      color:
                          const Color(0xFF00695C)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnectedState() {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.red.shade200,
                  width: 2),
            ),
            child: Icon(Icons.emergency_outlined,
                size: 48,
                color: Colors.red.shade400),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            "Emergency Calling\nNot Available",
            textAlign: TextAlign.center,
            style: AppTextStyles.heading.copyWith(
              fontSize: 22,
              color: Colors.red.shade700,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            "You need to be connected to a caregiver\n"
            "to use the emergency calling feature.",
            textAlign: TextAlign.center,
            style: AppTextStyles.body
                .copyWith(color: AppColors.hint),
          ),

          const SizedBox(height: AppSpacing.xl),

          Container(
            padding:
                const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius:
                  BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: Colors.amber.shade300),
            ),
            child: Column(
              children: [
                Row(children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade700,
                      size: 18),
                  const SizedBox(width: 8),
                  Text("How to connect",
                      style: AppTextStyles.body
                          .copyWith(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w700,
                      )),
                ]),
                const SizedBox(height: 10),
                _step("1",
                    "Ask your caregiver to open the app"),
                _step("2",
                    "Caregiver goes to More → Add Parent"),
                _step("3",
                    "Caregiver shares the pairing code"),
                _step("4",
                    "Go to More → Enter the pairing code"),
                _step("5",
                    "Once connected, emergency calling works"),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _step(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppTextStyles.small.copyWith(
                    color: Colors.amber.shade900)),
          ),
        ],
      ),
    );
  }

  Widget _primaryContactCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: AppColors.primary, width: 1.5),
        boxShadow: [AppShadows.light],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: AppColors.iconBg,
                shape: BoxShape.circle),
            child: const Icon(Icons.person,
                color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
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
        onTap: () => _showAddContactSheet(
            label: label, onSave: onSave),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius:
                BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: AppColors.accent, width: 1.5),
            boxShadow: [AppShadows.light],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                const Icon(Icons.add,
                    color: AppColors.accent),
                const SizedBox(width: 8),
                Text("Add $label Contact",
                    style: AppTextStyles.body.copyWith(
                        color: AppColors.accent)),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showAddContactSheet(
          label: label,
          existing: contact,
          onSave: onSave),
      child: Container(
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
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                  color: AppColors.iconBg,
                  shape: BoxShape.circle),
              child: const Icon(Icons.person_outline,
                  color: AppColors.accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                      style: AppTextStyles.body),
                  Text(contact.phone,
                      style: AppTextStyles.small),
                ],
              ),
            ),
            const Icon(Icons.edit,
                color: AppColors.hint, size: 18),
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
        borderRadius:
            BorderRadius.circular(AppRadius.md),
        border:
            Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline,
                color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text("How CALL HELP works",
                style: AppTextStyles.body.copyWith(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(
            _isPaired
                ? "1. Your caregiver is called first via the app\n"
                    "2. If unreachable after 20 seconds,\n"
                    "   the fallback contact is dialled\n"
                    "   on your regular phone"
                : "1. Your fallback contact is dialled\n"
                    "   on your regular phone\n"
                    "Connect a caregiver for in-app calling",
            style: AppTextStyles.small
                .copyWith(color: Colors.blue.shade800),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: AppTextStyles.subtitle
          .copyWith(fontWeight: FontWeight.w700));
}