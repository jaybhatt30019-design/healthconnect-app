import 'parent_signup_screen.dart';
import 'enter_pairing_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParentOptionsScreen extends StatelessWidget {
  const ParentOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE0F7FA),
              Color(0xFFFFF3E0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [

                const SizedBox(height: 10),

                /// Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          color: Colors.black.withOpacity(0.1),
                        )
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Color(0xFF004D40),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                /// Icon
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(35),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    size: 34,
                    color: Color(0xFF00796B),
                  ),
                ),

                const SizedBox(height: 25),

                /// Title
                Text(
                  "Welcome Parent",
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF004D40),
                  ),
                ),

                const SizedBox(height: 10),

               /// Subtitle
Text(
  "Choose how you'd like to continue",
  textAlign: TextAlign.center,
  style: GoogleFonts.poppins(
    fontSize: 14,
    color: const Color(0xFF546E7A),
  ),
),

const SizedBox(height: 60),

/// Pairing Code Button
buildOptionButton(
  icon: Icons.qr_code,
  text: "I Have a Pairing Code",
  onTap: () {

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnterPairingCodeScreen(),
      ),
    );

  },
),

const SizedBox(height: 20),

/// Parent Signup Button
buildOptionButton(
  icon: Icons.person_add,
  text: "Sign Up",
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ParentSignupScreen(),
      ),
    );
  },
),

                const Spacer(),

                /// Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF78909C),
                      ),
                    ),
                    Text(
                      "Sign In",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00796B),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// OPTION BUTTON UI
  Widget buildOptionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFB2DFDB),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [

            Icon(
              icon,
              color: const Color(0xFF00796B),
              size: 26,
            ),

            const SizedBox(width: 16),

            Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF004D40),
              ),
            ),

            const Spacer(),

            const Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Color(0xFF78909C),
            )
          ],
        ),
      ),
    );
  }
}