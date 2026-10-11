import 'package:flowboard/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Material 3 themes built from the brand palette.
///
/// Contrast (WCAG AA, checked by test/accessibility_test.dart):
/// - Brand orange and blue are fills under dark text (#14171F, ≥ 5.6:1):
///   filled buttons, FAB, containers. White on #FF7A45 would be 2.6:1.
/// - As text on the light background they are too pale, so the light
///   theme's `primary` / `secondary` are darker shades of them.
abstract final class AppTheme {
  static const double minTapTarget = 48;

  static ThemeData light() => _build(
    ColorScheme.fromSeed(seedColor: AppColors.accent).copyWith(
      primary: AppColors.accentOnLight,
      onPrimary: Colors.white,
      primaryContainer: AppColors.accent,
      onPrimaryContainer: AppColors.dark,
      secondary: AppColors.secondaryOnLight,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryAccent,
      onSecondaryContainer: AppColors.dark,
      surface: AppColors.lightBackground,
      onSurface: AppColors.dark,
    ),
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: AppColors.dark,
      secondary: AppColors.secondaryAccent,
      onSecondary: AppColors.dark,
      surface: AppColors.dark,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    const minSize = Size(minTapTarget, minTapTarget);
    return ThemeData(
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      // Primary actions keep the brand orange in both themes.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.dark,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: minSize),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: minSize),
      ),
      listTileTheme: const ListTileThemeData(minTileHeight: minTapTarget),
    );
  }
}
