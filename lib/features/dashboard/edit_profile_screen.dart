// lib/features/dashboard/edit_profile_screen.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;

  File? _profileImage;
  String? _existingPhotoUrl;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text =
            data['name'] as String? ?? '';
        _ageController.text =
            data['age']?.toString() ?? '';
        _phoneController.text =
            data['phone'] as String? ?? '';
        _emailController.text =
            data['email'] as String? ??
                _auth.currentUser?.email ??
                '';
        _existingPhotoUrl =
            data['photoUrl'] as String?;
      }
    } catch (e) {
      debugPrint('[EditProfile] Load: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _profileImage = File(picked.path));
  }

  // ✅ Upload photo to Firebase Storage
  Future<String?> _uploadPhoto(File file) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      setState(() => _isUploadingPhoto = true);

      // Compress before upload
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
          tempDir.path, 'profile_$uid.jpg');

      final compressed = await FlutterImageCompress
          .compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 400,
        minHeight: 400,
      );

      final fileToUpload =
          compressed != null ? File(compressed.path) : file;

      // Upload
      final ref = _storage
          .ref()
          .child('profile_photos/$uid.jpg');

      final task = await ref.putFile(fileToUpload);
      final url = await task.ref.getDownloadURL();

      debugPrint(
          '[EditProfile] Photo uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('[EditProfile] Upload error: $e');
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _snack("Please enter your name");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // Upload new photo if selected
      String? photoUrl = _existingPhotoUrl;
      if (_profileImage != null) {
        final uploaded =
            await _uploadPhoto(_profileImage!);
        if (uploaded != null) photoUrl = uploaded;
      }

      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(uid)
          .set({
        'name': _nameController.text.trim(),
        'age': int.tryParse(
                _ageController.text.trim()) ??
            0,
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        if (photoUrl != null)
          'photoUrl': photoUrl,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      _snack("Profile updated");
      if (!mounted) return;
      // Return true so caller can refresh
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[EditProfile] Save: $e');
      _snack("Failed to save. Try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                  child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    AppBackButton(
                      onTap: () =>
                          Navigator.pop(context),
                    ),

                    const SizedBox(
                        height: AppSpacing.md),

                    Text("Edit Profile",
                        style: AppTextStyles.heading),

                    const SizedBox(
                        height: AppSpacing.lg),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            // ── Photo picker ──────
                            Center(
                              child: Stack(
                                children: [
                                  // Show selected file,
                                  // existing URL, or initials
                                  _buildAvatar(),

                                  // Camera button
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap:
                                          _isUploadingPhoto
                                              ? null
                                              : _pickImage,
                                      child: Container(
                                        padding:
                                            const EdgeInsets
                                                .all(8),
                                        decoration:
                                            const BoxDecoration(
                                          color: AppColors
                                              .primary,
                                          shape: BoxShape
                                              .circle,
                                        ),
                                        child:
                                            _isUploadingPhoto
                                                ? const SizedBox(
                                                    width:
                                                        20,
                                                    height:
                                                        20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: Colors
                                                          .white,
                                                      strokeWidth:
                                                          2,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons
                                                        .camera_alt,
                                                    color: Colors
                                                        .white,
                                                    size: 20,
                                                  ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(
                                height: AppSpacing.xl),

                            _label("Full Name"),
                            AppInputField(
                              hint: "Enter your full name",
                              controller:
                                  _nameController,
                              icon: Icons.person_outline,
                            ),

                            const SizedBox(
                                height: AppSpacing.md),

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
                              style: AppTextStyles.small,
                            ),

                            const SizedBox(
                                height: AppSpacing.xl),

                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed:
                                    _isSaving
                                        ? null
                                        : _save,
                                style:
                                    ElevatedButton
                                        .styleFrom(
                                  backgroundColor:
                                      AppColors.primary,
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                                AppRadius
                                                    .md),
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

  Widget _buildAvatar() {
    final name = _nameController.text.trim();
    final initials = name.isNotEmpty
        ? name
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    if (_profileImage != null) {
      return CircleAvatar(
        radius: 55,
        backgroundImage: FileImage(_profileImage!),
      );
    }

    if (_existingPhotoUrl != null &&
        _existingPhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 55,
        backgroundImage:
            NetworkImage(_existingPhotoUrl!),
        backgroundColor: AppColors.iconBg,
      );
    }

    return CircleAvatar(
      radius: 55,
      backgroundColor: AppColors.primary,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
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
            fontWeight: FontWeight.w600),
      ),
    );
  }
}