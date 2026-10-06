import 'package:flowboard/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Material 3 themes built from the brand palette.
///
/// Text on the orange/blue accents is dark, not white: white on #FF7A45
/// fails WCAG AA contrast, #14171F passes comfortably.
abstract final class AppTheme {
  static const double minTapTarget = 48;

  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.accent,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: AppColors.dark,
      secondary: AppColors.secondaryAccent,
      onSecondary: AppColors.dark,
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: minSize),
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
