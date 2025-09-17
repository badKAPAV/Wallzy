import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 1. Define a ThemeExtension for custom semantic colors
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.income,
    required this.expense,
  });

  final Color income;
  final Color expense;

  @override
  AppColors copyWith({Color? income, Color? expense}) {
    return AppColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      income: Color.lerp(this.income, other.income, t)!,
      expense: Color.lerp(this.expense, other.expense, t)!,
    );
  }
}

class AppTheme {
  // 2. Define our custom colors as a const for re-use
  static const _appColors = AppColors(
    income: Color.fromARGB(255, 75, 192, 81), // A nice, deep green
    expense: Color(0xFFD32F2F), // A strong red
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,

    // 3. Generate a full color scheme from a single seed color
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFA40000), // A vibrant blue seed
      brightness: Brightness.dark,
    ),
    
    // 4. Define the expressive typography using Google Fonts
    textTheme: TextTheme(
      // For large, bold display text like the balance
      displayLarge: GoogleFonts.dmSerifDisplay(
        fontWeight: FontWeight.w700,
        fontSize: 48,
      ),
      // For screen titles
      headlineMedium: GoogleFonts.dmSerifDisplay(
        fontWeight: FontWeight.w600,
      ),
      // For section headers like "Recent Transactions"
      titleLarge: GoogleFonts.inter(
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      // For list item titles
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      // For general body text and labels
      bodyMedium: GoogleFonts.inter(),
      // For subtitles and captions
      bodySmall: GoogleFonts.inter(
        color: Colors.white70,
      ),
    ),
    
    // 5. Add our custom colors to the theme
    extensions: const <ThemeExtension<dynamic>>[
      _appColors,
    ],
    
    // 6. Style specific components
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}