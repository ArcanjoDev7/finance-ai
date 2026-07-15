import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = AppColors.brand;
  static const spacing = AppSpacing();
  static const radius = AppRadius();

  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: Typography.material2021().black.apply(
            bodyColor: colorScheme.onSurface,
            displayColor: colorScheme.onSurface,
          ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.medium)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius.medium)),
      ),
    );
  }
}

abstract final class AppColors {
  static const brand = Color(0xFF0B6E4F);
  static const positive = Color(0xFF087F5B);
  static const negative = Color(0xFFC92A2A);
  static const warning = Color(0xFFF08C00);
}

abstract final class AppShadows {
  static const card = [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4))];
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
}

class AppRadius {
  const AppRadius();
  final double small = 8;
  final double medium = 12;
  final double large = 20;
}
