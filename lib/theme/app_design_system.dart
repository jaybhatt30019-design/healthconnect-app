import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// =======================
/// 🎨 COLORS
/// =======================
class AppColors {
  static const primary = Color(0xFF0E7C6B);
  static const darkPrimary = Color(0xFF004D40);
  static const accent = Color(0xFF00796B);

  static const border = Color(0xFFB2DFDB);

  static const subtitle = Color(0xFF546E7A);
  static const hint = Color(0xFFB0BEC5);

  static const card = Colors.white;
  static const iconBg = Color(0xFFE0F2F1);

  /// Gradient
  static const gradient = LinearGradient(
    colors: [
      Color(0xFFE0F7FA),
      Color(0xFFFFF3E0),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// =======================
/// 📏 SPACING
/// =======================
class AppSpacing {
  static const xs = 10.0;
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 40.0;
  static const xxl = 60.0;
}

/// =======================
/// 🔲 BORDER RADIUS
/// =======================
class AppRadius {
  static const sm = 16.0;
  static const md = 20.0;
  static const circle = 35.0;
}

/// =======================
/// 🌫️ SHADOWS
/// =======================
class AppShadows {
  static BoxShadow light = BoxShadow(
    color: Colors.black.withValues(alpha: 0.05),
    blurRadius: 10,
    offset: const Offset(0, 4),
  );

  static BoxShadow medium = BoxShadow(
    color: Colors.black.withValues(alpha: 0.1),
    blurRadius: 10,
  );
}

/// =======================
/// 🔤 TEXT STYLES
/// =======================
class AppTextStyles {
  static TextStyle heading = GoogleFonts.poppins(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.darkPrimary,
  );

  static TextStyle body = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.darkPrimary,
  );

  static TextStyle subtitle = GoogleFonts.poppins(
    fontSize: 14,
    color: AppColors.subtitle,
  );

  static TextStyle small = GoogleFonts.poppins(
    fontSize: 15,
    color: AppColors.hint,
  );
}

/// =======================
/// 🧱 COMMON WIDGETS
/// =======================

/// 🌈 Gradient Background Wrapper
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
      ),
      child: SafeArea(child: child),
    );
  }
}

/// 🔙 Back Button
class AppBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const AppBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          boxShadow: [AppShadows.medium],
        ),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.darkPrimary,
          ),
          onPressed: onTap,
        ),
      ),
    );
  }
}

/// 🔘 Option Button (Used in your screen)
class AppOptionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const AppOptionButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: double.infinity,
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.border,
            width: 1.5,
          ),
          boxShadow: [AppShadows.light],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.accent,
              size: 26,
            ),
            const SizedBox(width: 16),
            Text(text, style: AppTextStyles.body),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: AppColors.hint,
            ),
          ],
        ),
      ),
    );
  }
}

/// 🧾 Input Field
class AppInputField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final IconData? icon;
  final int maxLines;

  /// NEW
  final TextInputType keyboardType;
  final bool enabled;
  final bool obscureText;

  const AppInputField({
    super.key,
    required this.hint,
    required this.controller,
    this.icon,
    this.maxLines = 1,

    /// NEW
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,

      /// NEW
      keyboardType: keyboardType,
      enabled: enabled,
      obscureText: obscureText,

      style: AppTextStyles.body,

      decoration: InputDecoration(
        hintText: hint,
hintStyle: GoogleFonts.poppins(
  fontSize: 14,
  color: Color(0xFFC5D0D5), // lighter than hint — clearly placeholder
  fontWeight: FontWeight.w400,
),

        prefixIcon: icon != null
            ? Icon(
                icon,
                color: AppColors.accent,
              )
            : null,

        filled: true,
        fillColor: enabled
            ? AppColors.card
            : AppColors.card.withValues(alpha: 0.6),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.border,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}



/// 🧾 Input Field
class AppInputFieldSuggestions extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final IconData? icon;
  final int maxLines;

  final List<String > suggestions;
final Function(String)? onSelected;
  /// NEW
  final TextInputType keyboardType;
  final bool enabled;
  final bool obscureText;

  const AppInputFieldSuggestions({
    super.key,
    required this.hint,
    required this.controller,
    this.icon,
    this.maxLines = 1,
    required this.suggestions,

    required this.onSelected,

    /// NEW
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue:TextEditingValue(text : controller.text),
optionsBuilder: (TextEditingValue textEditingValue) {
        // Hide overlay if user hasn't typed anything yet
        if (textEditingValue.text.isEmpty) {
          print("empty");
                    return const Iterable<String>.empty();
        }
        // Filter options matching user typing structure
        return suggestions.where((String option) {
            print(option);
          
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        controller.text = selection;
        if (onSelected != null) onSelected!(selection);
      },
      fieldViewBuilder: (context, fieldTextEditingController, focusNode, onFieldSubmitted) {
        // Sync our local controller state with the internal builder controller state
        if (controller.text != fieldTextEditingController.text && controller.text.isNotEmpty) {
          fieldTextEditingController.text = controller.text;
        }
        

        return TextField(
      controller: fieldTextEditingController,
      maxLines: maxLines,
focusNode: focusNode,
      onChanged: (value) {
        controller.text = value;
         if (onSelected != null) onSelected!(value);
      },

      /// NEW
      keyboardType: keyboardType,
      enabled: enabled,
      obscureText: obscureText,

      style: AppTextStyles.body,

      decoration: InputDecoration(
        hintText: hint,
hintStyle: GoogleFonts.poppins(
  fontSize: 14,
  color: Color(0xFFC5D0D5), // lighter than hint — clearly placeholder
  fontWeight: FontWeight.w400,
),

        prefixIcon: icon != null
            ? Icon(
                icon,
                color: AppColors.accent,
              )
            : null,

        filled: true,
        fillColor: enabled
            ? AppColors.card
            : AppColors.card.withValues(alpha: 0.6),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.border,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
        );},
         optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(  
            elevation: 4,
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: MediaQuery.of(context).size.width - (AppSpacing.md * 2),
              constraints: BoxConstraints(
                maxHeight: 220
              ),// Keeps drop view height constraints tight
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, _) => const Divider(color: AppColors.border, height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                                       title: Padding(
                                         padding: const EdgeInsets.all(5.0),
                                         child: Text(option, style: AppTextStyles.body),
                                       ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
  );
  }
}
