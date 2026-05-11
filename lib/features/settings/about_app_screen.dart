import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// HEADER
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "About App",
                      style: AppTextStyles.heading,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius:
                        BorderRadius.circular(AppRadius.md),
                    boxShadow: [AppShadows.light],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "HealthConnect",
                        style: AppTextStyles.heading,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      Text(
                        "HealthConnect is a healthcare assistance app designed for senior citizens and families. The app helps users manage medicines, health reminders, emergency contacts, and caregiver communication in one secure platform.",
                        style: AppTextStyles.body,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      Text(
                        "Version 1.0.0",
                        style: AppTextStyles.small,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}