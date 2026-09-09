// lib/screens/pairing_code_screen.dart
// ✅ Auto-redirects caregiver to dashboard
// when parent enters the pairing code and connects

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Vitanex/features/dashboard/main_dashboard.dart';
import '../theme/app_colors.dart';
import '../widgets/app_gradient.dart';
import '../widgets/primary_button.dart';

class PairingCodeScreen extends StatefulWidget {
  final String pairingCode;
  final String parentName;

  const PairingCodeScreen({
    super.key,
    required this.pairingCode,
    required this.parentName,
  });

  @override
  State<PairingCodeScreen> createState() =>
      _PairingCodeScreenState();
}

class _PairingCodeScreenState
    extends State<PairingCodeScreen> {
  StreamSubscription? _pairingSub;
  bool _isConnected = false;

StreamSubscription<DocumentSnapshot>? _subscriptionTracker;
  @override
  void initState() {
    super.initState();
    _listenForParentConnection();
  }

  @override
  void dispose() {
    _pairingSub?.cancel();
    super.dispose();
  }

  // ✅ Listen to pairing_codes/{code} document
  // When isUsed becomes true → parent connected
  // → auto navigate caregiver to dashboard
  void _listenForParentConnection() {
    _pairingSub = FirebaseFirestore.instance
        .collection('pairing_codes')
        .doc(widget.pairingCode)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      if (!mounted) return;

      final isUsed =
          snap.data()?['isUsed'] as bool? ?? false;

      if (isUsed && !_isConnected) {
       
        _pairingSub?.cancel();
        _onParentConnected();
      }
    });
  }

  // ✅ Parent connected — show success then navigate
  void _onParentConnected() {
    if (!mounted) return;

 //   Show connected banner
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle,
                color: Colors.white),
            const SizedBox(width: 10),
            Text(
              '${widget.parentName} connected! ✅',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0E7C6B),
        duration: const Duration(seconds: 2),
      ),
    );

    // Navigate to dashboard after short delay
    // so user can see the success message
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const MainDashboard(isCaregiver: true),
        ),
        (route) => false,
      );
    });
    
    //startPaymentListener();
  }







void startPaymentListener() async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) return;

  // setState(() {
  //   isLoading = true;
  // });

  try {
    // 1. Fetch current user role metrics first to map out dependencies
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUid)
        .get();

    if (!userDoc.exists) {
      // setState(() => isLoading = false);
      return;
    }
    
    final userData = userDoc.data()!;
    final String role = userData['role'] ?? 'parent';
    
    // Determine which document target we should listen to for premium changes
    String targetListenId = currentUid;
    if (role != 'parent' && (userData['parentId'] ?? '').isNotEmpty) {
      targetListenId = userData['parentId'];
    }

    // Helper validation formula matching your annual validation rule structure
    bool isSubscriptionActive(Map<String, dynamic>? data) {
      if (data == null) return false;
      final hasTaken = data['hasTakenSubscription'] == true;
      if (!hasTaken) return false;

      final expiresAt = data['subscriptionExpiresAt'];
      if (expiresAt is Timestamp) {
        return expiresAt.toDate().isAfter(DateTime.now());
      }
      return false;
    }

    // 2. Open a real-time connection stream to monitor that target document
    _subscriptionTracker?.cancel(); // Clear any existing listener first
    _subscriptionTracker = FirebaseFirestore.instance
        .collection("users")
        .doc(targetListenId)
        .snapshots()
        .listen((snapshot) {
      
      if (snapshot.exists) {
        final data = snapshot.data();
        final bool clearToProceed = isSubscriptionActive(data);

        if (clearToProceed) {
          // Break the listener immediately so it doesn't fire again
          _subscriptionTracker?.cancel();

          if (!mounted) return;
          // setState(() {
          //   isLoading = false;
          // });

           _isConnected = true;
Future.delayed(const Duration(seconds: 2), () {
          // Premium is confirmed active! Flush navigation history and move to dashboard
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => MainDashboard(isCaregiver: true),
            ),
            (route) => false,
          );});
        } else {
          // If payment is not done yet, turn off the full-screen loading spinner 
          // so they can interact with your Razorpay payment button layout on this page.
          if (mounted) {
            // setState(() {
            //   isLoading = false;
            // });
          }
          debugPrint("[Subscription Stream] Payment still pending... Staying on current page.");
        }
      }
    });

  } catch (e) {
    debugPrint("Subscription stream compilation loop error: $e");
    if (mounted) {
      // setState(() => isLoading = false);
    }
  }
}


  String get _shareMessage =>
      'Hi ${widget.parentName}! Here is your Vitanex pairing code: '
      '${widget.pairingCode}. '
      'Open the Vitanex app, tap "I Have a Pairing Code" and enter this code. '
      'It expires in 24 hours.';

  Future<void> _shareViaWhatsApp(
      BuildContext context) async {
    final encoded = Uri.encodeComponent(_shareMessage);
    final uri =
        Uri.parse('https://wa.me/?text=$encoded');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri,
          mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('WhatsApp is not installed.')),
        );
      }
    }
  }

  Future<void> _shareViaSMS(
      BuildContext context) async {
    final encoded = Uri.encodeComponent(_shareMessage);
    final uri = Uri.parse('sms:?body=$encoded');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Could not open SMS app.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradient(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [

                // Header
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                            Icons.arrow_back),
                        color: AppColors.textDark,
                        onPressed: () =>
                            Navigator.pop(context),
                      ),
                    ),
                    Text(
                      'Pairing Code',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Code card
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius:
                        BorderRadius.circular(25),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your Connection Code',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppColors.textLight,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        widget.pairingCode,
                        style: GoogleFonts.poppins(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.backgroundStart,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Code expires in 24 hours',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Share this code with ${widget.parentName}.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: AppColors.textDark,
                  ),
                ),

                const SizedBox(height: 16),

                // ✅ Waiting indicator
                // Shows while listening for parent
                if (!_isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFF0E7C6B)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                const Color(0xFF0E7C6B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Waiting for ${widget.parentName} to connect...',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color:
                                const Color(0xFF004D40),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ✅ Connected indicator
                if (_isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E7C6B),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.white,
                            size: 18),
                        const SizedBox(width: 10),
                        Text(
                          '${widget.parentName} Connected!',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Share buttons
                PrimaryButton(
                  text: 'Share via WhatsApp',
                  onPressed: () =>
                      _shareViaWhatsApp(context),
                ),

                const SizedBox(height: 16),

                OutlinedButton.icon(
                  icon: const Icon(Icons.sms,
                      color: AppColors.primary),
                  label: const Text(
                    'Share via SMS',
                    style: TextStyle(
                        color: AppColors.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                        const Size(double.infinity, 60),
                    side: const BorderSide(
                        color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () =>
                      _shareViaSMS(context),
                ),

                const SizedBox(height: 20),

                TextButton.icon(
                  icon: const Icon(Icons.copy,
                      color: AppColors.primary),
                  label: const Text(
                    'Copy Code',
                    style: TextStyle(
                        color: AppColors.primary),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                        text: widget.pairingCode));
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                          content: Text('Code copied')),
                    );
                  },
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}