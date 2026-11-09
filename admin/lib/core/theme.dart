import 'package:flutter/material.dart';

/// Placeholder brand palette (docs/03-design.md §2) until the final branding.
abstract final class BrandColors {
  static const forest = Color(0xFF1F4D3A);
  static const forestDark = Color(0xFF163A2B);
  static const sand = Color(0xFFC8A15A);
  static const paper = Color(0xFFFAF8F3);
  static const ink = Color(0xFF1E2422);
  static const line = Color(0xFFE4DFD3);

  // Status colours: sold is a success, so never red.
  static const available = Color(0xFF2E7D4F);
  static const reserved = Color(0xFFB7791F);
  static const sold = Color(0xFF5B6770);
  static const danger = Color(0xFFB3261E);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.forest,
    primary: BrandColors.forest,
    secondary: BrandColors.sand,
    surface: Colors.white,
    error: BrandColors.danger,
  );
  const radius = BorderRadius.all(Radius.circular(12));
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: BrandColors.paper,
    dividerColor: BrandColors.line,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: BrandColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: BrandColors.line),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dataTableTheme: const DataTableThemeData(
      headingTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: BrandColors.ink,
      ),
    ),
  );
}
