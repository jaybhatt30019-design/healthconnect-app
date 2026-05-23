// lib/widgets/social_buttons.dart
// Reusable Google + Apple buttons
// Used across login, parent signup, caregiver signup

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SocialButtons extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  const SocialButtons({
    super.key,
    required this.isLoading,
    required this.onGoogle,
    required this.onApple,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Divider ─────────────────────────────
        Row(
          children: [
            Expanded(
              child: Container(
                  height: 1,
                  color: const Color(0xFFE0E0E0)),
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
                  color: const Color(0xFFE0E0E0)),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Google button ────────────────────────
        _SocialButton(
          onTap: isLoading ? null : onGoogle,
          label: "Continue with Google",
          icon: _GoogleIcon(),
          bgColor: Colors.white,
          textColor: const Color(0xFF3C4043),
          borderColor: const Color(0xFFDADCE0),
        ),

        const SizedBox(height: 12),

        // ── Apple button ─────────────────────────
        _SocialButton(
          onTap: isLoading ? null : onApple,
          label: "Continue with Apple",
          icon: const Icon(Icons.apple,
              color: Colors.white, size: 22),
          bgColor: Colors.black,
          textColor: Colors.white,
          borderColor: Colors.black,
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final Widget icon;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;

  const _SocialButton({
    required this.onTap,
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
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
}

// ── Coloured Google G icon ───────────────────────
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.36;
    final stroke = size.width * 0.16;

    void arc(double start, double sweep, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        sweep,
        false,
        paint,
      );
    }

    // Red (top-right)
    arc(-1.05, 1.15, const Color(0xFFEA4335));
    // Yellow (bottom)
    arc(0.52, 1.05, const Color(0xFFFBBC05));
    // Green (bottom-left)
    arc(1.57, 1.10, const Color(0xFF34A853));
    // Blue (left to top)
    arc(2.67, 1.65, const Color(0xFF4285F4));

    // Blue horizontal bar (the flat part of G)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + r, c.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) =>
      false;
}