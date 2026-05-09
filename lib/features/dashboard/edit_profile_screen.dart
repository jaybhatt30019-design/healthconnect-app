import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameController = TextEditingController(text: "John Doe");
  final ageController = TextEditingController(text: "65");
  final phoneController = TextEditingController(text: "+1 (555) 123-4567");
  final emailController = TextEditingController(text: "john.doe@email.com");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔙 Back Button
              AppBackButton(
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: AppSpacing.md),

              /// 🏷 Title
              Center(
                child: Text(
                  "Edit Profile",
                  style: AppTextStyles.heading,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              /// 🧾 Form Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: [AppShadows.light],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Name
                        Text("Name", style: AppTextStyles.subtitle),
                        const SizedBox(height: 6),
                        AppInputField(
                          hint: "Enter your name",
                          controller: nameController,
                        ),

                        const SizedBox(height: AppSpacing.md),

                        /// Age
                        Text("Age", style: AppTextStyles.subtitle),
                        const SizedBox(height: 6),
                        AppInputField(
                          hint: "Enter age",
                          controller: ageController,
                        ),

                        const SizedBox(height: AppSpacing.md),

                        /// Phone
                        Text("Phone", style: AppTextStyles.subtitle),
                        const SizedBox(height: 6),
                        AppInputField(
                          hint: "Enter phone number",
                          controller: phoneController,
                        ),

                        const SizedBox(height: AppSpacing.md),

                        /// Email
                        Text("Email", style: AppTextStyles.subtitle),
                        const SizedBox(height: 6),
                        AppInputField(
                          hint: "Enter email",
                          controller: emailController,
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        /// 💾 Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                            onPressed: () {
                              // TODO: Save logic
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Profile Updated"),
                                ),
                              );
                            },
                            child: Text(
                              "Save Changes",
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}