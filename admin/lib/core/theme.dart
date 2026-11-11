import 'package:flutter/material.dart';

/// Placeholder brand palette (docs/03-design.md §2) until the final branding.
abstract final class BrandColors {
  static const forest = Color(0xFF1F4D3A);
  static const forestDark = Color(0xFF163A2B);
  static const sand = Color(0xFFC8A15A);
  static const paper = Color(0xFFFAF8F3);
  static const ink = Color(0xFF1E2422);
  static const line = Color(0xFFE4DFD3);

  // Dashboard design tones, shared by every page.
  static const cream = Color(0xFFF7F5EF);
  static const muted = Color(0xFF68736F);
  static const sage = Color(0xFFDCEDE3);
  static const text = Color(0xFF17211D);

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
  const radius = BorderRadius.all(Radius.circular(20));
  const fieldRadius = BorderRadius.all(Radius.circular(12));
  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );
  final base = ThemeData(colorScheme: scheme);
  final text = base.textTheme.apply(
    bodyColor: BrandColors.text,
    displayColor: BrandColors.text,
  );
  return base.copyWith(
    scaffoldBackgroundColor: BrandColors.cream,
    dividerColor: BrandColors.line,
    textTheme: text.copyWith(
      bodySmall: text.bodySmall?.copyWith(color: BrandColors.muted),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    dividerTheme: const DividerThemeData(color: BrandColors.line, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: BrandColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 1,
      shadowColor: Color(0x2217211D),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: Color(0xCCE4DFD3)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFFBFAF7),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: BrandColors.muted),
      hintStyle: TextStyle(color: BrandColors.muted),
      border: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: BrandColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: BrandColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: BrandColors.forest, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: BrandColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: BrandColors.danger, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: Color(0x80E4DFD3)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BrandColors.forest,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BrandColors.forest,
        backgroundColor: Colors.white,
        side: const BorderSide(color: BrandColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BrandColors.forest,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: buttonShape,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: BrandColors.sage,
      side: const BorderSide(color: BrandColors.line),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      labelStyle: const TextStyle(color: BrandColors.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: BrandColors.sage,
        selectedForegroundColor: BrandColors.forestDark,
        side: const BorderSide(color: BrandColors.line),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: BrandColors.forest,
      unselectedLabelColor: BrandColors.muted,
      indicatorColor: BrandColors.forest,
      dividerColor: BrandColors.line,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: BrandColors.line),
      ),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF0A4E3B)),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BrandColors.forest,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: BrandColors.text,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: BrandColors.text,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(BrandColors.cream),
      headingTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: BrandColors.muted,
      ),
      dataTextStyle: TextStyle(fontSize: 14, color: BrandColors.text),
      dividerThickness: 1,
    ),
  );
}
