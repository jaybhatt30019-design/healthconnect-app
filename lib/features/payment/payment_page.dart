import 'dart:math' as math;

import 'package:Vitanex/features/dashboard/main_dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:Vitanex/theme/app_design_system.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentPage extends StatefulWidget {
  final bool isCaregiver;
  final int initialIndex;
  final String caregiverId;
  final String code;

  const PaymentPage({
    super.key,
    required this.isCaregiver,
    required this.caregiverId,
    this.initialIndex = 0,
    required this.code,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage>
    with TickerProviderStateMixin {
  late Razorpay _razorpay;
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  // ───────────────────────── PRICING CONFIG ─────────────────────────
  static const int _earlyBirdLimit = 1000;
  static const int _earlyBirdPricePaise = 19900; // ₹199
  static const int _regularPricePaise = 29900; // ₹299
  static const int _subscriptionDays = 365; // 1 year

  int? _userCount;
  bool _loadingCount = true;

  bool get _isEarlyBird => (_userCount ?? _earlyBirdLimit) < _earlyBirdLimit;
  int get _priceInPaise =>
      _isEarlyBird ? _earlyBirdPricePaise : _regularPricePaise;
  int get _priceInRupees => _priceInPaise ~/ 100;
  int get _regularPriceInRupees => _regularPricePaise ~/ 100;
  int get _savingsInRupees =>
      _regularPriceInRupees - (_earlyBirdPricePaise ~/ 100);
  // ────────────────────────────────────────────────────────────────

  // ───────────────────────── COUPON / ORDER STATE ─────────────────────────
  final _couponController = TextEditingController();
  String? _couponError;
  bool _isProcessing = false;
  Map<String, dynamic>? _orderData;
  // ──────────────────────────────────────────────────────────────────────

  final List<Map<String, dynamic>> _appFeatures = [
    {
      'icon': Icons.phone_callback_rounded,
      'title': 'Auto-Receive Emergency Calls',
      'desc':
          'Instantly answers critical care calls from children or parents without requiring touch interactions.',
    },
    {
      'icon': Icons.location_on_rounded,
      'title': 'Real-time Location Sharing',
      'desc':
          'Keep tracks updated smoothly so children can see parental coordinates during emergencies.',
    },
    {
      'icon': Icons.medication_rounded,
      'title': 'Smart Medication Schedules',
      'desc':
          'Add routines with automated alerts and predictive typing matching 200+ medical items.',
    },
    {
      'icon': Icons.assignment_rounded,
      'title': 'Medical Report Management',
      'desc':
          'Securely upload, organize, and access vital health history logs anytime.',
    },
    {
      'icon': Icons.calendar_month_rounded,
      'title': 'Doctor Appointment Manager',
      'desc':
          'Schedule regular checkups and send timely reminders straight to caregivers.',
    },
  ];

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // Gentle "breathing" pulse used on the hero artwork and the CTA button.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchUserCount();
  }

  /// Live-counts the `users` collection to silently decide which pricing
  /// tier applies. The count itself is never shown in the UI — only the
  /// resulting price and a general "first 1,000 users" benefit line.
Future<void> _fetchUserCount() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('isPremium', isEqualTo: true)
        .count()
        .get();
    if (!mounted) return;
    setState(() {
      _userCount = snapshot.count ?? 0;
      _loadingCount = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() { _userCount = 1000; _loadingCount = false; });
  }
}

@override
void dispose() {
  _razorpay.clear();
  _pulseController.dispose();
  _couponController.dispose();   // ← add this
  super.dispose();
}

Future<void> _startPayment() async {
  if (_loadingCount || _isProcessing) return;
 setState(() { _isProcessing = true; _couponError = null; });

  try {
    await FirebaseAuth.instance.currentUser?.getIdToken(true);

    final token = await FirebaseAuth.instance.currentUser?.getIdToken();

    final callable = FirebaseFunctions.instance.httpsCallable('createSubscriptionOrder');
    final result = await callable.call({
      'couponCode': _couponController.text.trim().isEmpty ? null : _couponController.text.trim(),
    });

_orderData = Map<String, dynamic>.from(result.data);

if (_orderData!['isFree'] == true) {
  await _redeemFree();
  return;
}

if (!mounted) return;
final confirmed = await _showBreakdownSheet(_orderData!);
    if (confirmed != true) { setState(() => _isProcessing = false); return; }

    var options = {
      'key': _orderData!['keyId'],
      'order_id': _orderData!['orderId'],
      'amount': _orderData!['totalPaise'],
      'name': 'Vitanex Premium',
      'description': _orderData!['isEarlyBird']
          ? 'Early Bird Annual Pass (1 Year)'
          : 'Standard Annual Pass (1 Year)',
    };

    _razorpay.open(options);
  } on FirebaseFunctionsException catch (e) {
    setState(() { _isProcessing = false; _couponError = e.message ?? 'Invalid coupon'; });
  } catch (e) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not start payment: $e')),
    );
  }
}

Future<void> _redeemFree() async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('redeemFreeCoupon');
    await callable.call({'couponCode': _couponController.text.trim()});

    if (widget.code.compareTo("HC-1-1-1-1") != 0) {
      await _completePairing();
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MainDashboard(isCaregiver: widget.isCaregiver)),
    );
  } on FirebaseFunctionsException catch (e) {
    setState(() { _isProcessing = false; _couponError = e.message ?? 'Coupon redemption failed'; });
  } catch (e) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not redeem coupon: $e')),
    );
  }
}

Future<bool?> _showBreakdownSheet(Map<String, dynamic> order) {
  final base = order['discountedBase'] / 100;
  final gst = order['gstPaise'] / 100;
  final total = order['totalPaise'] / 100;

  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: 8),
              Text('Order Summary', style: AppTextStyles.heading.copyWith(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 20),
          _row('Plan price', '₹${base.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _row('GST (18%)', '₹${gst.toStringAsFixed(2)}'),
          const SizedBox(height: 14),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          _row('Total payable', '₹${total.toStringAsFixed(2)}', bold: true),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Proceed to Pay', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _row(String label, String value, {bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: bold ? AppTextStyles.body.copyWith(fontWeight: FontWeight.bold) : AppTextStyles.body),
      Text(value, style: bold ? AppTextStyles.body.copyWith(fontWeight: FontWeight.bold) : AppTextStyles.body),
    ],
  ),
);


Future<void> _completePairing()async{
  
    // Mark code as used
    await FirebaseFirestore.instance
        .collection('pairing_codes')
        .doc(widget.code)
        .update({'isUsed': true});

    // Link caregiver
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.caregiverId)
        .update({'parentLinked': true});

// String phone="";

// final parentRef = FirebaseFirestore.instance
//         .collection('parents')
//         .where('caregiverId',isEqualTo: widget.caregiverId).get().then((E){
//           phone = E.docs.first.get("phone");
//         });
}

Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('verifySubscriptionPayment');
    await callable.call({
      'orderId': response.orderId,
      'paymentId': response.paymentId,
      'signature': response.signature,
      'couponCode': _couponController.text.trim().isEmpty ? null : _couponController.text.trim(),
    });

    if (widget.code.compareTo("HC-1-1-1-1") != 0) {
      await _completePairing();
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MainDashboard(isCaregiver: widget.isCaregiver)),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment could not be verified: $e'), backgroundColor: Colors.red[800]),
    );
  } finally {
    if (mounted) setState(() => _isProcessing = false);
  }
}

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message}'),
        backgroundColor: Colors.red[800],
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.gradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHero(),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'FEATURES INCLUDED',
                        style: AppTextStyles.small.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ...List.generate(_appFeatures.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _StaggerFadeSlide(
                            index: index,
                            child: _buildFeatureCard(_appFeatures[index]),
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),

Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  child: Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(
        color: _couponError != null ? Colors.red.shade300 : AppColors.border,
        width: 1.2,
      ),
      boxShadow: [AppShadows.light],
    ),
    child: TextField(
      controller: _couponController,
      textCapitalization: TextCapitalization.characters,
      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2),
      onChanged: (_) {
        if (_couponError != null) setState(() => _couponError = null);
      },
      decoration: InputDecoration(
        hintText: 'Have a coupon code?',
        hintStyle: AppTextStyles.subtitle,
        prefixIcon: Icon(Icons.local_offer_rounded, color: AppColors.accent, size: 20),
        suffixIcon: _couponController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.hint,
                onPressed: () => setState(() => _couponController.clear()),
              )
            : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      ),
    ),
  ),
),
if (_couponError != null)
  Padding(
    padding: const EdgeInsets.only(left: AppSpacing.lg + 8, top: 6),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 14, color: Colors.red.shade400),
        const SizedBox(width: 4),
        Text(_couponError!, style: AppTextStyles.small.copyWith(color: Colors.red.shade400)),
      ],
    ),
  ),
const SizedBox(height: 12),

              _buildBottomPanel(),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── UI PIECES ─────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Center(
        child: Text(
          'Unlock Premium',
          style: AppTextStyles.heading.copyWith(fontSize: 22),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Center(
      child: Column(
        children: [
          _PremiumArtwork(pulseScale: _pulseScale),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Complete Care Protection Pack',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            'Peace of mind, always on.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
          _buildBenefitNote(),
        ],
      ),
    );
  }

  /// A quiet, static callout about the launch benefit — no live counters,
  /// just the fact that early users get a better price.
  Widget _buildBenefitNote() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: (_loadingCount || !_isEarlyBird) ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.iconBg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'First 1,000 members get this at ₹199/year — save ₹$_savingsInRupees',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.darkPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.light],
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.iconBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(item['icon'], color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'], style: AppTextStyles.body),
                const SizedBox(height: 4),
                Text(
                  item['desc'],
                  style: AppTextStyles.subtitle.copyWith(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.md),
          topRight: Radius.circular(AppRadius.md),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width - 132,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    
                    
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _loadingCount ? 'CHECKING OFFER…' : '1-YEAR PREMIUM PASS',
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: animation,
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: _loadingCount
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                height: 32,
                                width: 32,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : Row(
                                key: ValueKey(_priceInRupees),
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  if (_isEarlyBird) ...[
                                    Text(
                                      '₹$_regularPriceInRupees',
                                      style: AppTextStyles.subtitle.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        fontSize: 16,
                                      ),
                                    ),
                                    // const SizedBox(width: 6),
                                  ],
                                  Text(
                                    '₹$_priceInRupees',
                                    style: AppTextStyles.heading.copyWith(
                                      fontSize: 32,
                                      color: AppColors.darkPrimary,
                                    ),
                                  ),
                                  // const SizedBox(width: 4),
                                  Text('/year', style: AppTextStyles.subtitle),
                                ],
                              ),
                      ),
                      if (!_loadingCount) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Renews as a new 1-year pass after expiry',
                          style: AppTextStyles.small,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_loadingCount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isEarlyBird ? 'Best Deal' : 'Best',
                      style: GoogleFonts.poppins(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ScaleTransition(
            scale: _loadingCount
                ? const AlwaysStoppedAnimation(1.0)
                : _pulseScale,
            child: ElevatedButton(
              onPressed: _loadingCount ? null : _startPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                elevation: 2,
              ),
              child: _loadingCount
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Pay Now & Use App',
                          style: AppTextStyles.body.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.hint),
              const SizedBox(width: 4),
              Text(
                'Secure payment powered by Razorpay',
                style: AppTextStyles.small,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Decorative, animated premium badge — a soft glow, a gradient medallion,
/// and small feature icons gently orbiting around it. Purely visual, no
/// data behind it.
class _PremiumArtwork extends StatefulWidget {
  final Animation<double> pulseScale;

  const _PremiumArtwork({required this.pulseScale});

  @override
  State<_PremiumArtwork> createState() => _PremiumArtworkState();
}

class _PremiumArtworkState extends State<_PremiumArtwork>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotateController;

  static const List<IconData> _orbitIcons = [
    Icons.favorite_rounded,
    Icons.shield_rounded,
    Icons.auto_awesome_rounded,
    Icons.medication_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft outer glow
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.20),
                  AppColors.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),
          // Orbiting feature icons
          AnimatedBuilder(
            animation: _rotateController,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: List.generate(_orbitIcons.length, (i) {
                  final angle = (_rotateController.value * 2 * math.pi) +
                      (i * (2 * math.pi / _orbitIcons.length));
                  const radius = 90.0;
                  final dx = radius * math.cos(angle);
                  final dy = radius * math.sin(angle);
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [AppShadows.light],
                      ),
                      child: Icon(
                        _orbitIcons[i],
                        size: 14,
                        color: AppColors.accent,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          // Pulsing gradient medallion
          ScaleTransition(
            scale: widget.pulseScale,
            child: Container(
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.darkPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
          // Center icon
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.primary,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small reusable fade + slide-up entrance animation used to stagger the
/// feature list in on page load.
class _StaggerFadeSlide extends StatefulWidget {
  final Widget child;
  final int index;

  const _StaggerFadeSlide({required this.child, required this.index});

  @override
  State<_StaggerFadeSlide> createState() => _StaggerFadeSlideState();
}

class _StaggerFadeSlideState extends State<_StaggerFadeSlide> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 90 * widget.index + 120), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        offset: _visible ? Offset.zero : const Offset(0, 0.15),
        child: widget.child,
      ),
    );
  }
}