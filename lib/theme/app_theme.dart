import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Medical Services Directorate visual tokens ? aligned with Harasta sky skin.
abstract final class MsdColors {
  static const ink = Color(0xFF0E3A4A);
  static const sub = Color(0xFF3D6A7A);
  static const faint = Color(0xFF7A9EAB);
  static const cyan = Color(0xFF4BA3C7);
  static const teal = Color(0xFF1A6B8A);
  static const green = Color(0xFF2E9E6C);
  static const danger = Color(0xFFB42318);
  static const amber = Color(0xFFC0913A);
  static const line = Color(0x241A6B8A);
  static const surface = Color(0x1F7EC8E3);
  static const mist = Color(0xFFEAF6FB);
  static const fog = Color(0xFFF5FBFD);
  static const deep = Color(0xFF0F4A62);
  static const deepMid = Color(0xFF1A6B8A);
  static const sky = Color(0xFF7EC8E3);
}

abstract final class AppTheme {
  static ThemeData light() {
    final base = GoogleFonts.tajawalTextTheme();
    final textTheme = base.apply(
      bodyColor: MsdColors.ink,
      displayColor: MsdColors.ink,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: MsdColors.cyan,
      brightness: Brightness.light,
      primary: MsdColors.cyan,
      onPrimary: Colors.white,
      secondary: MsdColors.teal,
      surface: Colors.white,
      error: MsdColors.danger,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0x334BA3C7)),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: MsdColors.mist,
      fontFamily: GoogleFonts.tajawal().fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: MsdColors.deepMid,
        foregroundColor: const Color(0xFFF2F9F6),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.tajawal(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFF2F9F6),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: MsdColors.cyan, width: 1.8),
        ),
        labelStyle: GoogleFonts.tajawal(color: MsdColors.teal, fontSize: 13, fontWeight: FontWeight.w700),
        floatingLabelStyle: GoogleFonts.tajawal(
          color: MsdColors.teal,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: GoogleFonts.tajawal(color: MsdColors.faint, fontSize: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MsdColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: MsdColors.teal,
        disabledColor: MsdColors.surface,
        labelStyle: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: MsdColors.sub),
        secondaryLabelStyle: GoogleFonts.tajawal(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x334BA3C7)),
        ),
        side: const BorderSide(color: Color(0x334BA3C7)),
        showCheckmark: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.94),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: MsdColors.line),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: MsdColors.line,
    );
  }
}
