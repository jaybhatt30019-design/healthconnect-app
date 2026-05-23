import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../widgets/app_gradient.dart';
import '../widgets/primary_button.dart';

class PairingCodeScreen extends StatelessWidget {
  final String pairingCode;
  final String parentName;

  const PairingCodeScreen({
    super.key,
    required this.pairingCode,
    required this.parentName,
  });

  String get _shareMessage =>
      'Hi $parentName! Here is your pairing code: $pairingCode. It expires in 24 hours.';

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final encoded = Uri.encodeComponent(_shareMessage);
    final uri = Uri.parse('https://wa.me/?text=$encoded');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("WhatsApp is not installed.")),
        );
      }
    }
  }

  Future<void> _shareViaSMS(BuildContext context) async {
    final encoded = Uri.encodeComponent(_shareMessage);
    final uri = Uri.parse('sms:?body=$encoded');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open SMS app.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradient(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [

                /// HEADER
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.textDark,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Text(
                      "Pairing Code",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                /// CODE CARD
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    children: [

                      Text(
                        "Your Connection Code",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppColors.textLight,
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// PAIRING CODE
                      Text(
                        pairingCode,
                        style: GoogleFonts.poppins(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),

                      const SizedBox(height: 14),

                      /// EXPIRY BADGE
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundStart,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Code expires in 24 hours",
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                /// DESCRIPTION
                Text(
                  "Share this code with $parentName.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: AppColors.textDark,
                  ),
                ),

                const Spacer(),

                /// WHATSAPP BUTTON
                PrimaryButton(
                  text: "Share via WhatsApp",
                  onPressed: () => _shareViaWhatsApp(context),
                ),

                const SizedBox(height: 16),

                /// SMS BUTTON
                OutlinedButton.icon(
                  icon: const Icon(Icons.sms, color: AppColors.primary),
                  label: const Text(
                    "Share via SMS",
                    style: TextStyle(color: AppColors.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => _shareViaSMS(context),
                ),

                const SizedBox(height: 20),

                /// COPY BUTTON
                TextButton.icon(
                  icon: const Icon(Icons.copy, color: AppColors.primary),
                  label: const Text(
                    "Copy Code",
                    style: TextStyle(color: AppColors.primary),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pairingCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Code copied")),
                    );
                  },
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}