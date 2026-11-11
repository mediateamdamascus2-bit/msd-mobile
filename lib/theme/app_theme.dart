import 'package:flutter/material.dart';

import 'tokens.dart';

export 'tokens.dart';

/// Names kept so existing screens compile. Values come from [MsdTokens].
abstract final class MsdColors {
  static const ink = MsdTokens.ink;
  static const sub = MsdTokens.sub;
  static const faint = MsdTokens.faint;
  static const cyan = MsdTokens.cyan;
  static const teal = MsdTokens.teal;
  static const green = MsdTokens.success;
  static const danger = MsdTokens.danger;
  static const amber = MsdTokens.amberText;
  static const line = MsdTokens.line;
  static const surface = MsdTokens.surface;
  static const mist = MsdTokens.page;
  static const fog = MsdTokens.fog;
  static const deep = MsdTokens.deep;
  static const deepMid = MsdTokens.teal;
  static const sky = MsdTokens.sky;
}

abstract final class AppTheme {
  static const _text = TextTheme(
    displaySmall: TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w800, color: MsdTokens.ink),
    headlineSmall: TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w800, color: MsdTokens.ink),
    titleLarge: TextStyle(fontSize: 18, height: 1.3, fontWeight: FontWeight.w800, color: MsdTokens.ink),
    titleMedium: TextStyle(fontSize: 18, height: 1.3, fontWeight: FontWeight.w700, color: MsdTokens.ink),
    bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: MsdTokens.ink),
    bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: MsdTokens.ink),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: MsdTokens.sub),
    labelLarge: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w700, color: MsdTokens.ink),
    labelMedium: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600, color: MsdTokens.sub),
    labelSmall: TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600, color: MsdTokens.faint),
  );

  static ThemeData light() {
    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: MsdTokens.cyanLine),
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: MsdTokens.teal,
      brightness: Brightness.light,
      primary: MsdTokens.teal,
      onPrimary: MsdTokens.white,
      secondary: MsdTokens.cyan,
      surface: MsdTokens.white,
      error: MsdTokens.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: MsdTokens.page,
      fontFamily: 'Tajawal',
      textTheme: _text,
      primaryTextTheme: _text,
      appBarTheme: const AppBarTheme(
        backgroundColor: MsdTokens.deep,
        foregroundColor: MsdTokens.onDeep,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: MsdTokens.onDeep,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MsdTokens.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: MsdTokens.teal, width: 1.8),
        ),
        errorStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: MsdTokens.danger),
        labelStyle: const TextStyle(fontFamily: 'Tajawal', color: MsdTokens.teal, fontSize: 13, fontWeight: FontWeight.w700),
        floatingLabelStyle: const TextStyle(fontFamily: 'Tajawal', color: MsdTokens.teal, fontWeight: FontWeight.w700),
        hintStyle: const TextStyle(fontFamily: 'Tajawal', color: MsdTokens.faint, fontSize: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MsdTokens.teal,
          foregroundColor: MsdTokens.white,
          disabledBackgroundColor: MsdTokens.teal,
          disabledForegroundColor: MsdTokens.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MsdTokens.white,
        selectedColor: MsdTokens.teal,
        disabledColor: MsdTokens.surface,
        labelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700, color: MsdTokens.sub),
        secondaryLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700, color: MsdTokens.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: MsdTokens.cyanLine),
        ),
        side: const BorderSide(color: MsdTokens.cyanLine),
        showCheckmark: false,
      ),
      cardTheme: CardThemeData(
        color: MsdTokens.white.withValues(alpha: 0.94),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: MsdTokens.line),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: MsdTokens.line,
    );
  }
}
