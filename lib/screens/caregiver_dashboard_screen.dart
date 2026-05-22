import 'add_parent_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CaregiverDashboardScreen extends StatelessWidget {
  final String userName;

  const CaregiverDashboardScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,

        /// Same gradient across screens
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0F7FA), // Light teal
              Color(0xFFFFF3E0), // Light orange
            ],
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),

            child: Column(
              children: [

                /// Space on top
                const SizedBox(height: 10),

                /// Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [

                    /// Welcome text
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          "Welcome,",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: const Color(0xFF546E7A),
                          ),
                        ),

                        Text(
                          userName,
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF004D40),
                          ),
                        ),
                      ],
                    ),

                    /// Dummy Avatar
                    const CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(
                        "https://i.pravatar.cc/150?img=12",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                /// Image
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    image: const DecorationImage(
                      fit: BoxFit.cover,
                      image: NetworkImage(
                        "https://images.unsplash.com/photo-1584515933487-779824d29309",
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                /// Title
                Text(
                  "No Parents Connected Yet",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF004D40),
                  ),
                ),

                const SizedBox(height: 10),

                /// Subtitle
                Text(
                  "Connect with someone you want to care for. Add parent information to get alerts.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF546E7A),
                  ),
                ),

                const Spacer(),

                /// Add Parent Button
                SizedBox(
  width: double.infinity,
  height: 60,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF00796B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      elevation: 8,
    ),
onPressed: () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => const AddParentScreen(),
    ),
  );
},
    child: Text(
      "Add Parent / Senior",
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  ),
),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}