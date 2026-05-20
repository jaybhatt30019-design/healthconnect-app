// lib/screens/caregiver_signup_screen.dart
// Fix #2 — removed print() statements
// Fix #3 — added loading state
// Fix #7 — friendly error messages

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthconnect/screens/add_parent_screen.dart';

class CaregiverSignupScreen extends StatefulWidget {
  const CaregiverSignupScreen({super.key});

  @override
  State<CaregiverSignupScreen> createState() =>
      _CaregiverSignupScreenState();
}

class _CaregiverSignupScreenState
    extends State<CaregiverSignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isPasswordHidden = true;
  // ✅ FIX #3 — loading state
  bool _isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ✅ FIX #7 — friendly error messages
  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Sign up failed. Please try again.';
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signUp() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      _snack("Please fill all fields.");
      return;
    }

    // ✅ FIX #3 — show loading
    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: email, password: password);

      final uid = credential.user!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'caregiver',
        'parentLinked': false,
        'createdAt': Timestamp.now(),
      });

      // ✅ FIX #2 — no print()
      debugPrint('[CaregiverSignup] Created: $uid');

      if (!mounted) return;

      // Go straight to Add Parent screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => const AddParentScreen()),
      );
    } on FirebaseAuthException catch (e) {
      // ✅ FIX #7 — friendly message, not raw e.message
      _snack(_friendlyError(e.code));
    } catch (e) {
      debugPrint('[CaregiverSignup] Error: $e');
      _snack("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            color: Colors.black
                                .withValues(alpha: 0.1),
                          )
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Color(0xFF004D40)),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(Icons.favorite,
                        color: Color(0xFF00796B), size: 30),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Create Your\nCaregiver Account",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF004D40),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Join our community to provide care",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF546E7A)),
                  ),

                  const SizedBox(height: 40),

                  _buildInput(
                    icon: Icons.person_outline,
                    hint: "Full Name",
                    controller: nameController,
                  ),
                  const SizedBox(height: 16),
                  _buildInput(
                    icon: Icons.mail_outline,
                    hint: "Email Address",
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildInput(
                    icon: Icons.phone_outlined,
                    hint: "Phone Number",
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextField(
                    controller: passwordController,
                    obscureText: _isPasswordHidden,
                    enabled: !_isLoading,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      hintText: "Password",
                      hintStyle: GoogleFonts.poppins(
                          color: const Color(0xFFB0BEC5)),
                      prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF00796B)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordHidden
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFFCFD8DC),
                        ),
                        onPressed: () => setState(() =>
                            _isPasswordHidden =
                                !_isPasswordHidden),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFFB2DFDB),
                            width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFFB2DFDB),
                            width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFF00796B),
                            width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ✅ Create Account button with loading
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF00796B),
                        disabledBackgroundColor:
                            const Color(0xFF00796B)
                                .withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(30),
                        ),
                        elevation: 8,
                      ),
                      onPressed:
                          _isLoading ? null : _signUp,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "Create Account",
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

  Widget _buildInput({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !_isLoading,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
            color: const Color(0xFFB0BEC5)),
        prefixIcon:
            Icon(icon, color: const Color(0xFF00796B)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 20, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
              color: Color(0xFFB2DFDB), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
              color: Color(0xFFB2DFDB), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
              color: Color(0xFF00796B), width: 2),
        ),
      ),
    );
  }
}