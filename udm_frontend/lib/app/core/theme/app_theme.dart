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

  static const radiusCard = 18.0;
  static const radiusSheet = 24.0;
}

class AppTypography {
  const AppTypography._();

  /// Dynamic type is supported by scaling these rather than hardcoding sizes in
  /// features; `TextScaler` is honoured by `ThemeData.textTheme`.
  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
        displaySmall: TextStyle(
          fontSize: 30,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: primary,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: primary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
        bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: primary),
        bodyMedium: TextStyle(fontSize: 14.5, height: 1.5, color: primary),
        bodySmall: TextStyle(fontSize: 13, height: 1.45, color: secondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
        labelMedium: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: secondary,
        ),
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
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        canvas: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        elevated: AppColors.darkElevated,
        scriptureSurface: AppColors.darkLightBlue,
        text: AppColors.darkModeText,
        textSecondary: AppColors.darkModeSecondaryText,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color canvas,
    required Color surface,
    required Color elevated,
    required Color scriptureSurface,
    required Color text,
    required Color textSecondary,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: brightness,
      primary: AppColors.primaryBlue,
      surface: surface,
    ).copyWith(
      onSurface: text,
      onSurfaceVariant: textSecondary,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: canvas,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme(text, textSecondary),
      dividerTheme: DividerThemeData(color: textSecondary.withValues(alpha: 0.16), thickness: 1),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: text),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.primaryBlue,
        titleTextStyle: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: text),
        subtitleTextStyle: TextStyle(fontSize: 13.5, color: textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scriptureSurface,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.primaryBlue : textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? AppColors.primaryBlue : textSecondary,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      extensions: <ThemeExtension<dynamic>>[
        AppSurfaces(elevated: elevated, scripture: scriptureSurface),
      ],
    );
  }
}

/// Extra surfaces that Material's `ColorScheme` has no slot for.
@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({required this.elevated, required this.scripture});

  final Color elevated;
  final Color scripture;

  @override
  AppSurfaces copyWith({Color? elevated, Color? scripture}) => AppSurfaces(
        elevated: elevated ?? this.elevated,
        scripture: scripture ?? this.scripture,
      );

  @override
  AppSurfaces lerp(covariant AppSurfaces? other, double t) => this;
}
