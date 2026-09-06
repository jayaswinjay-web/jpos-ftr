import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Color(0xFF1A73E8);
  static const Color primaryContainer = Color(0xFFD2E3FC);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF041E49);

  // Secondary palette
  static const Color secondary = Color(0xFF5F6368);
  static const Color secondaryContainer = Color(0xFFE8EAED);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF202124);

  // Surface
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F4);
  static const Color onSurface = Color(0xFF202124);
  static const Color onSurfaceVariant = Color(0xFF5F6368);

  // Dark surface
  static const Color darkSurface = Color(0xFF1F1F1F);
  static const Color darkSurfaceVariant = Color(0xFF2D2D2D);
  static const Color darkOnSurface = Color(0xFFE8EAED);
  static const Color darkOnSurfaceVariant = Color(0xFF9AA0A6);

  // Semantic colors
  static const Color success = Color(0xFF1E8E3E);
  static const Color successContainer = Color(0xFFCEFAD0);
  static const Color warning = Color(0xFFF9AB00);
  static const Color warningContainer = Color(0xFFFEF7E0);
  static const Color danger = Color(0xFFD93025);
  static const Color dangerContainer = Color(0xFFFCE8E6);
  static const Color info = Color(0xFF1967D2);
  static const Color infoContainer = Color(0xFFE8F0FE);

  // Chart colors
  static const List<Color> chartColors = [
    Color(0xFF1A73E8),
    Color(0xFF34A853),
    Color(0xFFF9AB00),
    Color(0xFFEA4335),
    Color(0xFFAB47BC),
    Color(0xFF00BCD4),
    Color(0xFFFF7043),
    Color(0xFF9E9E9E),
  ];
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  AppRadius._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 9999;
}

class AppElevation {
  AppElevation._();

  static const double sm = 1;
  static const double md = 2;
  static const double lg = 4;
  static const double xl = 8;
}
