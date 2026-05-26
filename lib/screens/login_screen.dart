// lib/screens/login_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthconnect/screens/welcome_screen.dart';
import 'package:healthconnect/screens/add_parent_screen.dart';
import 'package:healthconnect/features/dashboard/main_dashboard.dart';
import 'package:healthconnect/core/services/social_auth_service.dart';
import 'package:healthconnect/widgets/social_buttons.dart';

// ── Saved account model ───────────────────────────
class _SavedAccount {
  final String name;
  final String email;
  final String? photoUrl;

  const _SavedAccount({
    required this.name,
    required this.email,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
      };

  factory _SavedAccount.fromJson(
      Map<String, dynamic> json) {
    return _SavedAccount(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  final _socialAuth = SocialAuthService();

  bool _hidePassword = true;
  bool _isLoading = false;
  bool _isResetting = false;

  // Previously signed in accounts
  List<_SavedAccount> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Load saved accounts from SharedPreferences ────
  Future<void> _loadSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('savedAccounts') ?? [];
      final accounts = raw.map((s) {
        final json = jsonDecode(s) as Map<String, dynamic>;
        return _SavedAccount.fromJson(json);
      }).toList();

      if (mounted) {
        setState(() => _savedAccounts = accounts);
      }
    } catch (e) {
      debugPrint('[Login] Load accounts error: $e');
    }
  }

  // ── Save account after successful login ───────────
  static Future<void> saveAccount({
    required String name,
    required String email,
    String? photoUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getStringList('savedAccounts') ?? [];

      // Parse existing
      final accounts = raw.map((s) {
        final json =
            jsonDecode(s) as Map<String, dynamic>;
        return _SavedAccount.fromJson(json);
      }).toList();

      // Remove if already exists (avoid duplicate)
      accounts.removeWhere((a) => a.email == email);

      // Add to front
      accounts.insert(
          0,
          _SavedAccount(
            name: name,
            email: email,
            photoUrl: photoUrl,
          ));

      // Keep max 3
      final trimmed = accounts.take(3).toList();

      // Save back
      final encoded =
          trimmed.map((a) => jsonEncode(a.toJson())).toList();
      await prefs.setStringList('savedAccounts', encoded);
    } catch (e) {
      debugPrint('[Login] Save account error: $e');
    }
  }

  // ── Remove saved account ──────────────────────────
  Future<void> _removeAccount(_SavedAccount account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getStringList('savedAccounts') ?? [];

      final accounts = raw.map((s) {
        final json =
            jsonDecode(s) as Map<String, dynamic>;
        return _SavedAccount.fromJson(json);
      }).toList();

      accounts.removeWhere((a) => a.email == account.email);

      final encoded =
          accounts.map((a) => jsonEncode(a.toJson())).toList();
      await prefs.setStringList('savedAccounts', encoded);

      if (mounted) {
        setState(() => _savedAccounts = accounts);
      }
    } catch (e) {
      debugPrint('[Login] Remove account error: $e');
    }
  }

  // ── Tap saved account → fill email + focus password ─
  void _onAccountTap(_SavedAccount account) {
    setState(() => _emailCtrl.text = account.email);
    // Small delay so field updates before focusing
    Future.delayed(const Duration(milliseconds: 100), () {
      _passwordFocus.requestFocus();
    });
  }

  // ── Long press → confirm remove ──────────────────
  Future<void> _onAccountLongPress(
      _SavedAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text("Remove account?",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600)),
        content: Text(
          "Remove ${account.email} from saved accounts?",
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: Text("Cancel",
                style: GoogleFonts.poppins(
                    color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10)),
            ),
            onPressed: () =>
                Navigator.pop(context, true),
            child: Text("Remove",
                style: GoogleFonts.poppins(
                    color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeAccount(account);
    }
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

  // ── Redirect by role ──────────────────────────────
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

  // ── Email login ───────────────────────────────────
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
      final name = data['name'] as String? ?? '';
      final photoUrl = data['photoUrl'] as String?;

      // ✅ Save account for next login
      await saveAccount(
        name: name,
        email: email,
        photoUrl: photoUrl,
      );

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
        if (response.role == null) {
          await _socialAuth.signOut();
          setState(() => _isLoading = false);
          _snack(
            "No account found. Please sign up first "
            "by selecting your role on the welcome screen.",
          );
          return;
        }

        // ✅ Save account
        await saveAccount(
          name: response.displayName ?? '',
          email: response.email ?? '',
        );

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

        // ✅ Save account
        await saveAccount(
          name: response.displayName ?? '',
          email: response.email ?? '',
        );

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
          _snack(
              "Could not send reset email. Try again.");
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

                const SizedBox(height: 10),

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

                const SizedBox(height: 20),

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

                const SizedBox(height: 30),

                // ✅ Previously signed in accounts
                if (_savedAccounts.isNotEmpty) ...[
                  _buildSavedAccountsSection(),
                  const SizedBox(height: 20),

                  // Divider
                  Row(children: [
                    Expanded(
                        child: Container(
                            height: 1,
                            color: const Color(
                                0xFFE0E0E0))),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 14),
                      child: Text(
                        "or sign in with email",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color:
                              const Color(0xFF90A4AE),
                        ),
                      ),
                    ),
                    Expanded(
                        child: Container(
                            height: 1,
                            color: const Color(
                                0xFFE0E0E0))),
                  ]),

                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 10),

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

                // Google + Apple
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

  // ── Previously signed in section ─────────────────
  Widget _buildSavedAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Previously signed in",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF546E7A),
              ),
            ),
            const Spacer(),
            Text(
              "Long press to remove",
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF90A4AE),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Account cards
        ...(_savedAccounts.map(
          (account) => _accountCard(account),
        )),
      ],
    );
  }

  // ── Single account card ───────────────────────────
  Widget _accountCard(_SavedAccount account) {
    // Get initials for avatar
    final initials = account.name.isNotEmpty
        ? account.name
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : account.email.isNotEmpty
            ? account.email[0].toUpperCase()
            : '?';

    return GestureDetector(
      onTap: () => _onAccountTap(account),
      onLongPress: () => _onAccountLongPress(account),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFB2DFDB),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00796B),
                shape: BoxShape.circle,
              ),
              child: account.photoUrl != null &&
                      account.photoUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        account.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Center(
                          child: Text(
                            initials,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initials,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),

            const SizedBox(width: 12),

            // Name and email
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name.isNotEmpty
                        ? account.name
                        : account.email,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF004D40),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (account.name.isNotEmpty)
                    Text(
                      account.email,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF78909C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Arrow
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xFF00796B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Input field ───────────────────────────────────
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

  // ── Password field ────────────────────────────────
  Widget _passwordField() {
    return TextField(
      controller: _passwordCtrl,
      focusNode: _passwordFocus,
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

  // ── Primary button ────────────────────────────────
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
          disabledBackgroundColor: const Color(0xFF00796B)
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