import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/role_card.dart';
import 'caregiver_signup_screen.dart';
import 'login_screen.dart';
import 'parent_options_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundStart,
              AppColors.backgroundEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // const Icon(Icons.favorite, size: 80, color: AppColors.primary),
                

                Image.asset("assets/images/logovitanex.png", height: 80, width:80, ),
                // const SizedBox(height: 20),
                // const Text(
                //   "Vitanex",
                //   style: TextStyle(
                //     fontSize: 32,
                //     fontWeight: FontWeight.bold,
                //     color: AppColors.textDark,
                //   ),
                // ),
                const SizedBox(height: 10),
                const Text(
                  "Welcome, please select your role",
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 40),

                /// Senior Button
                RoleCard(
                  icon: Icons.elderly,
                  title: "I am a Senior / Parent",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ParentOptionsScreen(),
                      ),
                    );
                  },
                ),

                /// Caregiver Button
                RoleCard(
                  icon: Icons.favorite_outline,
                  title: "I am a Caregiver / Child",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CaregiverSignupScreen(),
                      ),
                    );
                  },
                ),

                const Spacer(),

Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    const Text(
      "Already have an account? ",
      style: TextStyle(
        fontSize: 16,
        color: AppColors.textLight,
      ),
    ),
    GestureDetector(
      onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const LoginScreen(),
    ),
  );
},
      child: const Text(
        "Log in",
        style: TextStyle(
          fontSize: 16,
          color: Color(0xFF0F6F5E),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ],
),

const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}