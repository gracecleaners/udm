import 'package:flutter/material.dart';

/// Semantic color tokens from docs/design-system.md. Features must not use raw
/// hex values; add a token here instead.
class AppColors {
  const AppColors._();

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color deepBlue = Color(0xFF101B3D);
  static const Color lightBlue = Color(0xFFEFF6FF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC);

  static const Color darkText = Color(0xFF172033);
  static const Color secondaryText = Color(0xFF64748B);

  static const Color success = Color(0xFF269B72);
  static const Color warning = Color(0xFFE6A23C);

  // Dark palette: same hues, lifted surfaces, text contrast checked against
  // each surface it sits on.
  static const Color darkBackground = Color(0xFF0B1020);
  static const Color darkSurface = Color(0xFF111A2E);
  static const Color darkElevated = Color(0xFF18243B);
  static const Color darkModeText = Color(0xFFF1F5F9);
  static const Color darkModeSecondaryText = Color(0xFF9AAAC1);
  static const Color darkLightBlue = Color(0xFF1D3563);

  static const Color danger = Color(0xFFC0392B);

  // Brand extensions. These exist so gradients and hairlines stay in the family
  // instead of each screen inventing its own blue.
  static const Color royalBlue = Color(0xFF3B82F6);
  static const Color ink = Color(0xFF101B3D);
  static const Color mist = Color(0xFFDCEBFF);

  /// Candle gold: decoration only (the verse rule, the streak flame). Never a
  /// status colour, because warning already owns amber.
  static const Color gold = Color(0xFFF5B942);

  static const Color darkInk = Color(0xFF070B16);
  static const Color darkMist = Color(0xFF294A83);

  /// The wash under a cover that has no artwork, and the scrim laid over a
  /// photograph so white type stays legible on whatever the ministry uploaded.
  static const Color scrim = Color(0xB30B1428);
  static const Color scrimSoft = Color(0x8C0B1428);

  /// Hairlines at the two weights the kit needs: a quiet edge on a card, and a
  /// firm one where a control has to declare itself (an input, a selected pill).
  static const Color hairline = Color(0x14123B63);
  static const Color hairlineStrong = Color(0x29123B63);
  static const Color darkHairline = Color(0x33A9CBE8);
  static const Color darkHairlineStrong = Color(0x4DA9CBE8);

  /// The tinted fill an inactive input or a quiet row sits on.
  static const Color field = Color(0xFFF4F8FC);
  static const Color primaryTint = Color(0x1A2563EB);
  static const Color successTint = Color(0x1A269B72);
  static const Color goldTint = Color(0x24F5B942);
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
    colors: [AppColors.gold, Color(0x00F5B942)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Bottom-to-top scrim over cover art, so a title set on the picture stays
  /// readable whatever the photograph behind it happens to be.
  static const LinearGradient scrim = LinearGradient(
    colors: [Color(0x00000000), Color(0x66000000), AppColors.scrim],
    stops: [0.32, 0.62, 1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// The left-to-right version, for a row whose art sits on the leading edge.
  static const LinearGradient scrimSide = LinearGradient(
    colors: [Color(0xCC000000), Color(0x00000000)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Frosted veil used behind the bottom navigation and app bars.
  static LinearGradient veil(Color surface) => LinearGradient(
        colors: [surface.withValues(alpha: 0.94), surface.withValues(alpha: 0.99)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  /// The quiet wash a picker or highlight panel sits on: brand blue at the top
  /// corner easing into the surface, so a control reads as lit rather than boxed.
  static LinearGradient tint(Color surface, Color accent) => LinearGradient(
        colors: [surface, accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
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

  /// One low, wide shadow for elements smaller than a card: a chip, a pill, a
  /// cover tile. The two-layer `card` shadow is overkill at that size and makes
  /// a small control look muddy.
  static List<BoxShadow> soft(Color tint, {double depth = 6, bool dark = false}) => [
        BoxShadow(
          color: tint.withValues(alpha: dark ? 0.32 : 0.07),
          blurRadius: depth * 2,
          offset: Offset(0, depth / 2),
        ),
      ];

  /// The bottom bar casts upward, which is the only way a navigation surface
  /// reads as lifted from the content it floats over.
  static List<BoxShadow> raised(Color tint, {bool dark = false}) => [
        BoxShadow(
          color: tint.withValues(alpha: dark ? 0.40 : 0.10),
          blurRadius: 20,
          offset: const Offset(0, -6),
        ),
      ];
}
