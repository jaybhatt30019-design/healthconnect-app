import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/emergency_contact_model.dart';

class AddContactBottomSheet extends StatefulWidget {
  final String label;
  final EmergencyContactEntry? existing;
  final Function(EmergencyContactEntry) onSave;

  const AddContactBottomSheet({
    super.key,
    required this.label,
    this.existing,
    required this.onSave,
  });

  @override
  State<AddContactBottomSheet> createState() => _AddContactBottomSheetState();
}

class _AddContactBottomSheetState extends State<AddContactBottomSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill name and phone")),
      );
      return;
    }

    widget.onSave(EmergencyContactEntry(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            "${widget.existing != null ? 'Edit' : 'Add'} ${widget.label} Contact",
            style: AppTextStyles.heading,
          ),

          const SizedBox(height: 20),

          AppInputField(
            hint: "Full Name",
            controller: _nameCtrl,
            icon: Icons.person_outline,
          ),

          const SizedBox(height: 14),

          AppInputField(
            hint: "Phone Number",
            controller: _phoneCtrl,
            icon: Icons.phone_outlined,
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(
                "Save Contact",
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}