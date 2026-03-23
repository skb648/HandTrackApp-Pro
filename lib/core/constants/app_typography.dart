import 'package:flutter/material.dart';
import 'package:airtouch_ultimate/core/constants/app_theme.dart';

/// Typography System for AirTouch Ultimate (using system fonts)
class AppTypography {
  AppTypography._();

  static const FontWeight thin = FontWeight.w100;
  static const FontWeight extraLight = FontWeight.w200;
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
  static const FontWeight black = FontWeight.w900;

  static const double fontSize9 = 9.0;
  static const double fontSize10 = 10.0;
  static const double fontSize11 = 11.0;
  static const double fontSize12 = 12.0;
  static const double fontSize13 = 13.0;
  static const double fontSize14 = 14.0;
  static const double fontSize15 = 15.0;
  static const double fontSize16 = 16.0;
  static const double fontSize18 = 18.0;
  static const double fontSize20 = 20.0;
  static const double fontSize24 = 24.0;
  static const double fontSize28 = 28.0;
  static const double fontSize32 = 32.0;
  static const double fontSize36 = 36.0;
  static const double fontSize48 = 48.0;

  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.5;

  static const TextStyle heading1 = TextStyle(
    fontSize: fontSize24,
    fontWeight: extraBold,
    letterSpacing: -0.25,
    height: lineHeightTight,
    color: AppTheme.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: fontSize20,
    fontWeight: bold,
    letterSpacing: -0.25,
    height: lineHeightTight,
    color: AppTheme.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: fontSize18,
    fontWeight: bold,
    letterSpacing: 0,
    height: lineHeightNormal,
    color: AppTheme.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: fontSize15,
    fontWeight: bold,
    letterSpacing: 0,
    height: lineHeightNormal,
    color: AppTheme.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: fontSize16,
    fontWeight: regular,
    letterSpacing: 0,
    height: lineHeightNormal,
    color: AppTheme.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: fontSize14,
    fontWeight: regular,
    letterSpacing: 0,
    height: lineHeightNormal,
    color: AppTheme.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: fontSize12,
    fontWeight: regular,
    letterSpacing: 0.25,
    height: lineHeightNormal,
    color: AppTheme.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: fontSize13,
    fontWeight: semiBold,
    letterSpacing: 0.25,
    height: lineHeightNormal,
    color: AppTheme.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: fontSize11,
    fontWeight: medium,
    letterSpacing: 0.25,
    height: lineHeightNormal,
    color: AppTheme.textSecondary,
  );

  static const TextStyle captionSmall = TextStyle(
    fontSize: fontSize10,
    fontWeight: medium,
    letterSpacing: 0.25,
    height: lineHeightNormal,
    color: AppTheme.textMuted,
  );

  static const TextStyle badge = TextStyle(
    fontSize: fontSize9,
    fontWeight: semiBold,
    letterSpacing: 0.5,
    height: lineHeightNormal,
    color: AppTheme.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontSize: fontSize14,
    fontWeight: bold,
    letterSpacing: 0.5,
    height: lineHeightNormal,
    color: AppTheme.textPrimary,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: fontSize28,
    fontWeight: black,
    letterSpacing: -0.5,
    height: lineHeightTight,
    color: AppTheme.textPrimary,
  );

  static const TextStyle emojiIcon = TextStyle(
    fontSize: fontSize48,
    height: 1.0,
  );

  static const TextStyle emojiIconSmall = TextStyle(
    fontSize: fontSize32,
    height: 1.0,
  );

  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }
}
