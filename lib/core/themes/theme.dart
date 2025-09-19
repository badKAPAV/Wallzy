import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color income;
  final Color expense;

  const AppColors({required this.income, required this.expense});

  @override
  ThemeExtension<AppColors> copyWith({Color? income, Color? expense}) {
    return AppColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
    );
  }
}

Color scaffoldSurface(
  CorePalette? palette,
  Brightness brightness,
  Color fallback,
) {
  if (palette == null) return fallback;

  // Use neutralVariant instead of plain neutral — better surface contrasts.
  final neutral = palette.neutralVariant;

  if (brightness == Brightness.dark) {
    // Dark theme: keep scaffold darker, so containers can layer above
    return Color(neutral.get(10)); // deep background
  } else {
    // Light theme: avoid too-white, pick a mid-high tone
    return Color(neutral.get(93)); // slightly tinted off-white
  }
}

Color containerSurface(
  CorePalette? palette,
  Brightness brightness,
  Color fallback,
) {
  if (palette == null) return fallback;

  final neutral = palette.neutralVariant;

  if (brightness == Brightness.dark) {
    return Color(neutral.get(20)); // one step lighter than scaffold
  } else {
    return Color(neutral.get(98)); // one step brighter than scaffold
  }
}

ColorScheme patchedColorScheme(ColorScheme base, CorePalette? palette) {
  // If no dynamic palette is available, return the base theme.
  if (palette == null) return base;

  final isDark = base.brightness == Brightness.dark;

  // Get references to all the tonal palettes
  final primary = palette.primary;
  final secondary = palette.secondary;
  final tertiary = palette.tertiary;
  final neutral = palette.neutral;
  final neutralVariant = palette.neutralVariant;

  // Return the ColorScheme with roles mapped to the correct palette and tone.
  // The tone values (e.g., get(40), get(90)) are based on Material 3 specs.
  return base.copyWith(
    // Primary colors
    primary: isDark ? Color(primary.get(80)) : Color(primary.get(40)),
    onPrimary: isDark ? Color(primary.get(20)) : Color(primary.get(100)),
    primaryContainer: isDark ? Color(primary.get(30)) : Color(primary.get(90)),
    onPrimaryContainer: isDark ? Color(primary.get(90)) : Color(primary.get(10)),

    // Secondary colors
    secondary: isDark ? Color(secondary.get(80)) : Color(secondary.get(40)),
    onSecondary: isDark ? Color(secondary.get(20)) : Color(secondary.get(100)),
    secondaryContainer: isDark ? Color(secondary.get(30)) : Color(secondary.get(90)),
    onSecondaryContainer: isDark ? Color(secondary.get(90)) : Color(secondary.get(10)),

    // Tertiary colors
    tertiary: isDark ? Color(tertiary.get(80)) : Color(tertiary.get(40)),
    onTertiary: isDark ? Color(tertiary.get(20)) : Color(tertiary.get(100)),
    tertiaryContainer: isDark ? Color(tertiary.get(30)) : Color(tertiary.get(90)),
    onTertiaryContainer: isDark ? Color(tertiary.get(90)) : Color(tertiary.get(10)),

    // Error colors (usually remain static)
    error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
    onError: isDark ? const Color(0xFF690005) : const Color(0xFFFFFFFF),
    errorContainer: isDark ? const Color(0xFF93000A) : const Color(0xFFF9DEDC),
    onErrorContainer: isDark ? const Color(0xFFF9DEDC) : const Color(0xFF410E0B),

    // Neutral Surface and Background colors
    surface: isDark ? Color(neutral.get(6)) : Color(neutral.get(98)),
    onSurface: isDark ? Color(neutral.get(90)) : Color(neutral.get(10)),
    surfaceVariant: isDark ? Color(neutralVariant.get(30)) : Color(neutralVariant.get(90)),
    onSurfaceVariant: isDark ? Color(neutralVariant.get(80)) : Color(neutralVariant.get(30)),

    // Inverse and Outline colors
    inverseSurface: isDark ? Color(neutral.get(90)) : Color(neutral.get(20)),
    onInverseSurface: isDark ? Color(neutral.get(20)) : Color(neutral.get(95)),
    inversePrimary: isDark ? Color(primary.get(40)) : Color(primary.get(80)),
    outline: isDark ? Color(neutralVariant.get(60)) : Color(neutralVariant.get(50)),
    outlineVariant: isDark ? Color(neutralVariant.get(30)) : Color(neutralVariant.get(80)),
    
    // Container colors (layered surfaces)
    surfaceContainerLowest: isDark ? Color(neutral.get(4)) : Color(neutral.get(100)),
    surfaceContainerLow: isDark ? Color(neutral.get(10)) : Color(neutral.get(96)),
    surfaceContainer: isDark ? Color(neutral.get(12)) : Color(neutral.get(94)),
    surfaceContainerHigh: isDark ? Color(neutral.get(17)) : Color(neutral.get(92)),
    surfaceContainerHighest: isDark ? Color(neutral.get(22)) : Color(neutral.get(90)),
  );
}

class AppTheme {
  static const _lightAppColors = AppColors(
    income: Color(0xFF2CBF6E),
    expense: Color(0xFFF26D6D),
  );

  static const _darkAppColors = AppColors(
    income: Colors.greenAccent,
    expense: Colors.redAccent,
  );

static ThemeData buildTheme(
  ColorScheme colorScheme, {
  CorePalette? corePalette,
}) {
  final isDark = colorScheme.brightness == Brightness.dark;
  final appColors = isDark ? _darkAppColors : _lightAppColors;
  final baseTheme = ThemeData.from(
    colorScheme: colorScheme,
    useMaterial3: true,
  );

  final fullColorScheme = patchedColorScheme(
    baseTheme.colorScheme,
    corePalette,
  );

  final interTheme = GoogleFonts.interTextTheme(baseTheme.textTheme);
  final oswaldTheme = GoogleFonts.oswaldTextTheme(baseTheme.textTheme);
  final finaltextTheme = interTheme.copyWith(
      displayLarge: oswaldTheme.displayLarge,
      displayMedium: oswaldTheme.displayMedium,
      displaySmall: oswaldTheme.displaySmall,
      headlineLarge: oswaldTheme.headlineLarge,
      headlineMedium: oswaldTheme.headlineMedium,
      headlineSmall: oswaldTheme.headlineSmall,
      titleLarge: oswaldTheme.titleLarge,
    );

  final finalTheme = ThemeData.from(
    colorScheme: fullColorScheme,
    textTheme: finaltextTheme,
    useMaterial3: true,
  );

  return finalTheme.copyWith(
    extensions: [appColors],
    scaffoldBackgroundColor: scaffoldSurface(
      corePalette,
      isDark ? Brightness.dark : Brightness.light,
      fullColorScheme.surface, // Use the new surface color as fallback
    ),
    appBarTheme: const AppBarTheme(
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
}
