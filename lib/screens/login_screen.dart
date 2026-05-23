// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:healthconnect/screens/welcome_screen.dart';
import 'package:healthconnect/screens/add_parent_screen.dart';
import 'package:healthconnect/features/dashboard/main_dashboard.dart';
import 'package:healthconnect/core/services/social_auth_service.dart';
import 'package:healthconnect/widgets/social_buttons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _socialAuth = SocialAuthService();

  bool _hidePassword = true;
  bool _isLoading = false;
  bool _isResetting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

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

  void _snack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isSuccess ? const Color(0xFF00796B) : null,
      ),
    );
  }

  // ── Redirect based on role ────────────────────────
  void _redirectByRole(
      String role, Map<String, dynamic> data) {
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
  }

  // ── Email + password login ────────────────────────
  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack("Please enter your email and password.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: email, password: password);

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!doc.exists) {
        _snack("Account not found. Please sign up.");
        return;
      }

      final data = doc.data()!;
      _redirectByRole(
          data['role'] as String? ?? '', data);
    } on FirebaseAuthException catch (e) {
      _snack(_friendlyError(e.code));
    } catch (e) {
      debugPrint('[Login] Error: $e');
      _snack("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google login ──────────────────────────────────
  Future<void> _loginWithGoogle() async {
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
        // ✅ role is null → new user, no Firestore doc
        if (response.role == null) {
          // Sign out — they need to sign up first
          await _socialAuth.signOut();
          setState(() => _isLoading = false);
          _snack(
            "No account found. Please sign up first "
            "by selecting your role on the welcome screen.",
          );
          return;
        }

        // ✅ Existing user → fetch full doc and redirect
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(response.uid)
            .get();
        _redirectByRole(response.role!, doc.data()!);
        return;

      case SocialAuthResult.userNotFound:
        setState(() => _isLoading = false);
        return;
    }
  }

  // ── Apple login ───────────────────────────────────
  Future<void> _loginWithApple() async {
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
        if (response.role == null) {
          await _socialAuth.signOut();
          setState(() => _isLoading = false);
          _snack(
            "No account found. Please sign up first "
            "by selecting your role on the welcome screen.",
          );
          return;
        }
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(response.uid)
            .get();
        _redirectByRole(response.role!, doc.data()!);
        return;

      case SocialAuthResult.userNotFound:
        setState(() => _isLoading = false);
        return;
    }
  }

  // ── Forgot password ───────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty) {
      await _sendResetEmail(email);
    } else {
      await _showForgotPasswordDialog();
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.lock_reset,
              color: Color(0xFF00796B)),
          const SizedBox(width: 10),
          Text("Forgot Password",
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF004D40))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Enter your email to receive a reset link.",
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF546E7A)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Email Address",
                prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF00796B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF00796B),
                        width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel",
                style: GoogleFonts.poppins(
                    color: const Color(0xFF546E7A))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final email = ctrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(context);
              await _sendResetEmail(email);
            },
            child: Text("Send Reset Link",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendResetEmail(String email) async {
    setState(() => _isResetting = true);
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);
      _snack(
          "Reset link sent to $email. Check your inbox.",
          isSuccess: true);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _snack("No account found with this email.");
          break;
        case 'invalid-email':
          _snack("Please enter a valid email address.");
          break;
        default:
          _snack("Could not send reset email. Try again.");
      }
    } catch (e) {
      _snack("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _isResetting = false);
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                        Icons.arrow_back_ios_new),
                    color: const Color(0xFF004D40),
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

                const SizedBox(height: 20),

                // Logo
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius:
                        BorderRadius.circular(35),
                  ),
                  child: const Icon(Icons.favorite,
                      size: 34,
                      color: Color(0xFF00796B)),
                ),

                const SizedBox(height: 25),

                Text(
                  "Welcome Back",
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF004D40),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "Login to continue",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF546E7A),
                  ),
                ),

                const SizedBox(height: 40),

                // Email field
                _field(
                  controller: _emailCtrl,
                  hint: "Email Address",
                  icon: Icons.email_outlined,
                  keyboardType:
                      TextInputType.emailAddress,
                ),

                const SizedBox(height: 16),

                // Password field
                _passwordField(),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : _forgotPassword,
                    style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8)),
                    child: _isResetting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00796B),
                            ),
                          )
                        : Text(
                            "Forgot Password?",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(
                                  0xFF00796B),
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 8),

                // Login button
                _primaryButton(
                    label: "Login",
                    onPressed: _login),

                const SizedBox(height: 24),

                // ✅ Google + Apple buttons
                SocialButtons(
                  isLoading: _isLoading,
                  onGoogle: _loginWithGoogle,
                  onApple: _loginWithApple,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !_isLoading,
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

  Widget _passwordField() {
    return TextField(
      controller: _passwordCtrl,
      obscureText: _hidePassword,
      enabled: !_isLoading,
      decoration: InputDecoration(
        hintText: "Password",
        hintStyle: GoogleFonts.poppins(
            color: const Color(0xFF90A4AE)),
        prefixIcon: const Icon(Icons.lock_outline,
            color: Color(0xFF00796B)),
        suffixIcon: IconButton(
          icon: Icon(_hidePassword
              ? Icons.visibility_off
              : Icons.visibility),
          onPressed: () => setState(
              () => _hidePassword = !_hidePassword),
        ),
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

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00796B),
          disabledBackgroundColor:
              const Color(0xFF00796B)
                  .withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 4,
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}