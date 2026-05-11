import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
                      "Terms & Conditions",
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
By using HealthConnect, you agree to the following terms:

• The app is intended for informational and reminder purposes only.
• HealthConnect does not replace professional medical advice.
• Users are responsible for maintaining accurate medical information.
• We are not liable for missed medicines or incorrect user-entered data.
• Unauthorized use of the app is prohibited.

Continued use of the app indicates acceptance of these terms.
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