import 'package:flutter/material.dart';

/// Semantic color tokens from docs/design-system.md. Features must not use raw
/// hex values; add a token here instead.
class AppColors {
  const AppColors._();

  static const Color primaryBlue = Color(0xFF1769AA);
  static const Color deepBlue = Color(0xFF123B63);
  static const Color lightBlue = Color(0xFFEAF4FC);
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F9FC);

  static const Color darkText = Color(0xFF182B3A);
  static const Color secondaryText = Color(0xFF718096);

  static const Color success = Color(0xFF269B72);
  static const Color warning = Color(0xFFE6A23C);

  // Dark palette: same hues, lifted surfaces, text contrast checked against
  // each surface it sits on.
  static const Color darkBackground = Color(0xFF0E1822);
  static const Color darkSurface = Color(0xFF16232F);
  static const Color darkElevated = Color(0xFF1D2E3D);
  static const Color darkModeText = Color(0xFFEAF1F8);
  static const Color darkModeSecondaryText = Color(0xFF9FB0C1);
  static const Color darkLightBlue = Color(0xFF1B3A55);

  static const Color danger = Color(0xFFC0392B);
}
