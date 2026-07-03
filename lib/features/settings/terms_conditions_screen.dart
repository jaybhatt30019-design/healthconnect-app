import 'package:flutter/material.dart';
import 'package:Vitanex/theme/app_design_system.dart';

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
Last updated: July 3, 2026

These Terms & Conditions ("Terms") govern your access to and use of the Vitanex mobile application (the "App"), operated by Straventis Global Pvt Ltd ("Vitanex", "we", "us", or "our"). By downloading, accessing, or using the App, you agree to be bound by these Terms. If you do not agree, please do not use the App.

1. Eligibility
You must be at least 18 years old to create an account and use the App. By using the App, you confirm that you are 18 or older and that the information you provide is accurate and complete.

2. What Vitanex is
Vitanex is a family health organization tool that links a parent (senior) and a caregiver so they can share health and safety information. Features include medication reminders, appointment management, health summaries, a health passport, emergency SOS and calling, and location sharing between paired accounts.

3. Not a medical service
Vitanex is an organizational and reminder tool only. It does not provide medical advice, diagnosis, or treatment, and it is not a substitute for professional medical care. Any information in the App is for your convenience and should never replace the guidance of a qualified doctor or healthcare provider. Always consult a licensed medical professional for decisions about medications, treatment, or health. You are responsible for the accuracy of the health information you enter, including medication names, dosages, and schedules.

4. Emergency features — important limitations
The App includes emergency SOS, emergency calling, and location-sharing features intended to help you reach a caregiver or contact in an urgent situation. You must understand and accept the following:

Vitanex is not an emergency service and is not a replacement for official emergency services such as 108, 112, or your local emergency number. In a real emergency, always contact official emergency services directly.
We do not guarantee that an SOS alert, emergency call, or location update will always be delivered, received, or delivered on time. Delivery depends on factors outside our control, including your device, battery level, internet or mobile network connectivity, operating system behavior, and device manufacturer power-saving or background-app restrictions.
You should not rely on the App as your only means of getting help in an emergency.
To the fullest extent permitted by law, we are not liable for any failure, delay, or error in delivering emergency alerts, calls, or location information.

5. Accounts and pairing
To use the App you must create an account and keep your login details confidential. You are responsible for all activity under your account. Vitanex links a parent and a caregiver through a pairing code; by pairing, you agree that health, location, and related information will be shared between the linked accounts, as described in our Privacy Policy. You must have the consent of any third party (such as an emergency contact) whose details you add to the App.

6. Acceptable use
You agree not to:

Use the App for any unlawful purpose or in violation of these Terms;
Enter false, misleading, or harmful information;
Attempt to access accounts or data that are not yours;
Interfere with, disrupt, reverse-engineer, or attempt to gain unauthorized access to the App or its systems;
Use the App to harass, harm, or impersonate another person.
7. Pricing and paid features
The App is currently free to download and free to use. We intend to introduce paid features in the future, which may be offered as a yearly subscription. If and when we introduce paid features, we will provide clear pricing and updated terms before you are charged, and any payment will be subject to your consent. We will not charge you for paid features without your agreement.

8. Intellectual property
The App, including its design, features, logos, and content we provide, is owned by Straventis Global Pvt Ltd and protected by applicable laws. We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for your personal, non-commercial use. You retain ownership of the information you enter into the App.

9. Third-party services
The App relies on third-party services, including Google Firebase, Google Maps, and Agora, to function. Your use of the App may also be subject to those providers' terms. We are not responsible for the acts, omissions, or content of third-party services.

10. Availability and changes
We aim to keep the App available and working, but we do not guarantee uninterrupted or error-free operation. We may modify, suspend, or discontinue any part of the App at any time. We may also update these Terms from time to time; when we make material changes, we will update the "Last updated" date above and, where appropriate, notify you in the App. Continued use of the App after changes take effect means you accept the updated Terms.

11. Termination
You may stop using the App and request deletion of your account at any time by contacting us at support@vitanex.app. We may suspend or terminate your access if you violate these Terms or use the App in a way that could harm other users, us, or third parties.

12. Disclaimer of warranties
To the fullest extent permitted by law, the App is provided on an "as is" and "as available" basis, without warranties of any kind, whether express or implied, including but not limited to fitness for a particular purpose, reliability, or availability. We do not warrant that the App will meet your requirements or that it will be secure, timely, or error-free.

13. Limitation of liability
To the fullest extent permitted by law, Straventis Global Pvt Ltd and its directors, employees, and partners will not be liable for any indirect, incidental, special, consequential, or punitive damages, or for any loss of data, health outcomes, missed medications or appointments, or failure or delay of emergency features, arising out of or related to your use of, or inability to use, the App. Nothing in these Terms excludes liability that cannot be excluded under applicable law.

14. Indemnity
You agree to indemnify and hold harmless Straventis Global Pvt Ltd from any claims, damages, losses, or expenses arising from your misuse of the App, your violation of these Terms, or your violation of the rights of any third party.

15. Governing law and jurisdiction
These Terms are governed by the laws of India. Any disputes arising out of or in connection with these Terms or the App shall be subject to the exclusive jurisdiction of the courts of Ahmedabad, Gujarat, India.

16. Contact us
If you have questions about these Terms, please contact:

Straventis Global Pvt Ltd
Email: support@vitanex.app
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