import 'package:flutter/material.dart';

/// Shared visual tokens for every Finance AI web feature.
abstract final class AppTheme {
  static const spacing = AppSpacing();
  static const radius = AppRadius();

  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.info,
      onSecondary: Colors.white,
      error: AppColors.negative,
      onError: Colors.white,
      surface: dark ? AppColors.surface : const Color(0xFFF8F7FC),
      onSurface: dark ? AppColors.textPrimary : const Color(0xFF17131E),
    );
    final outline = dark ? AppColors.border : const Color(0xFFE4E0EA);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Roboto',
      textTheme: Typography.material2021().white
          .copyWith(
            displaySmall: const TextStyle(
              fontSize: 36,
              height: 1.1,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            headlineMedium: const TextStyle(
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.4),
            labelLarge: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          )
          .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      dividerColor: outline,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? AppColors.surface : scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: dark ? const Color(0xFF17141F) : Colors.white,
        indicatorColor: AppColors.brand.withValues(alpha: 0.24),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF211C29),
        modalBackgroundColor: Color(0xFF211C29),
        showDragHandle: true,
      ),
      cardTheme: CardThemeData(
        color: dark ? AppColors.surfaceElevated : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.large),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1B1724) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.medium),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.medium),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.medium),
          borderSide: const BorderSide(color: AppColors.brand, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.medium),
          ),
          side: BorderSide(color: outline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.medium),
        ),
      ),
    );
  }
}

abstract final class AppColors {
  static const brand = Color(0xFF9B7BFF);
  static const info = Color(0xFF5DA9FF);
  static const positive = Color(0xFF3DD6A0);
  static const negative = Color(0xFFFF708C);
  static const warning = Color(0xFFFFC65A);
  static const crypto = Color(0xFFF6B64A);
  static const galaxyStart = Color(0xFF0B0820);
  static const galaxyEnd = Color(0xFF121C3F);
  static const surface = Color(0xFF121019);
  static const surfaceElevated = Color(0xFF1B1724);
  static const border = Color(0xFF30293A);
  static const textPrimary = Color(0xFFF4F0FA);
  static const textSecondary = Color(0xFFC5BDCF);
  static const textMuted = Color(0xFF91889F);
}

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x33000000), blurRadius: 28, offset: Offset(0, 12)),
  ];
}

abstract final class AppAnimations {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
}

class AppSpacing {
  const AppSpacing();
  final double xs = 4;
  final double sm = 8;
  final double md = 16;
  final double lg = 24;
  final double xl = 32;
  final double xxl = 48;
}

class AppRadius {
  const AppRadius();
  final double small = 10;
  final double medium = 14;
  final double large = 22;
  final double xl = 30;
}
