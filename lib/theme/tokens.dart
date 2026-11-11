import 'package:flutter/material.dart';

/// Single palette aligned with the site (`site/src/index.css`).
///
/// Text colors meet WCAG AA (4.5:1) on [page] and on white:
/// ink, sub `#4C6B71` (5.2 on page), faint `#4E7484` (4.6 on page;
/// `#557A87` is only 4.2 on the sage page, so it is darkened),
/// amber text `#8A6516` (4.8), success text `#1F7A52` (4.8).
/// Buttons use teal `#1A6B8A` with white text (6.0). Cyan is decoration.
abstract final class MsdTokens {
  static const page = Color(0xFFEEF5F1);
  static const pageDeep = Color(0xFFDDEAE3);
  static const paper = Color(0xFFF4F8F9);
  static const fog = Color(0xFFF7FBFA);
  static const white = Color(0xFFFFFFFF);
  static const onDeep = Color(0xFFF2F9F6);

  static const ink = Color(0xFF143139);
  static const sub = Color(0xFF4C6B71);
  static const faint = Color(0xFF4E7484);

  /// Buttons and white-on-teal text. Not used as a decorative cyan.
  static const teal = Color(0xFF1A6B8A);
  static const deep = Color(0xFF123840);

  /// Borders, icons, and decoration only.
  static const cyan = Color(0xFF0F8F86);
  static const sky = Color(0xFF7EC8E3);
  static const mint = Color(0xFF57C9B3);
  static const blue = Color(0xFF3A7BA6);

  static const success = Color(0xFF1F7A52);
  static const successFill = Color(0xFF2E9E6C);
  static const danger = Color(0xFFB42318);
  static const amberText = Color(0xFF8A6516);
  static const amberFill = Color(0xFFC0913A);

  static const mist = Color(0xFFE7F4F1);
  static const mintWash = Color(0xFFE7F7F4);
  static const amberSoft = Color(0xFFFFF8EC);
  static const dangerSoft = Color(0xFFF8E6E4);

  static const line = Color(0x1F143139);
  static const lineSoft = Color(0x14143139);
  static const cyanLine = Color(0x334BA3C7);
  static const skyLine = Color(0x33A8D4E6);
  static const surface = Color(0x1F7EC8E3);
  static const tealWash = Color(0x241A6B8A);
  static const cyanWash = Color(0x1F0F8F86);
  static const dangerWash = Color(0x1AB42318);
  static const successWash = Color(0x292E9E6C);
  static const amberWash = Color(0x33C0913A);
  static const mintLine = Color(0x3357C9B3);
  static const deepWash = Color(0x221C4A54);
  static const pageWash = Color(0x66EAF6FB);
  static const whiteWash = Color(0x22FFFFFF);
  static const transparent = Color(0x00000000);
}
