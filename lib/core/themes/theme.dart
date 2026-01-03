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

/// Returns a highly vibrant scaffold surface.
///
/// FIX: We now use [palette.primary] instead of [palette.neutralVariant].
/// This ensures the background is a rich version of the seed color (e.g., Blue, Red)
/// rather than a greyish tint.
Color scaffoldSurface(
  CorePalette? palette,
  Brightness brightness,
  Color fallback,
) {
  if (palette == null) return fallback;

  // Use the PRIMARY palette. This is the key to vibrancy.
  final primary = palette.primary;

  if (brightness == Brightness.dark) {
    // Dark Mode: Use Tone 6.
    // This is a very deep, rich color (e.g., Midnight Blue, Deep Forest Green).
    // It is much more colorful than the standard "Dark Grey" (Tone 10).
    return Color(primary.get(6));
  } else {
    // Light Mode: Use Tone 95.
    // This creates a distinct pastel wash (e.g., Light Blue, Light Pink).
    // Standard Material uses Tone 98/99 which looks white. 95 is visibly colored.
    return Color(primary.get(95));
  }
}

/// Returns a container surface that pops against the vibrant scaffold.
Color containerSurface(
  CorePalette? palette,
  Brightness brightness,
  Color fallback,
) {
  if (palette == null) return fallback;

  final primary = palette.primary;

  if (brightness == Brightness.dark) {
    // Dark Mode Container: Tone 20.
    // Lighter than the Tone 6 background, creating contrast without shadows.
    return Color(primary.get(20));
  } else {
    // Light Mode Container: Tone 99 or 100.
    // Almost pure white (tinted slightly).
    // This creates the "White Card on Colored Background" effect.
    return Color(primary.get(99));
  }
}

ColorScheme patchedColorScheme(ColorScheme base, CorePalette? palette) {
  if (palette == null) return base;

  final isDark = base.brightness == Brightness.dark;

  final primary = palette.primary;
  final secondary = palette.secondary;
  final tertiary = palette.tertiary;
  final neutral = palette.neutral;
  final neutralVariant = palette.neutralVariant;

  // We use the Primary palette for surfaces to force vibrancy everywhere.
  final surfacePalette = primary;

  return base.copyWith(
    // Boosted Primary Tones
    primary: isDark ? Color(primary.get(80)) : Color(primary.get(40)),
    onPrimary: isDark ? Color(primary.get(20)) : Color(primary.get(100)),
    primaryContainer: isDark ? Color(primary.get(30)) : Color(primary.get(90)),
    onPrimaryContainer: isDark
        ? Color(primary.get(90))
        : Color(primary.get(10)),

    // Secondary
    secondary: isDark ? Color(secondary.get(80)) : Color(secondary.get(40)),
    onSecondary: isDark ? Color(secondary.get(20)) : Color(secondary.get(100)),
    secondaryContainer: isDark
        ? Color(secondary.get(30))
        : Color(secondary.get(90)),
    onSecondaryContainer: isDark
        ? Color(secondary.get(90))
        : Color(secondary.get(10)),

    // Tertiary
    tertiary: isDark ? Color(tertiary.get(80)) : Color(tertiary.get(40)),
    onTertiary: isDark ? Color(tertiary.get(20)) : Color(tertiary.get(100)),
    tertiaryContainer: isDark
        ? Color(tertiary.get(30))
        : Color(tertiary.get(90)),
    onTertiaryContainer: isDark
        ? Color(tertiary.get(90))
        : Color(tertiary.get(10)),

    // Error
    error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
    onError: isDark ? const Color(0xFF690005) : const Color(0xFFFFFFFF),
    errorContainer: isDark ? const Color(0xFF93000A) : const Color(0xFFF9DEDC),
    onErrorContainer: isDark
        ? const Color(0xFFF9DEDC)
        : const Color(0xFF410E0B),

    // --- VIBRANT SURFACES ---
    // Mapping surface roles to the PRIMARY palette.

    // The "Canvas"
    surface: isDark
        ? Color(surfacePalette.get(6))
        : Color(surfacePalette.get(95)),

    onSurface: isDark
        ? Color(surfacePalette.get(98))
        : Color(surfacePalette.get(10)),

    // --- CONTAINERS ---
    // These now use Primary Tones 99/20 to contrast with the 95/6 Canvas.
    surfaceContainerLowest: isDark
        ? Color(surfacePalette.get(4))
        : Color(surfacePalette.get(100)),

    surfaceContainerLow: isDark
        ? Color(surfacePalette.get(10))
        : Color(surfacePalette.get(96)),

    // Standard Card Color
    surfaceContainer: isDark
        ? Color(surfacePalette.get(20))
        : Color(surfacePalette.get(98)),

    surfaceContainerHigh: isDark
        ? Color(surfacePalette.get(25))
        : Color(surfacePalette.get(95)), // Inverted slightly for effect

    surfaceContainerHighest: isDark
        ? Color(surfacePalette.get(30))
        : Color(surfacePalette.get(90)),

    // Variants (Outlines, secondary text)
    // We map these to NeutralVariant to ensure text is still readable (not too neon)
    onSurfaceVariant: isDark
        ? Color(neutralVariant.get(80))
        : Color(neutralVariant.get(30)),

    outline: isDark
        ? Color(neutralVariant.get(60))
        : Color(neutralVariant.get(50)),

    outlineVariant: isDark
        ? Color(neutralVariant.get(30))
        : Color(neutralVariant.get(80)),

    inverseSurface: isDark ? Color(neutral.get(90)) : Color(neutral.get(20)),
    onInverseSurface: isDark ? Color(neutral.get(20)) : Color(neutral.get(95)),
    inversePrimary: isDark ? Color(primary.get(40)) : Color(primary.get(80)),

    surfaceTint: primary.get(40) == 0 ? base.primary : Color(primary.get(40)),
  );
}

class AppTheme {
  static const _lightAppColors = AppColors(
    income: Color(0xFF00C853), // Vivid Green
    expense: Color(0xFFD50000), // Vivid Red
  );

  static const _darkAppColors = AppColors(
    income: Color(0xFF00E676), // Neon Green
    expense: Color(0xFFFF1744), // Neon Red
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

    return ThemeData(
      colorScheme: fullColorScheme,
      textTheme: finaltextTheme,
      useMaterial3: true,
      extensions: [appColors],
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (BuildContext context) {
          return Padding(
            padding: const EdgeInsets.all(2.0),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, size: 16),
            ),
          ); // Your custom icon here
        },
      ),
      // Apply the vibrant scaffold color
      scaffoldBackgroundColor: scaffoldSurface(
        corePalette,
        isDark ? Brightness.dark : Brightness.light,
        fullColorScheme.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldSurface(
          corePalette,
          isDark ? Brightness.dark : Brightness.light,
          fullColorScheme.surface,
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: fullColorScheme.onSurface),
        titleTextStyle: finaltextTheme.titleLarge?.copyWith(
          color: fullColorScheme.onSurface,
        ),
      ),
      // Apply the vibrant container color to Cards and BottomSheets
      cardTheme: CardThemeData(
        color: containerSurface(
          corePalette,
          isDark ? Brightness.dark : Brightness.light,
          fullColorScheme.surfaceContainer,
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: containerSurface(
          corePalette,
          isDark ? Brightness.dark : Brightness.light,
          fullColorScheme.surfaceContainer,
        ),
        modalBackgroundColor: containerSurface(
          corePalette,
          isDark ? Brightness.dark : Brightness.light,
          fullColorScheme.surfaceContainer,
        ),
      ),
    );
  }
}
