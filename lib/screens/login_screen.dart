// lib/screens/login_screen.dart
// Fixes: loading state (#3), friendly errors (#7), removed print() (#2)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:healthconnect/screens/welcome_screen.dart';
import 'package:healthconnect/screens/add_parent_screen.dart';
import 'package:healthconnect/features/dashboard/main_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _hidePassword = true;
  // ✅ FIX #3 — loading state prevents double-tap
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ✅ FIX #7 — friendly error messages
  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack("Please enter your email and password.");
      return;
    }

    // ✅ FIX #3 — show loading, disable button
    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        _snack("Account not found. Please sign up.");
        return;
      }

      final data = doc.data()!;
      final role = data['role'] as String? ?? '';

      if (!mounted) return;

      if (role == 'caregiver') {
        final isLinked =
            data['parentLinked'] as bool? ?? false;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => isLinked
                ? const MainDashboard(isCaregiver: true)
                : const AddParentScreen(),
          ),
        );
      } else if (role == 'parent') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const MainDashboard(isCaregiver: false),
          ),
        );
      } else {
        _snack("Unknown account type. Contact support.");
      }
    } on FirebaseAuthException catch (e) {
      // ✅ FIX #7 — no raw Firebase messages shown
      _snack(_friendlyError(e.code));
    } catch (e) {
      // ✅ FIX #2 — no print(), uses debugPrint only
      debugPrint('[Login] Error: $e');
      _snack("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 24),
                      child: Stack(
                        children: [

                          // Back button
                          Positioned(
                            top: 10,
                            left: 0,
                            child: IconButton(
                              icon: const Icon(
                                  Icons.arrow_back_ios_new),
                              color:
                                  const Color(0xFF004D40),
                              onPressed: _isLoading
                                  ? null
                                  : () =>
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const WelcomeScreen(),
                                        ),
                                      ),
                            ),
                          ),

                          SizedBox(
                            height: constraints.maxHeight,
                            child: Center(
                              child: Column(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [

                                  // Logo
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                          0xFFE0F2F1),
                                      borderRadius:
                                          BorderRadius
                                              .circular(35),
                                    ),
                                    child: const Icon(
                                      Icons.favorite,
                                      size: 34,
                                      color: Color(
                                          0xFF00796B),
                                    ),
                                  ),

                                  const SizedBox(height: 25),

                                  Text(
                                    "Welcome Back",
                                    style:
                                        GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight:
                                          FontWeight.bold,
                                      color: const Color(
                                          0xFF004D40),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    "Login to continue",
                                    style:
                                        GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: const Color(
                                          0xFF546E7A),
                                    ),
                                  ),

                                  const SizedBox(height: 50),

                                  // Email field
                                  TextField(
                                    controller:
                                        emailController,
                                    keyboardType: TextInputType
                                        .emailAddress,
                                    enabled: !_isLoading,
                                    decoration:
                                        InputDecoration(
                                      hintText:
                                          "Email Address",
                                      prefixIcon:
                                          const Icon(
                                        Icons.email_outlined,
                                        color: Color(
                                            0xFF00796B),
                                      ),
                                      filled: true,
                                      fillColor:
                                          Colors.white,
                                      border:
                                          OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    16),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Password field
                                  TextField(
                                    controller:
                                        passwordController,
                                    obscureText:
                                        _hidePassword,
                                    enabled: !_isLoading,
                                    decoration:
                                        InputDecoration(
                                      hintText: "Password",
                                      prefixIcon:
                                          const Icon(
                                        Icons.lock_outline,
                                        color: Color(
                                            0xFF00796B),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _hidePassword
                                              ? Icons
                                                  .visibility_off
                                              : Icons
                                                  .visibility,
                                        ),
                                        onPressed: () =>
                                            setState(() =>
                                                _hidePassword =
                                                    !_hidePassword),
                                      ),
                                      filled: true,
                                      fillColor:
                                          Colors.white,
                                      border:
                                          OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    16),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 35),

                                  // ✅ Login button with
                                  // loading indicator
                                  SizedBox(
                                    width: double.infinity,
                                    height: 60,
                                    child: ElevatedButton(
                                      style: ElevatedButton
                                          .styleFrom(
                                        backgroundColor:
                                            const Color(
                                                0xFF00796B),
                                        disabledBackgroundColor:
                                            const Color(
                                                0xFF00796B)
                                                .withValues(
                                                    alpha:
                                                        0.6),
                                        shape:
                                            RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      30),
                                        ),
                                      ),
                                      // Disabled while loading
                                      onPressed: _isLoading
                                          ? null
                                          : _login,
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child:
                                                  CircularProgressIndicator(
                                                color: Colors
                                                    .white,
                                                strokeWidth:
                                                    2,
                                              ),
                                            )
                                          : Text(
                                              "Login",
                                              style: GoogleFonts
                                                  .poppins(
                                                color: Colors
                                                    .white,
                                                fontSize: 18,
                                                fontWeight:
                                                    FontWeight
                                                        .w600,
                                              ),
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}