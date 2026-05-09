import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import 'package:healthconnect/features/parent/parent_home.dart';

class EnterPairingCodeScreen extends StatefulWidget {
  const EnterPairingCodeScreen({super.key});

  @override
  State<EnterPairingCodeScreen> createState() => _EnterPairingCodeScreenState();
}

class _EnterPairingCodeScreenState extends State<EnterPairingCodeScreen> {

  final TextEditingController codeController = TextEditingController();

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  // 🔥 MAIN FUNCTION
  Future<void> connectWithCode(BuildContext context) async {
    final code = codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter pairing code")),
      );
      return;
    }

    try {
      print("Checking code: $code");

      // 🔍 Find pairing code in Firestore
      final doc = await FirebaseFirestore.instance
          .collection('pairing_codes')
          .doc(code)
          .get();

      if (!doc.exists) {
        throw Exception("Invalid pairing code");
      }

      final data = doc.data()!;

      // ❌ Already used?
      if (data['isUsed'] == true) {
        throw Exception("Code already used");
      }

      final caregiverId = data['caregiverId'];

      // 🔥 LINK PARENT → CAREGIVER
     final parentId = data['parentId'];

final parentDoc = await FirebaseFirestore.instance
    .collection('parents')
    .doc(parentId)
    .get();

if (!parentDoc.exists) {
  throw Exception("Parent data not found");
}

final parentData = parentDoc.data()!;

      // 🔥 MARK CODE AS USED
      await FirebaseFirestore.instance
          .collection('pairing_codes')
          .doc(code)
          .update({
        'isUsed': true,
      });

      // 🔥 UPDATE CAREGIVER
      await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverId)
          .update({
        'parentLinked': true,
      });

      print("Connected successfully");

      // ✅ Redirect to Parent Dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParentHome(
            parentData: parentData,
          ),
        ),
      );

    } catch (e) {
      print("ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.backgroundStart,
              AppColors.backgroundEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  onPressed: () => Navigator.pop(context),
                ),

                const SizedBox(height: 20),

                Text(
                  "Enter Pairing Code",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "Enter the code shared by your child to connect.",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: AppColors.textLight,
                  ),
                ),

                const SizedBox(height: 40),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),

                  child: TextField(
                    controller: codeController,
                    textAlign: TextAlign.center,

                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: AppColors.primary,
                    ),

                    decoration: InputDecoration(
                      hintText: "HC-123456",
                      border: InputBorder.none,
                    ),
                  ),
                ),

                const Spacer(),

                PrimaryButton(
                  text: "Connect",
                  onPressed: () => connectWithCode(context),
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