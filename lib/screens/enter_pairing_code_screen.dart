// lib/screens/enter_pairing_code_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:healthconnect/features/dashboard/main_dashboard.dart';

class EnterPairingCodeScreen extends StatefulWidget {
  const EnterPairingCodeScreen({super.key});

  @override
  State<EnterPairingCodeScreen> createState() =>
      _EnterPairingCodeScreenState();
}

class _EnterPairingCodeScreenState
    extends State<EnterPairingCodeScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeFocus = FocusNode();

  // ── Animation ─────────────────────────────────────
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── State ─────────────────────────────────────────
  // Phase 1: code input only
  // Phase 2: account creation revealed after code verified
  bool _codeVerified = false;
  bool _isVerifying = false;
  bool _isCreating = false;
  bool _hidePassword = true;
  String _codeError = '';

  // Saved after successful code verification
  String _caregiverId = '';
  String _parentId = '';
  String _parentName = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Phase 1: Verify Code ──────────────────────────
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => _codeError = 'Please enter your pairing code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _codeError = '';
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('pairing_codes')
          .doc(code)
          .get();

      if (!doc.exists) {
        setState(() => _codeError = 'Invalid code. Please check and try again.');
        return;
      }

      final data = doc.data()!;

      if (data['isUsed'] == true) {
        setState(() => _codeError = 'This code has already been used.');
        return;
      }

      // ✅ Check expiry
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (expiresAt != null &&
          expiresAt.toDate().isBefore(DateTime.now())) {
        setState(() => _codeError = 'This code has expired. Ask your caregiver for a new one.');
        return;
      }

      // ✅ Code is valid — save data and reveal phase 2
      _caregiverId = data['caregiverId'] as String? ?? '';
      _parentId = data['parentId'] as String? ?? '';

      // Get parent name from parents collection
      final parentDoc = await FirebaseFirestore.instance
          .collection('parents')
          .doc(_parentId)
          .get();
      _parentName = parentDoc.data()?['name'] as String? ?? 'Parent';

      // Haptic feedback — success
      HapticFeedback.mediumImpact();

      setState(() => _codeVerified = true);
      _animController.forward();

    } catch (e) {
      setState(() => _codeError = 'Something went wrong. Please try again.');
      debugPrint('[PairingCode] Verify error: $e');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ── Phase 2: Complete pairing in Firestore ────────
  Future<void> _completePairing(String uid) async {
    final code = _codeController.text.trim().toUpperCase();

    // Mark code as used
    await FirebaseFirestore.instance
        .collection('pairing_codes')
        .doc(code)
        .update({'isUsed': true});

    // Link caregiver
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_caregiverId)
        .update({'parentLinked': true});

    // Create parent user doc
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({
      'name': _parentName,
      'email': FirebaseAuth.instance.currentUser?.email ?? '',
      'role': 'parent',
      'caregiverId': _caregiverId,
      'parentId': _parentId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Email + Password sign up ──────────────────────
  Future<void> _createWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack('Please enter your email and password.');
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _completePairing(credential.user!.uid);
      _goToDashboard();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          // ✅ If account exists, sign in instead
          try {
            final credential = await FirebaseAuth.instance
                .signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            await _completePairing(credential.user!.uid);
            _goToDashboard();
          } on FirebaseAuthException catch (_) {
            _snack('An account with this email already exists. Please use the correct password.');
          }
          break;
        case 'weak-password':
          _snack('Password is too weak. Use at least 6 characters.');
          break;
        case 'invalid-email':
          _snack('Please enter a valid email address.');
          break;
        default:
          _snack('Account creation failed. Please try again.');
      }
    } catch (e) {
      _snack('Something went wrong. Please try again.');
      debugPrint('[PairingCode] Email create error: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ── Google Sign In ────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _isCreating = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isCreating = false);
        return; // User cancelled
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      await _completePairing(userCredential.user!.uid);
      _goToDashboard();
    } catch (e) {
      _snack('Google sign in failed. Please try again.');
      debugPrint('[PairingCode] Google error: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ── Apple Sign In ─────────────────────────────────
  Future<void> _signInWithApple() async {
    setState(() => _isCreating = true);
    try {
      final appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      await _completePairing(userCredential.user!.uid);
      _goToDashboard();
    } catch (e) {
      _snack('Apple sign in failed. Please try again.');
      debugPrint('[PairingCode] Apple error: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const MainDashboard(isCaregiver: false),
      ),
      (route) => false,
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ── BUILD ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE0F7FA),
              Color(0xFFF3E5F5),
              Color(0xFFFFF3E0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
                horizontal: 24),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Back button ──────────────────
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: Color(0xFF004D40),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Header ───────────────────────
                _buildHeader(),

                const SizedBox(height: 32),

                // ── Code input card ───────────────
                _buildCodeCard(),

                // ── Phase 2: Account creation ─────
                // Revealed with animation after code verified
                if (_codeVerified) ...[
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: _buildAccountSection(),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header section ────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon with glow
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF00796B),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00796B)
                    .withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.link_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),

        const SizedBox(height: 20),

        Text(
          _codeVerified
              ? "Almost there! 🎉"
              : "Connect with\nyour caregiver",
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF004D40),
            height: 1.2,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _codeVerified
              ? "Code verified! Now create your account\nto save your progress."
              : "Enter the pairing code shared\nby your child or caregiver.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF546E7A),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Code input card ───────────────────────────────
  Widget _buildCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _codeVerified
                      ? Colors.green
                      : const Color(0xFF00796B),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _codeVerified
                    ? "Code verified ✓"
                    : "Pairing Code",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _codeVerified
                      ? Colors.green.shade700
                      : const Color(0xFF546E7A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Code input
          Container(
            decoration: BoxDecoration(
              color: _codeVerified
                  ? Colors.green.shade50
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _codeError.isNotEmpty
                    ? Colors.red.shade300
                    : _codeVerified
                        ? Colors.green.shade300
                        : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    focusNode: _codeFocus,
                    // ✅ Locked after verification
                    enabled: !_codeVerified,
                    textAlign: TextAlign.center,
                    textCapitalization:
                        TextCapitalization.characters,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: _codeVerified
                          ? Colors.green.shade700
                          : const Color(0xFF004D40),
                    ),
                    decoration: InputDecoration(
                      hintText: "HC-123456",
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 22,
                        letterSpacing: 4,
                        color: const Color(0xFFCFD8DC),
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                    onChanged: (_) {
                      if (_codeError.isNotEmpty) {
                        setState(() => _codeError = '');
                      }
                    },
                  ),
                ),
                // Verified checkmark icon
                if (_codeVerified)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Error message
          if (_codeError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.error_outline,
                    size: 14,
                    color: Colors.red.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _codeError,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.red.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Verify button — hidden after verification
          if (!_codeVerified) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  disabledBackgroundColor:
                      const Color(0xFF00796B)
                          .withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isVerifying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        "Verify Code",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Account creation section (Phase 2) ────────────
  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome message with parent name
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF00796B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome, $_parentName!",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Your caregiver has connected you.",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Section title
        Text(
          "Create your account",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF004D40),
          ),
        ),
        Text(
          "So you can log back in anytime",
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF546E7A),
          ),
        ),

        const SizedBox(height: 20),

        // Account creation card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Email field
              _inputField(
                controller: _emailController,
                hint: "Email Address",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 14),

              // Password field
              _passwordField(),

              const SizedBox(height: 20),

              // Create account button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      _isCreating ? null : _createWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF00796B),
                    disabledBackgroundColor:
                        const Color(0xFF00796B)
                            .withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          "Create Account & Continue",
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFFE0E0E0),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14),
                    child: Text(
                      "or continue with",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF90A4AE),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFFE0E0E0),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Google button
              _socialButton(
                onTap: _isCreating
                    ? null
                    : _signInWithGoogle,
                label: "Continue with Google",
                icon: _googleIcon(),
                bgColor: Colors.white,
                textColor: const Color(0xFF3C4043),
                borderColor: const Color(0xFFDADCE0),
              ),

              const SizedBox(height: 12),

              // Apple button
              _socialButton(
                onTap: _isCreating
                    ? null
                    : _signInWithApple,
                label: "Continue with Apple",
                icon: const Icon(
                  Icons.apple,
                  color: Colors.white,
                  size: 22,
                ),
                bgColor: Colors.black,
                textColor: Colors.white,
                borderColor: Colors.black,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Input field helper ────────────────────────────
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE8ECEF),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: !_isCreating,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: const Color(0xFF004D40),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFFB0BEC5),
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF00796B),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // ── Password field ────────────────────────────────
  Widget _passwordField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE8ECEF),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _hidePassword,
        enabled: !_isCreating,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: const Color(0xFF004D40),
        ),
        decoration: InputDecoration(
          hintText: "Password (min 6 characters)",
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFFB0BEC5),
          ),
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: Color(0xFF00796B),
            size: 20,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _hidePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFF90A4AE),
              size: 20,
            ),
            onPressed: () => setState(
                () => _hidePassword = !_hidePassword),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // ── Social button ─────────────────────────────────
  Widget _socialButton({
    required VoidCallback? onTap,
    required String label,
    required Widget icon,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Google icon (coloured G) ──────────────────────
  Widget _googleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _GoogleIconPainter(),
      ),
    );
  }
}

// ── Google G icon painter ─────────────────────────
class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
        0, 0, size.width, size.height);
    final center = rect.center;
    final radius = size.width / 2;

    // Blue arc
    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;

    // Red arc
    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;

    // Yellow arc
    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;

    // Green arc
    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;

    final r = radius * 0.72;
    final arcRect = Rect.fromCircle(
        center: center, radius: r);

    // Draw coloured arcs — simplified G shape
    canvas.drawArc(
        arcRect, -0.5, 1.5, false, paintBlue);
    canvas.drawArc(
        arcRect, 1.0, 1.2, false, paintRed);
    canvas.drawArc(
        arcRect, 2.2, 1.0, false, paintYellow);
    canvas.drawArc(
        arcRect, 3.2, 1.1, false, paintGreen);

    // Horizontal bar for G
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + r, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}