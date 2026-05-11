import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Privacy Policy",
                      style: AppTextStyles.heading,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        boxShadow: [AppShadows.light],
                      ),
                      child: Text(
                        '''
We value your privacy.

HealthConnect collects only the necessary information required to provide healthcare-related services and reminders.

Your data is securely stored and is never sold to third parties.

We may collect:
• Name
• Email address
• Phone number
• Health-related reminders
• Emergency contact information

By using the app, you agree to the collection and use of information according to this policy.
                        ''',
                        style: AppTextStyles.body,
                      ),
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
}