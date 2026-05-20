// lib/features/shared/more_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:healthconnect/core/services/notification_service.dart';
import 'package:healthconnect/core/services/connection_service.dart';
import 'package:healthconnect/features/dashboard/edit_profile_screen.dart';
import 'package:healthconnect/screens/welcome_screen.dart';
import 'package:healthconnect/screens/add_parent_screen.dart';
import 'package:healthconnect/screens/enter_pairing_code_screen.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/features/settings/about_app_screen.dart';
import 'package:healthconnect/features/settings/privacy_policy_screen.dart';
import 'package:healthconnect/features/settings/terms_conditions_screen.dart';
import 'package:healthconnect/features/medical_history/medical_history_screen.dart';
import 'package:healthconnect/features/health_passport/health_passport_screen.dart';
import 'package:healthconnect/features/medical_report/medical_report_screen.dart';
import 'package:healthconnect/features/scan_report/scan_report_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _connectionService = ConnectionService();

  Map<String, dynamic>? userData;
  bool isLoading = true;
  String _appVersion = '';
  bool _isOffline = false;

  // Connection card state
  ConnectionInfo? _connectionInfo;
  bool _connectionLoading = true;
  String _userRole = '';

  // Pairing code input for parent
  final _codeController = TextEditingController();
  bool _connectingCode = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadVersion();
    _checkConnectivity();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadUser(),
      _loadConnection(),
    ]);
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion =
              'v${info.version} (${info.buildNumber})';
        });
      }
    } catch (e) {
      debugPrint('[MoreScreen] Version: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final result =
          await Connectivity().checkConnectivity();
      if (mounted) {
        setState(() {
          _isOffline =
              result == ConnectivityResult.none;
        });
      }
      Connectivity().onConnectivityChanged.listen(
        (result) {
          if (mounted) {
            setState(() {
              _isOffline =
                  result == ConnectivityResult.none;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('[MoreScreen] Connectivity: $e');
    }
  }

  Future<void> _loadUser() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (mounted) {
        setState(() {
          userData = doc.exists ? doc.data() : null;
          _userRole =
              userData?['role'] as String? ?? '';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[MoreScreen] Load user: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadConnection() async {
    try {
      final info = await _connectionService
          .loadConnectionInfo();
      if (mounted) {
        setState(() {
          _connectionInfo = info;
          _connectionLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[MoreScreen] Connection: $e');
      if (mounted) {
        setState(() => _connectionLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await NotificationService()
          .cancelAllNotifications();
    } catch (e) {
      debugPrint('[MoreScreen] Cancel notif: $e');
    }
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _resetPassword() async {
    try {
      final email = _auth.currentUser?.email;
      if (email == null || email.isEmpty) {
        _snack("No email found for this account");
        return;
      }
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Password Reset"),
          content: Text(
              "A reset link has been sent to:\n\n$email"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'too-many-requests':
          _snack(
              "Too many requests. Try again later.");
          break;
        default:
          _snack("Something went wrong. Try again.");
      }
    }
  }

  // ── Disconnect dialog ─────────────────────────────
  Future<void> _showDisconnectDialog() async {
    final name =
        _connectionInfo?.connectedName ?? 'this person';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Connection?"),
        content: Text(
          "You will be disconnected from $name.\n\n"
          "Your health data will not be deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _connectionLoading = true);
      await _connectionService.disconnect();

      if (!mounted) return;

      // Caregiver goes to AddParentScreen
      if (_userRole == 'caregiver') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => const AddParentScreen()),
          (route) => false,
        );
        return;
      }

      // Parent stays — refresh connection card
      _snack("Disconnected successfully");
      await _loadConnection();
    } catch (e) {
      debugPrint('[MoreScreen] Disconnect: $e');
      _snack("Could not disconnect. Try again.");
      if (mounted) {
        setState(() => _connectionLoading = false);
      }
    }
  }

  // ── Parent: connect via pairing code ─────────────
  Future<void> _connectWithCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _snack("Please enter a pairing code");
      return;
    }

    setState(() => _connectingCode = true);

    final result = await _connectionService
        .connectWithCode(code);

    if (!mounted) return;
    setState(() => _connectingCode = false);

    if (result.success) {
      _codeController.clear();
      _snack(
          "Connected to ${result.message} successfully!");
      // Refresh connection card
      await _loadConnection();
    } else {
      _snack(result.message);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.all(AppSpacing.lg),
            child: isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator())
                : Column(
                    children: [
                      Align(
                        alignment:
                            Alignment.centerLeft,
                        child: Text("Settings",
                            style:
                                AppTextStyles.heading),
                      ),

                      // Offline banner
                      if (_isOffline) ...[
                        const SizedBox(
                            height: AppSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                Colors.orange.shade50,
                            borderRadius:
                                BorderRadius.circular(
                                    8),
                            border: Border.all(
                                color: Colors
                                    .orange.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.wifi_off,
                                  color: Colors
                                      .orange.shade700,
                                  size: 16),
                              const SizedBox(width: 8),
                              Text(
                                "You're offline. Some features may not work.",
                                style: AppTextStyles
                                    .small
                                    .copyWith(
                                  color: Colors
                                      .orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(
                          height: AppSpacing.lg),

                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [

                              // ── Profile card ───
                              _card(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text("Profile",
                                        style:
                                            AppTextStyles
                                                .body),
                                    const SizedBox(
                                        height:
                                            AppSpacing
                                                .md),
                                    _profileItem(
                                        "Name",
                                        userData?[
                                                'name'] ??
                                            "Not Available"),
                                    _profileItem(
                                        "Age",
                                        "${userData?['age'] ?? '-'}"),
                                    _profileItem(
                                        "Phone",
                                        userData?[
                                                'phone'] ??
                                            "Not Available"),
                                    _profileItem(
                                        "Email",
                                        userData?[
                                                'email'] ??
                                            _auth.currentUser
                                                ?.email ??
                                            ""),
                                    const SizedBox(
                                        height:
                                            AppSpacing
                                                .md),
                                    SizedBox(
                                      width:
                                          double.infinity,
                                      height: 50,
                                      child:
                                          ElevatedButton
                                              .icon(
                                        style: ElevatedButton
                                            .styleFrom(
                                          backgroundColor:
                                              AppColors
                                                  .iconBg,
                                          elevation: 0,
                                          shape:
                                              RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        AppRadius
                                                            .md),
                                          ),
                                        ),
                                        onPressed:
                                            () async {
                                          await Navigator
                                              .push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const EditProfileScreen(),
                                            ),
                                          );
                                          _loadUser();
                                        },
                                        icon: const Icon(
                                            Icons.edit,
                                            color: AppColors
                                                .accent),
                                        label: Text(
                                          "Edit Profile",
                                          style: AppTextStyles
                                              .body
                                              .copyWith(
                                                  color: AppColors
                                                      .accent),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(
                                  height:
                                      AppSpacing.lg),

                              // ── Connected To card ─
                              _connectionCard(),

                              const SizedBox(
                                  height:
                                      AppSpacing.lg),

                              // ── Health Records ──
                              _card(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                        "Health Records",
                                        style:
                                            AppTextStyles
                                                .body),
                                    const SizedBox(
                                        height:
                                            AppSpacing
                                                .md),
                                    _tile(
                                      icon: Icons
                                          .badge_outlined,
                                      text:
                                          "Health Passport",
                                      color: AppColors
                                          .primary,
                                      onTap: () =>
                                          Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const HealthPassportScreen(),
                                        ),
                                      ),
                                    ),
                                    const Divider(),
                                    _tile(
                                      icon: Icons
                                          .health_and_safety_outlined,
                                      text:
                                          "Medical History",
                                      color: AppColors
                                          .primary,
                                      onTap: () =>
                                          Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const MedicalHistoryScreen(),
                                        ),
                                      ),
                                    ),
                                    const Divider(),
                                    _tile(
                                      icon: Icons
                                          .timeline_outlined,
                                      text:
                                          "Medical Report",
                                      color: AppColors
                                          .primary,
                                      onTap: () =>
                                          Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const MedicalReportScreen(),
                                        ),
                                      ),
                                    ),
                                    const Divider(),
                                    _tile(
                                      icon: Icons
                                          .document_scanner_outlined,
                                      text:
                                          "Scan Report",
                                      color: AppColors
                                          .primary,
                                      onTap: () =>
                                          Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ScanReportScreen(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(
                                  height:
                                      AppSpacing.lg),

                              // ── Account Settings ─
                              _card(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                        "Account Settings",
                                        style:
                                            AppTextStyles
                                                .body),
                                    const SizedBox(
                                        height:
                                            AppSpacing
                                                .md),
                                    _tile(
                                      icon: Icons
                                          .lock_outline,
                                      text:
                                          "Change Password",
                                      onTap:
                                          _resetPassword,
                                    ),
                                    const Divider(),
                                    _tile(
                                      icon:
                                          Icons.logout,
                                      text: "Logout",
                                      color: Colors.red,
                                      onTap: _logout,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(
                                  height:
                                      AppSpacing.lg),

                              // ── App Info ─────────
                              _card(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text("App Info",
                                        style:
                                            AppTextStyles
                                                .body),
                                    const SizedBox(
                                        height:
                                            AppSpacing
                                                .md),
                                    _tile(
                                      icon: Icons
                                          .info_outline,
                                      text: "About App",
                                      onTap: () =>
                                          Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AboutAppScreen(),
                                        ),
                                      ),
                                    ),
                                    const Divider(),
                                    _tile(
                                      icon: Icons
                                          .privacy_tip_outlined,
                                      text:
                                          "Privacy Policy",
                                      onTap: () =>
                                          Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const PrivacyPolicyScreen(),
                                        ),
                                      ),
                                    ),
                                    const Divider(),
                                    _tile(
                                      icon: Icons
                                          .description_outlined,
                                      text:
                                          "Terms & Conditions",
                                      onTap: () =>
                                          Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const TermsConditionsScreen(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(
                                  height:
                                      AppSpacing.lg),

                              // ── Version ──────────
                              if (_appVersion
                                  .isNotEmpty)
                                Container(
                                  width:
                                      double.infinity,
                                  padding:
                                      const EdgeInsets
                                          .all(
                                          AppSpacing
                                              .md),
                                  decoration:
                                      BoxDecoration(
                                    color: AppColors
                                        .card,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                                AppRadius
                                                    .md),
                                    boxShadow: [
                                      AppShadows.light
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                          Icons
                                              .info_outline,
                                          color:
                                              AppColors
                                                  .hint,
                                          size: 16),
                                      const SizedBox(
                                          width: 8),
                                      Text(
                                        "HealthConnect $_appVersion",
                                        style:
                                            AppTextStyles
                                                .small,
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(
                                  height:
                                      AppSpacing.xl),
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
  }

  // ── Connection card ───────────────────────────────
  Widget _connectionCard() {
    final isCaregiver = _userRole == 'caregiver';
    final title = isCaregiver
        ? 'Connected Parent'
        : 'Connected Caregiver';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(
                Icons.link,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.body),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Loading
          if (_connectionLoading)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2),
              ),
            )

          // Connected state
          else if (_connectionInfo?.isConnected ==
              true) ...[
            _connectedContent(),
            const SizedBox(height: AppSpacing.md),
            // Disconnect button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(
                      color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                            AppRadius.sm),
                  ),
                ),
                onPressed: _showDisconnectDialog,
                icon: const Icon(Icons.link_off,
                    size: 18),
                label:
                    const Text("Remove Connection"),
              ),
            ),
          ]

          // Not connected state
          else ...[
            _notConnectedContent(isCaregiver),
          ],
        ],
      ),
    );
  }

  // Connected — shows person's info
  Widget _connectedContent() {
    final info = _connectionInfo!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.iconBg,
        borderRadius:
            BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + relation
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person,
                    color: AppColors.primary,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.connectedName ?? '—',
                      style: AppTextStyles.body
                          .copyWith(
                              fontWeight:
                                  FontWeight.w700),
                    ),
                    if (info.relation != null &&
                        info.relation!.isNotEmpty)
                      Text(
                        info.relation!,
                        style: AppTextStyles.small,
                      ),
                  ],
                ),
              ),
              // Connected badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green
                      .withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.green
                          .withValues(alpha: 0.4)),
                ),
                child: Text(
                  "Connected",
                  style: AppTextStyles.small
                      .copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          if (info.connectedPhone != null &&
              info.connectedPhone!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.phone_outlined,
                    size: 14, color: AppColors.hint),
                const SizedBox(width: 6),
                Text(info.connectedPhone!,
                    style: AppTextStyles.small),
              ],
            ),
          ],

          if (info.connectedSince != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: AppColors.hint),
                const SizedBox(width: 6),
                Text(
                  "Since ${info.connectedSince}",
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Not connected — different content per role
  Widget _notConnectedContent(bool isCaregiver) {
    return Column(
      children: [
        // Warning banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius:
                BorderRadius.circular(AppRadius.sm),
            border: Border.all(
                color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_outlined,
                  color: Colors.orange.shade700,
                  size: 18),
              const SizedBox(width: 8),
              Text(
                isCaregiver
                    ? "No parent connected"
                    : "No caregiver connected",
                style: AppTextStyles.small.copyWith(
                    color: Colors.orange.shade800),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        if (isCaregiver)
          // Caregiver → go to Add Parent screen
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      AppRadius.sm),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AddParentScreen(),
                ),
              ).then((_) => _loadConnection()),
              icon: const Icon(Icons.person_add,
                  color: Colors.white, size: 18),
              label: const Text("Add Parent",
                  style:
                      TextStyle(color: Colors.white)),
            ),
          )
        else
          // Parent → enter pairing code inline
          _pairingCodeInput(),
      ],
    );
  }

  // Parent: inline pairing code entry
  Widget _pairingCodeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Enter the pairing code shared by your caregiver:",
          style: AppTextStyles.small,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                textCapitalization:
                    TextCapitalization.characters,
                style: AppTextStyles.body.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  hintText: "HC-XXXXXX",
                  hintStyle: AppTextStyles.small,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                            AppRadius.sm),
                    borderSide: const BorderSide(
                        color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                            AppRadius.sm),
                    borderSide: const BorderSide(
                        color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                            AppRadius.sm),
                    borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                            AppRadius.sm),
                  ),
                ),
                onPressed: _connectingCode
                    ? null
                    : _connectWithCode,
                child: _connectingCode
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Connect",
                        style: TextStyle(
                            color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Reusable widgets ──────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.light],
      ),
      child: child,
    );
  }

  Widget _profileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(
          bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.small),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String text,
    Color color = AppColors.darkPrimary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(text,
          style:
              AppTextStyles.body.copyWith(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}