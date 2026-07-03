import 'package:flutter/material.dart';
import 'package:Vitanex/models/emergency_contact.dart';
import 'package:Vitanex/theme/app_design_system.dart';

class AddContactScreen extends StatefulWidget {
  final EmergencyContact? existingContact;

  const AddContactScreen({super.key, this.existingContact});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.existingContact != null) {
      nameController.text = widget.existingContact!.name;
      phoneController.text = widget.existingContact!.phone;
    }
  }

  void _saveContact() {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) return;

    final contact = EmergencyContact(name: name, phone: phone);

    Navigator.pop(context, contact);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingContact != null;

    return Scaffold(
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBackButton(onTap: () => Navigator.pop(context)),

              const SizedBox(height: AppSpacing.lg),

              Text(
                isEdit ? "Edit Contact" : "Add Contact",
                style: AppTextStyles.heading,
              ),

              const SizedBox(height: AppSpacing.xl),

              AppInputField(
                hint: "Full Name",
                controller: nameController,
              ),

              const SizedBox(height: AppSpacing.sm),

              AppInputField(
                hint: "Phone Number",
                controller: phoneController,
              ),

              const Spacer(),

              AppOptionButton(
                icon: isEdit ? Icons.edit : Icons.save,
                text: isEdit ? "Update Contact" : "Save Contact",
                onTap: _saveContact,
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}