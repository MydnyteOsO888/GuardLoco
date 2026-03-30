import 'package:flutter/material.dart';

class AppTheme {
  // ── Colors ──────────────────────────────────────────────
  static const Color bgColor      = Color(0xFF080B12);
  static const Color surfaceColor = Color(0xFF0F1219);
  static const Color surface2     = Color(0xFF161B25);
  static const Color borderColor  = Color(0xFF1E2530);
  static const Color accentColor  = Color(0xFF00D4FF);
  static const Color redColor     = Color(0xFFFF3B5C);
  static const Color greenColor   = Color(0xFF00E676);
  static const Color yellowColor  = Color(0xFFFFC107);
  static const Color purpleColor  = Color(0xFF7C4DFF);
  static const Color textColor    = Color(0xFFDDE3EE);
  static const Color mutedColor   = Color(0xFF5A6477);
  static const Color muted2Color  = Color(0xFF8899AA);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      fontFamily: 'Syne',
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: greenColor,
        surface: surfaceColor,
        error: redColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: TextStyle(
          fontFamily: 'Syne',
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: textColor,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardTheme(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderColor),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgColor,
        selectedItemColor: accentColor,
        unselectedItemColor: mutedColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: bgColor,
          textStyle: const TextStyle(
            fontFamily: 'Syne',
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentColor),
        ),
        labelStyle: const TextStyle(color: mutedColor),
        hintStyle: const TextStyle(color: mutedColor),
      ),
      dividerColor: borderColor,
      iconTheme: const IconThemeData(color: muted2Color),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Syne', fontWeight: FontWeight.w800,
          color: textColor, letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Syne', fontWeight: FontWeight.w700,
          color: textColor,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Syne', fontWeight: FontWeight.w700,
          color: textColor,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Syne', fontWeight: FontWeight.w600,
          color: textColor,
        ),
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: muted2Color),
        bodySmall: TextStyle(
          fontFamily: 'JetBrains Mono', color: muted2Color, fontSize: 11,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Syne', fontWeight: FontWeight.w700,
          color: mutedColor, letterSpacing: 1.5, fontSize: 10,
        ),
      ),
    );
  }
}
