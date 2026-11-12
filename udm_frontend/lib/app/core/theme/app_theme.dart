import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 8-point spacing rhythm used by every screen.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double screen = 20;

  static const radiusCard = 22.0;
  static const radiusSheet = 28.0;
  static const radiusField = 16.0;
  static const radiusTile = 14.0;
  static const radiusPill = 999.0;

  /// The gradient icon tile shared by content rows and status panels.
  static const double iconTile = 46;

  /// The artwork square on a Learn shelf row: bigger than an icon tile because
  /// it carries the ministry's own cover, not a glyph.
  static const double shelfArt = 72;
}

/// Bundled families, declared in `pubspec.yaml`. Features ask for these by
/// role, never by vendor name, so a future rebrand touches one file.
class AppFonts {
  const AppFonts._();

  static const String ui = 'Brand Sans';
  static const String scripture = 'Scripture Serif';
}

class AppTypography {
  const AppTypography._();

  /// Dynamic type is supported by scaling these rather than hardcoding sizes in
  /// features; `TextScaler` is honoured by `ThemeData.textTheme`.
  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          height: 1.12,
          fontWeight: FontWeight.w800,
          color: primary,
          letterSpacing: -0.7,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          height: 1.16,
          fontWeight: FontWeight.w800,
          color: primary,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 23,
          height: 1.22,
          fontWeight: FontWeight.w700,
          color: primary,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          height: 1.28,
          fontWeight: FontWeight.w700,
          color: primary,
          letterSpacing: -0.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 17.5,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        titleLarge: TextStyle(fontSize: 18, height: 1.3, fontWeight: FontWeight.w700, color: primary),
        titleMedium: TextStyle(fontSize: 15.5, height: 1.35, fontWeight: FontWeight.w700, color: primary),
        titleSmall: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: primary),
        bodyLarge: TextStyle(fontSize: 16.5, height: 1.62, color: primary),
        bodyMedium: TextStyle(fontSize: 14.5, height: 1.55, color: primary),
        bodySmall: TextStyle(fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w500, color: secondary),
        labelLarge: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: primary, letterSpacing: 0.1),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: secondary,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          color: secondary,
        ),
        // One family for the whole scale: features set size and weight by role,
        // and nobody has to remember to repeat `fontFamily`.
      ).apply(fontFamily: AppFonts.ui);

  /// Reading faces. Scripture and devotion bodies are set in a serif on purpose:
  /// the eye treats it differently from chrome, and the app should too.
  static TextStyle scriptureBody(Color primary) => TextStyle(
        fontFamily: AppFonts.scripture,
        fontSize: 18.5,
        height: 1.75,
        fontWeight: FontWeight.w400,
        color: primary,
        letterSpacing: 0.1,
      );

  static TextStyle scriptureVerse(Color primary, {double size = 22}) => TextStyle(
        fontFamily: AppFonts.scripture,
        fontSize: size,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: primary,
        letterSpacing: 0.15,
      );

  static TextStyle scriptureReference(Color secondary) => TextStyle(
        fontFamily: AppFonts.scripture,
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        color: secondary,
      );

  /// Small all-caps label above a section or card.
  static TextStyle eyebrow(Color color) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: color,
      );
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        canvas: AppColors.background,
        surface: AppColors.white,
        elevated: AppColors.white,
        scriptureSurface: AppColors.lightBlue,
        text: AppColors.darkText,
        textSecondary: AppColors.secondaryText,
        hairline: const Color(0x14123B63),
        shadowTint: AppColors.deepBlue,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        canvas: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        elevated: AppColors.darkElevated,
        scriptureSurface: AppColors.darkLightBlue,
        text: AppColors.darkModeText,
        textSecondary: AppColors.darkModeSecondaryText,
        hairline: const Color(0x33A9CBE8),
        shadowTint: AppColors.darkInk,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color canvas,
    required Color surface,
    required Color elevated,
    required Color scriptureSurface,
    required Color text,
    required Color textSecondary,
    required Color hairline,
    required Color shadowTint,
  }) {
    final dark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: brightness,
      primary: dark ? AppColors.royalBlue : AppColors.primaryBlue,
      surface: surface,
    ).copyWith(
      onSurface: text,
      onSurfaceVariant: textSecondary,
      error: AppColors.danger,
      secondary: AppColors.gold,
      tertiary: AppColors.success,
      outlineVariant: hairline,
    );

    final textTheme = AppTypography.textTheme(text, textSecondary);
    final radius = BorderRadius.circular(AppSpacing.radiusCard);

    OutlineInputBorder fieldBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusField),
          borderSide: width <= 1 ? BorderSide(color: color) : BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: canvas,
      colorScheme: colorScheme,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      dividerColor: hairline,
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: textSecondary, size: 22),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: hairline),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium?.copyWith(color: text),
        iconTheme: IconThemeData(color: text, size: 22),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusField)),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusField)),
          textStyle: textTheme.labelLarge?.copyWith(color: AppColors.white),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: hairline, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusField)),
          textStyle: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? elevated : const Color(0xFFF4F8FC),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary, fontWeight: FontWeight.w600),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: colorScheme.primary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: fieldBorder(hairline),
        enabledBorder: fieldBorder(hairline),
        focusedBorder: fieldBorder(colorScheme.primary, 1.8),
        errorBorder: fieldBorder(AppColors.danger),
        focusedErrorBorder: fieldBorder(AppColors.danger, 1.8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scriptureSurface,
        side: BorderSide(color: hairline),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium?.copyWith(color: colorScheme.primary),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: text),
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: textSecondary.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusField)),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: hairline)),
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadowTint.withValues(alpha: dark ? 0.5 : 0.12),
        indicatorColor: scriptureSurface,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? colorScheme.primary : textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: states.contains(WidgetState.selected) ? colorScheme.primary : textSecondary,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: scriptureSurface,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? AppColors.darkElevated : AppColors.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(fontFamily: AppFonts.ui, color: AppColors.white, fontSize: 12.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppColors.darkElevated : AppColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusField)),
        elevation: 4,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppSurfaces(
          elevated: elevated,
          scripture: scriptureSurface,
          hairline: hairline,
          shadowTint: shadowTint,
          hero: dark ? AppGradients.heroDark : AppGradients.hero,
          scriptureCard: dark ? AppGradients.scriptureDark : AppGradients.scripture,
          sheen: dark ? AppGradients.sheenDark : AppGradients.sheen,
        ),
      ],
    );
  }
}

/// Extra surfaces that Material's `ColorScheme` has no slot for.
@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.elevated,
    required this.scripture,
    this.hairline = const Color(0x14123B63),
    this.shadowTint = AppColors.deepBlue,
    this.hero = AppGradients.hero,
    this.scriptureCard = AppGradients.scripture,
    this.sheen = AppGradients.sheen,
  });

  final Color elevated;
  final Color scripture;
  final Color hairline;
  final Color shadowTint;
  final Gradient hero;
  final Gradient scriptureCard;
  final Gradient sheen;

  BorderRadius get radius => BorderRadius.circular(AppSpacing.radiusCard);

  /// The lifted-card treatment used by every card-like surface: sheen, hairline
  /// and a tinted shadow together, so screens never hand-roll their own.
  BoxDecoration card({bool border = true}) => BoxDecoration(
        gradient: sheen,
        borderRadius: radius,
        boxShadow: AppShadows.card(shadowTint),
        border: border ? Border.all(color: hairline) : null,
      );

  @override
  AppSurfaces copyWith({
    Color? elevated,
    Color? scripture,
    Color? hairline,
    Color? shadowTint,
    Gradient? hero,
    Gradient? scriptureCard,
    Gradient? sheen,
  }) =>
      AppSurfaces(
        elevated: elevated ?? this.elevated,
        scripture: scripture ?? this.scripture,
        hairline: hairline ?? this.hairline,
        shadowTint: shadowTint ?? this.shadowTint,
        hero: hero ?? this.hero,
        scriptureCard: scriptureCard ?? this.scriptureCard,
        sheen: sheen ?? this.sheen,
      );

  @override
  AppSurfaces lerp(covariant AppSurfaces? other, double t) {
    if (other == null) return this;
    return AppSurfaces(
      elevated: Color.lerp(elevated, other.elevated, t)!,
      scripture: Color.lerp(scripture, other.scripture, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      shadowTint: Color.lerp(shadowTint, other.shadowTint, t)!,
      hero: Gradient.lerp(hero, other.hero, t)!,
      scriptureCard: Gradient.lerp(scriptureCard, other.scriptureCard, t)!,
      sheen: Gradient.lerp(sheen, other.sheen, t)!,
    );
  }
}
