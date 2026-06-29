// lib/screens/parent_signup_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthconnect/features/dashboard/main_dashboard.dart';
import 'package:healthconnect/core/services/social_auth_service.dart';
import 'package:healthconnect/widgets/social_buttons.dart';

class ParentSignupScreen extends StatefulWidget {
  const ParentSignupScreen({super.key});

  @override
  State<ParentSignupScreen> createState() =>
      _ParentSignupScreenState();
}

class _ParentSignupScreenState
    extends State<ParentSignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _socialAuth = SocialAuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

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

  void _snack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isSuccess ? const Color(0xFF00796B) : null,
    ));
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const MainDashboard(isCaregiver: false),
      ),
    );
  }

  // ── Email signup ──────────────────────────────────
  Future<void> _signUp() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      _snack("Please fill all fields.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Declare credential as a local variable
      UserCredential credential;

      try {
        credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: email, password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Account exists — sign in instead
          try {
            credential = await FirebaseAuth.instance
                .signInWithEmailAndPassword(
                    email: email, password: password);
            _snack("Account already exists. Logging you in.",
                isSuccess: true);
          } on FirebaseAuthException catch (signInErr) {
            _snack(_friendlyError(signInErr.code));
            return;
          }
        } else {
          _snack(_friendlyError(e.code));
          return;
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'parent',
        'createdAt': Timestamp.now(),
      });

      _goToDashboard();
    } on FirebaseAuthException catch (e) {
      _snack(_friendlyError(e.code));
    } catch (e) {
      //debugPrint('[ParentSignup] Error: $e');
      _snack("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google signup ─────────────────────────────────
  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);

    final response = await _socialAuth.signInWithGoogle();

    if (!mounted) return;

    switch (response.result) {
      case SocialAuthResult.cancelled:
        setState(() => _isLoading = false);
        return;

      case SocialAuthResult.error:
        _snack(response.errorMessage ??
            'Google sign in failed.');
        setState(() => _isLoading = false);
        return;

      case SocialAuthResult.success:
        // ✅ Account already exists — just redirect
        if (response.role != null) {
          _snack("Account found. Logging you in.",
              isSuccess: true);
          _goToDashboard();
          return;
        }

        // ✅ New user — create Firestore doc as parent
        await _socialAuth.createUserDoc(
          uid: response.uid!,
          name: response.displayName ?? 'Parent',
          email: response.email ?? '',
          role: 'parent',
        );
        _goToDashboard();
        return;

      case SocialAuthResult.userNotFound:
        setState(() => _isLoading = false);
        return;
    }
  }

  // ── Apple signup ──────────────────────────────────
  Future<void> _signUpWithApple() async {
    setState(() => _isLoading = true);

    final response = await _socialAuth.signInWithApple();

    if (!mounted) return;

    switch (response.result) {
      case SocialAuthResult.cancelled:
        setState(() => _isLoading = false);
        return;

      case SocialAuthResult.error:
        _snack(response.errorMessage ??
            'Apple sign in failed.');
        setState(() => _isLoading = false);
        return;

      case SocialAuthResult.success:
        if (response.role != null) {
          _snack("Account found. Logging you in.",
              isSuccess: true);
          _goToDashboard();
          return;
        }

        await _socialAuth.createUserDoc(
          uid: response.uid!,
          name: response.displayName ?? 'Parent',
          email: response.email ?? '',
          role: 'parent',
        );
        _goToDashboard();
        return;

      case SocialAuthResult.userNotFound:
        setState(() => _isLoading = false);
        return;
    }
  }

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 24),
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
                          : () =>
                              Navigator.pop(context),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius:
                        BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.favorite,
                      color: Color(0xFF00796B),
                      size: 30),
                ),

                const SizedBox(height: 20),

                Text(
                  "Create Parent Account",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF004D40),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Join to monitor your loved one's health",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF546E7A)),
                ),

                const SizedBox(height: 30),

                // ✅ Google + Apple at top
                SocialButtons(
                  isLoading: _isLoading,
                  onGoogle: _signUpWithGoogle,
                  onApple: _signUpWithApple,
                ),

                const SizedBox(height: 20),

                // Divider for email section
                Row(children: [
                  Expanded(
                      child: Container(
                          height: 1,
                          color:
                              const Color(0xFFE0E0E0))),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14),
                    child: Text("or sign up with email",
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color:
                                const Color(0xFF90A4AE))),
                  ),
                  Expanded(
                      child: Container(
                          height: 1,
                          color:
                              const Color(0xFFE0E0E0))),
                ]),

                const SizedBox(height: 20),

                _buildInput(
                    icon: Icons.person_outline,
                    hint: "Full Name",
                    controller: _nameCtrl),
                const SizedBox(height: 16),
                _buildInput(
                    icon: Icons.mail_outline,
                    hint: "Email Address",
                    controller: _emailCtrl,
                    keyboardType:
                        TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildInput(
                    icon: Icons.phone_outlined,
                    hint: "Phone Number",
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 16),

                // Password
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  enabled: !_isLoading,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: "Password",
                    hintStyle: GoogleFonts.poppins(
                        color:
                            const Color(0xFF90A4AE)),
                    prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF00796B)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                          color: const Color(0xFF90A4AE)),
                      onPressed: () => setState(() =>
                          _obscurePassword =
                              !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 16),
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

                // Create account button
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
                              BorderRadius.circular(
                                  30)),
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
                                    strokeWidth: 2))
                        : Text("Create Account",
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w600,
                                color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 40),
              ],
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
            color: const Color(0xFF90A4AE)),
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