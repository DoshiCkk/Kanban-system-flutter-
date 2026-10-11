import 'package:flutter/material.dart';

/// Brand palette.
abstract final class AppColors {
  static const accent = Color(0xFFFF7A45);
  static const secondaryAccent = Color(0xFF5B8CFF);
  static const dark = Color(0xFF14171F);
  static const lightBackground = Color(0xFFF4F2EC);

  // Darker accents for text and icons on light backgrounds: the brand
  // colors reach only 2.3–3.2:1 there, these pass WCAG AA (≥ 4.5:1).
  static const accentOnLight = Color(0xFFA8401A);
  static const secondaryOnLight = Color(0xFF2E5BD6);

  // "Done" (complete checklist): 4.6:1 on the light background, 8:1 dark.
  static const successOnLight = Color(0xFF2E7D32);
  static const successOnDark = Color(0xFF81C784);
}
