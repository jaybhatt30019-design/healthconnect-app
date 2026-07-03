import 'package:flutter/material.dart';
import 'package:Vitanex/theme/app_design_system.dart';

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
Last updated: July 3, 2026

This Privacy Policy explains how Straventis Global Pvt Ltd ("Vitanex", "we", "us", or "our") collects, uses, shares, and protects your personal information when you use the Vitanex mobile application (the "App"). Vitanex helps families stay connected by linking a parent (senior) and a caregiver to share health and safety information.

By creating an account and using the App, you agree to the practices described in this policy. Please read it carefully. Because Vitanex handles health and location information, we treat your data with particular care.

1. Who we are
The App is operated by Straventis Global Pvt Ltd, a company registered in India. For the purposes of applicable data protection law, including India's Digital Personal Data Protection Act, 2023 (the "DPDP Act"), Straventis Global Pvt Ltd is the data fiduciary (data controller) responsible for your personal data.

If you have any questions about this policy or your data, contact us at support@vitanex.app.

2. Information we collect
We collect the following categories of information so the App can function:

Account information
When you register, we collect your name, email address, phone number, age, and your role (parent or caregiver). This is used to create and manage your account and to link paired accounts together.

Health information
Depending on how you use the App, we collect health-related information you enter, including medications and dosages, medication schedules and intake history, doctor appointments, prescribing doctor and hospital names, and details stored in your health passport. This is sensitive personal data and is used to provide medication reminders, appointment management, and health summaries to you and your paired family member.

Location information
With your permission, the App collects your device's location continuously, including while the App runs in the background. Location is used so a paired caregiver can see a parent's location for safety and emergency purposes. You can disable location access at any time through your device settings, though doing so will limit location-based features. We will request your explicit consent before enabling background location, as required by the Google Play Store and applicable law.

Emergency contacts
You may add the names and phone numbers of emergency contacts. These are third-party individuals; you are responsible for ensuring you have their permission to add their details. We use this information only to enable emergency calling and alerts.

Photos
You may choose to provide a profile photo or other images. These are stored to personalize your account and are not used for any other purpose.

Diagnostic and crash data
We collect crash reports and basic diagnostic information to detect, fix, and prevent technical problems and to keep the App stable and secure.

3. How we use your information
We use the information we collect to:

Create and manage your account and link paired parent and caregiver accounts;
Provide medication reminders, appointment management, and health summaries;
Enable emergency SOS calling and alerts to caregivers and emergency contacts;
Share a parent's location with their paired caregiver for safety;
Send notifications related to medications, appointments, and emergencies;
Diagnose technical issues, improve reliability, and maintain security;
Comply with our legal obligations.
4. Legal basis for processing
Under the DPDP Act and other applicable laws, we process your personal data on the basis of the consent you provide when you create an account, enable specific features (such as location), and enter health information. You may withdraw your consent at any time as described in the "Your rights" section below. Withdrawing consent may mean some or all features of the App can no longer function.

5. How we share your information
Vitanex is built around sharing health and safety information between a parent and their paired caregiver. The core sharing in the App works as follows:

Between paired accounts: Medication data, appointments, health summaries, location, and emergency alerts are shared between the parent and the caregiver who are linked through a pairing code.
We also rely on trusted third-party service providers to operate the App. These providers process data on our behalf and are bound by their own privacy and security obligations:

Google Firebase (authentication, database, cloud functions, messaging, and crash reporting) — stores your account and health data and delivers notifications;
Google Maps — provides mapping and location display;
Agora — provides real-time audio and video for emergency calls.
We do not sell your personal data, and we do not share it with advertisers. We may disclose information if required to do so by law, or to protect the rights, safety, or property of our users or the public.

6. International data transfers
Some of our service providers, including Google and Agora, may store and process data on servers located outside India. Where this happens, we take steps to ensure your data continues to be protected in line with this policy and applicable law.

7. Data retention
We keep your personal data for as long as your account is active and as needed to provide the App's features. If you ask us to delete your account, we will delete or anonymize your personal data within a reasonable period, except where we are required to retain certain information to comply with legal obligations.

8. Your rights
Subject to applicable law, including the DPDP Act, you have the right to:

Access the personal data we hold about you;
Correct or update inaccurate or incomplete data;
Request deletion of your personal data and your account;
Withdraw consent you have previously given;
Raise a grievance about how we handle your data.
To exercise any of these rights, or to request account and data deletion, email us at support@vitanex.app. We will respond within a reasonable timeframe.

9. Data security
We use reasonable technical and organizational measures to protect your personal data against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission or storage is completely secure, and we cannot guarantee absolute security.

10. Children's privacy
The App is intended for use by adults aged 18 and over and is not directed at children. We do not knowingly collect personal data from children. If you believe a child has provided us with personal data, please contact us so we can remove it.

11. Changes to this policy
We may update this Privacy Policy from time to time. When we make material changes, we will update the "Last updated" date at the top of this page and, where appropriate, notify you within the App. Your continued use of the App after changes take effect means you accept the updated policy.

12. Contact us
If you have questions, concerns, or grievances about this Privacy Policy or your personal data, please contact:

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