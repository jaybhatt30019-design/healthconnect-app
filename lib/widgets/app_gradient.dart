import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppGradient extends StatelessWidget {
  final Widget child;

  const AppGradient({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.backgroundStart,
            AppColors.backgroundEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}