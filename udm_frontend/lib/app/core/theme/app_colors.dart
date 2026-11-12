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

  // Brand extensions. These exist so gradients and hairlines stay in the family
  // instead of each screen inventing its own blue.
  static const Color royalBlue = Color(0xFF2E8FD0);
  static const Color ink = Color(0xFF0B1F33);
  static const Color mist = Color(0xFFDDEBF7);

  /// Candle gold: decoration only (the verse rule, the streak flame). Never a
  /// status colour, because warning already owns amber.
  static const Color gold = Color(0xFFF2B544);

  static const Color darkInk = Color(0xFF060E16);
  static const Color darkMist = Color(0xFF24425F);
}

/// Gradient and depth tokens. A feature asks for `AppGradients.hero` rather than
/// composing stops, so the brand reads the same on every screen and both
/// brightnesses are tuned in one place.
class AppGradients {
  const AppGradients._();

  static const LinearGradient hero = LinearGradient(
    colors: [AppColors.royalBlue, AppColors.primaryBlue, AppColors.deepBlue],
    stops: [0, 0.52, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient scripture = LinearGradient(
    colors: [AppColors.primaryBlue, AppColors.deepBlue, AppColors.ink],
    stops: [0, 0.6, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark-mode hero: same direction, lifted so it separates from the canvas.
  static const LinearGradient heroDark = LinearGradient(
    colors: [AppColors.darkLightBlue, AppColors.darkSurface, AppColors.darkInk],
    stops: [0, 0.55, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient scriptureDark = LinearGradient(
    colors: [AppColors.darkMist, AppColors.darkSurface, AppColors.darkInk],
    stops: [0, 0.55, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Card face: a barely-there sheen that keeps a large white surface from
  /// looking flat against the canvas.
  static const LinearGradient sheen = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF4F9FE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient sheenDark = LinearGradient(
    colors: [AppColors.darkElevated, AppColors.darkSurface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldRule = LinearGradient(
    colors: [AppColors.gold, Color(0x00F2B544)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Frosted veil used behind the bottom navigation and app bars.
  static LinearGradient veil(Color surface) => LinearGradient(
        colors: [surface.withValues(alpha: 0.94), surface.withValues(alpha: 0.99)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

/// Soft, blue-tinted shadows. Grey shadows on a blue brand look dirty at low
/// opacity; tinting keeps lifted cards reading as part of the same family.
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> card(Color tint, {bool dark = false}) => [
        BoxShadow(
          color: tint.withValues(alpha: dark ? 0.45 : 0.10),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: tint.withValues(alpha: dark ? 0.30 : 0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static const List<BoxShadow> float = [
    BoxShadow(color: Color(0x2E123B63), blurRadius: 28, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x14123B63), blurRadius: 8, offset: Offset(0, 3)),
  ];

  static List<BoxShadow> glow(Color tint) => [
        BoxShadow(color: tint.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
      ];
}
