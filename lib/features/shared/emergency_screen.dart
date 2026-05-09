import 'package:flutter/material.dart';
import 'package:healthconnect/models/emergency_contact.dart';
import 'package:healthconnect/features/dashboard/add_contact_screen.dart';
import 'package:healthconnect/theme/app_design_system.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  EmergencyContact? contact1;
  EmergencyContact? contact2;

  /// 🔁 NAVIGATION
  Future<void> _openAddContact(int index, {EmergencyContact? existing}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddContactScreen(existingContact: existing),
      ),
    );

    if (result != null && result is EmergencyContact) {
      setState(() {
        if (index == 1) {
          contact1 = result;
        } else {
          contact2 = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Emergency", style: AppTextStyles.heading),

              const SizedBox(height: AppSpacing.lg),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _sectionTitle("Primary Caregiver"),
                      _primaryCard(),

                      const SizedBox(height: AppSpacing.lg),

                      _sectionTitle("Emergency Contacts"),

                      _buildContact1(),

                      const SizedBox(height: AppSpacing.md),

                      _buildContact2(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 PRIMARY CARD
  Widget _primaryCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppShadows.light],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.iconBg,
            child: Icon(Icons.person, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Primary Caregiver", style: AppTextStyles.body),
              const SizedBox(height: 4),
              Text("+91 XXXXXXXX", style: AppTextStyles.small),
            ],
          ),
        ],
      ),
    );
  }

  /// 🔹 CONTACT 1
  Widget _buildContact1() {
    if (contact1 == null) {
      return _addCard(() => _openAddContact(1));
    }
    return _filledCard(contact1!, () => _openAddContact(1, existing: contact1));
  }

  /// 🔹 CONTACT 2
  Widget _buildContact2() {
    if (contact2 == null) {
      return _emptyCard(() => _openAddContact(2));
    }
    return _filledCard(contact2!, () => _openAddContact(2, existing: contact2));
  }

  /// ➕ ADD CARD
  Widget _addCard(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.accent),
          boxShadow: [AppShadows.light],
        ),
        child: const Center(
          child: Icon(Icons.add, color: AppColors.accent),
        ),
      ),
    );
  }

  /// 🔹 EMPTY CARD
  Widget _emptyCard(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 90,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppShadows.light],
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add, color: AppColors.accent),
            const SizedBox(width: AppSpacing.md),
            Text("Contact 2", style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }

  /// 🔹 FILLED CARD
  Widget _filledCard(EmergencyContact contact, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 90,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.light],
        ),
        child: Row(
          children: [
            const Icon(Icons.person, color: AppColors.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name, style: AppTextStyles.body),
                  const SizedBox(height: 4),
                  Text(contact.phone, style: AppTextStyles.small),
                ],
              ),
            ),
            const Icon(Icons.edit),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(title, style: AppTextStyles.subtitle),
      ),
    );
  }
}
