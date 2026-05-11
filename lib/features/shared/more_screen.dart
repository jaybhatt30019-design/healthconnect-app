import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:healthconnect/features/dashboard/edit_profile_screen.dart';
import 'package:healthconnect/screens/welcome_screen.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/features/settings/about_app_screen.dart';
import 'package:healthconnect/features/settings/privacy_policy_screen.dart';
import 'package:healthconnect/features/settings/terms_conditions_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final uid = _auth.currentUser?.uid;

      if (uid == null) return;

      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      debugPrint("Error loading user: $e");
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const WelcomeScreen(),
      ),
      (route) => false,
    );
  }

 Future<void> _resetPassword() async {
  try {
    final user = _auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User not logged in"),
        ),
      );
      return;
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No email found for this account"),
        ),
      );
      return;
    }

    /// SEND RESET EMAIL
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: email,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Password Reset"),
        content: Text(
          "A password reset link has been sent to:\n\n$email",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  } on FirebaseAuthException catch (e) {
    String message = "Something went wrong";

    switch (e.code) {
      case 'invalid-email':
        message = "Invalid email address";
        break;

      case 'user-not-found':
        message = "User not found";
        break;

      case 'too-many-requests':
        message = "Too many requests. Try again later.";
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Settings",
                          style: AppTextStyles.heading,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              /// PROFILE CARD
                              _card(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Profile",
                                      style: AppTextStyles.body,
                                    ),

                                    const SizedBox(height: AppSpacing.md),

                                    _profileItem(
                                      "Name",
                                      userData?['name'] ?? "Not Available",
                                    ),

                                    _profileItem(
                                      "Age",
                                      "${userData?['age'] ?? '-'} ",
                                    ),

                                    _profileItem(
                                      "Phone",
                                      userData?['phone'] ?? "Not Available",
                                    ),

                                    _profileItem(
                                      "Email",
                                      userData?['email'] ??
                                          _auth.currentUser?.email ??
                                          "",
                                    ),

                                    const SizedBox(height: AppSpacing.md),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.iconBg,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                              AppRadius.md,
                                            ),
                                          ),
                                        ),
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const EditProfileScreen(),
                                            ),
                                          );

                                          _loadUser();
                                        },
                                        icon: const Icon(
                                          Icons.edit,
                                          color: AppColors.accent,
                                        ),
                                        label: Text(
                                          "Edit Profile",
                                          style: AppTextStyles.body.copyWith(
                                            color: AppColors.accent,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: AppSpacing.lg),

                              /// ACCOUNT SETTINGS
                              _card(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Account Settings",
                                      style: AppTextStyles.body,
                                    ),

                                    const SizedBox(height: AppSpacing.md),

                                    _tile(
                                      icon: Icons.lock_outline,
                                      text: "Change Password",
                                      onTap: _resetPassword,
                                    ),

                                    const Divider(),

                                    _tile(
                                      icon: Icons.logout,
                                      text: "Logout",
                                      color: Colors.red,
                                      onTap: _logout,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: AppSpacing.lg),

                              /// APP INFO
                              _card(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "App Info",
                                      style: AppTextStyles.body,
                                    ),

                                    const SizedBox(height: AppSpacing.md),

                                    _tile(
                                      icon: Icons.info_outline,
                                      text: "About App",
                                       onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AboutAppScreen(),
      ),
    );
  },
                                    ),

                                    const Divider(),

                                    _tile(
                                      icon:
                                          Icons.privacy_tip_outlined,
                                      text: "Privacy Policy",
                                      onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  },
                                    ),

                                    const Divider(),

                                    _tile(
                                      icon:
                                          Icons.description_outlined,
                                      text: "Terms & Conditions",
                                      onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TermsConditionsScreen(),
      ),
    );
  },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: AppSpacing.xl),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.light],
      ),
      child: child,
    );
  }

  Widget _profileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.small),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String text,
    Color color = AppColors.darkPrimary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        text,
        style: AppTextStyles.body.copyWith(color: color),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}