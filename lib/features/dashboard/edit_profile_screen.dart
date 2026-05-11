import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';


class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;

  File? _profileImage;
final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final uid = _auth.currentUser?.uid;

      if (uid == null) return;

      final doc =
          await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;

        _nameController.text = data['name'] ?? '';

        _ageController.text =
            data['age']?.toString() ?? '';

        _phoneController.text =
            data['phone'] ?? '';

        _emailController.text =
            data['email'] ??
            _auth.currentUser?.email ??
            '';
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint(e.toString());

      setState(() => _isLoading = false);
    }
  }
Future<void> _pickImage() async {
  final XFile? image = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 70,
  );

  if (image != null) {
    setState(() {
      _profileImage = File(image.path);
    });
  }
}
  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _snack("Please enter name");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = _auth.currentUser?.uid;

      if (uid == null) return;

      await _firestore.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'age':
            int.tryParse(_ageController.text.trim()) ?? 0,
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      _snack("Profile updated");

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      _snack("Failed to save");
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    AppBackButton(
                      onTap: () => Navigator.pop(context),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    Text(
                      "Edit Profile",
                      style: AppTextStyles.heading,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Center(
  child: Stack(
    children: [
      CircleAvatar(
        radius: 55,
        backgroundColor: Colors.grey.shade300,
        backgroundImage:
            _profileImage != null
                ? FileImage(_profileImage!)
                : null,
        child:
            _profileImage == null
                ? const Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.white,
                )
                : null,
      ),

      Positioned(
        bottom: 0,
        right: 0,
        child: GestureDetector(
          onTap: _pickImage,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    ],
  ),
),

const SizedBox(height: AppSpacing.xl),
                            /// NAME
                            _label("Full Name"),

                            AppInputField(
                              hint: "Enter your full name",
                              controller: _nameController,
                              icon: Icons.person_outline,
                            ),

                            const SizedBox(
                                height: AppSpacing.md),

                            /// AGE
                            _label("Age"),

                            AppInputField(
                              hint: "Enter age",
                              controller: _ageController,
                              icon: Icons.cake_outlined,
                              keyboardType:
                                  TextInputType.number,
                            ),

                            const SizedBox(
                                height: AppSpacing.md),

                            /// PHONE
                            _label("Phone Number"),

                            AppInputField(
                              hint: "Enter phone number",
                              controller:
                                  _phoneController,
                              icon: Icons.phone_outlined,
                              keyboardType:
                                  TextInputType.phone,
                            ),

                            const SizedBox(
                                height: AppSpacing.md),

                            /// EMAIL
                            _label("Email Address"),

                            AppInputField(
                              hint: "Email address",
                              controller:
                                  _emailController,
                              icon: Icons.email_outlined,
                              enabled: false,
                            ),

                            const SizedBox(
                                height: AppSpacing.sm),

                            Text(
                              "Email cannot be changed for security reasons.",
                              style:
                                  AppTextStyles.small,
                            ),

                            const SizedBox(
                                height: AppSpacing.xl),

                            /// SAVE BUTTON
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed:
                                    _isSaving
                                        ? null
                                        : _save,
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.primary,
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child:
                                            CircularProgressIndicator(
                                          color:
                                              Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        "Save Changes",
                                        style:
                                            AppTextStyles
                                                .body
                                                .copyWith(
                                          color:
                                              Colors.white,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(
                                height: AppSpacing.lg),
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTextStyles.small.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}