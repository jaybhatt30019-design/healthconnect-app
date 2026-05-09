import 'pairing_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddParentScreen extends StatefulWidget {
  const AddParentScreen({super.key});

  @override
  State<AddParentScreen> createState() => _AddParentScreenState();
}

class _AddParentScreenState extends State<AddParentScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController relationController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    relationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,

        /// SAME GRADIENT AS SIGNUP
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),

              child: Column(
                children: [

                  const SizedBox(height: 10),

                  /// BACK BUTTON
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

                  const SizedBox(height: 20),

                  /// ICON
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.elderly,
                      color: Color(0xFF00796B),
                      size: 30,
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// TITLE
                  Text(
                    "Add Parent",
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF004D40),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Add your parent details to connect",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF546E7A),
                    ),
                  ),

                  const SizedBox(height: 40),

                  /// NAME
                  buildInput(
                    icon: Icons.person_outline,
                    hint: "Parent Name",
                    controller: nameController,
                  ),

                  const SizedBox(height: 16),

                  /// AGE
                  buildInput(
                    icon: Icons.cake_outlined,
                    hint: "Age",
                    controller: ageController,
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 16),

                  /// PHONE
                  buildInput(
                    icon: Icons.phone_outlined,
                    hint: "Phone Number",
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 16),

                  /// RELATION
                  buildInput(
                    icon: Icons.family_restroom,
                    hint: "Relation (Father / Mother)",
                    controller: relationController,
                  ),

                  const SizedBox(height: 30),

                  /// Generate Pairing Code Button
Container(
  width: double.infinity,
  height: 60,
  decoration: BoxDecoration(
    color: const Color(0xFF00796B),
    borderRadius: BorderRadius.circular(30),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF00796B).withOpacity(0.3),
        blurRadius: 20,
        offset: const Offset(0, 10),
      )
    ],
  ),
  child: TextButton(
onPressed: () async {
  final name = nameController.text.trim();
  final age = ageController.text.trim();
  final phone = phoneController.text.trim();
  final relation = relationController.text.trim();

  if (name.isEmpty || age.isEmpty || phone.isEmpty || relation.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please fill all fields")),
    );
    return;
  }

  try {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    /// 🔥 Generate Code
    final random = Random();
    String pairingCode = "HC-${100000 + random.nextInt(900000)}";

    /// 🔥 Save Parent Info + Code in Firestore
    final parentRef = FirebaseFirestore.instance.collection('parents').doc();

await parentRef.set({
  'caregiverId': uid,
  'name': name,
  'age': age,
  'phone': phone,
  'relation': relation,
});

    await FirebaseFirestore.instance
    .collection('pairing_codes')
    .doc(pairingCode)
    .set({
  'caregiverId': uid,
  'parentId': parentRef.id,
  'isUsed': false,
});

    /// 🔥 Update caregiver document
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'pairingCode': pairingCode,
      'parentLinked': false,
    });

    /// ✅ Navigate to next screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PairingCodeScreen(
          pairingCode: pairingCode,
          parentName: name,
        ),
      ),
    );

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }
},
    child: Text(
      "Generate Pairing Code",
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  ),
),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// REUSABLE INPUT FIELD
  Widget buildInput({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFFB0BEC5),
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF00796B),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFB2DFDB),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFB2DFDB),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF00796B),
            width: 2,
          ),
        ),
      ),
    );
  }
}