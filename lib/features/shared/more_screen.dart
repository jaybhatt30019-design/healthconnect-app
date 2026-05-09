import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/features/dashboard/edit_profile_screen.dart';
import 'package:healthconnect/screens/welcome_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              /// 🔙 HEADER
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
                      /// ================= PROFILE CARD =================
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Profile", style: AppTextStyles.body),

                            const SizedBox(height: AppSpacing.md),

                            _profileItem("Name", "John Doe"),
                            _profileItem("Age", "65 years"),
                            _profileItem("Phone", "+1 (555) 123-4567"),
                            _profileItem("Email", "john.doe@email.com"),

                            const SizedBox(height: AppSpacing.md),

                            /// EDIT BUTTON
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.iconBg,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.md),
                                  ),
                                ),
                                onPressed: () { 
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditProfileScreen(),
                                    ),
                                  );
                                  },
                                icon: const Icon(Icons.edit,
                                    color: AppColors.accent),
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

                      /// ================= ACCOUNT =================
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Account Settings",
                                style: AppTextStyles.body),

                            const SizedBox(height: AppSpacing.md),

                            _tile(
                              icon: Icons.lock_outline,
                              text: "Change Password",
                              onTap: () {},
                            ),

                            const Divider(),

                            _tile(
                              icon: Icons.logout,
                              text: "Logout",
                              color: Colors.red,
                              onTap: () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const WelcomeScreen(),
                                  ),
                                  (route) => false, // 🔥 removes all previous screens
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      /// ================= APP INFO =================
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("App Info", style: AppTextStyles.body),

                            const SizedBox(height: AppSpacing.md),

                            _tile(
                              icon: Icons.info_outline,
                              text: "About App",
                              onTap: () {},
                            ),

                            const Divider(),

                            _tile(
                              icon: Icons.privacy_tip_outlined,
                              text: "Privacy Policy",
                              onTap: () {},
                            ),

                            const Divider(),

                            _tile(
                              icon: Icons.description_outlined,
                              text: "Terms & Conditions",
                              onTap: () {},
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
    );
  }

  /// ================= CARD =================
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

  /// ================= PROFILE ITEM =================
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

  /// ================= LIST TILE =================
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