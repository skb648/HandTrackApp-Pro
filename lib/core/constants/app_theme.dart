import 'package:flutter/material.dart';

/// AirTouch Ultimate Design System - Deep Blue/Indigo Theme
class AppTheme {
  AppTheme._();

  // PRIMARY PALETTE
  static const Color primary900 = Color(0xFF0A0E21);
  static const Color primary800 = Color(0xFF0F1629);
  static const Color primary700 = Color(0xFF151D38);
  static const Color primary600 = Color(0xFF1A2348);
  static const Color primary500 = Color(0xFF1E2A5A);

  // ACCENT COLORS
  static const Color accent = Color(0xFF6366F1);
  static const Color accentLight = Color(0xFF818CF8);
  static const Color accentDark = Color(0xFF4F46E5);

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonCyan = Color(0xFF00F0FF);

  // SEMANTIC COLORS
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // GESTURE COLORS
  static const Color gestureClick = Color(0xFF6366F1);
  static const Color gestureBack = Color(0xFFF97316);
  static const Color gestureRecents = Color(0xFF8B5CF6);
  static const Color gestureScroll = Color(0xFF10B981);
  static const Color gestureDrag = Color(0xFF06B6D4);

  // ZONE COLORS
  static const Color zonePinkyL = Color(0xFFFF6B6B);
  static const Color zoneRingL = Color(0xFFFFB347);
  static const Color zoneMiddleL = Color(0xFFFFE66D);
  static const Color zoneIndexL = Color(0xFF6BCB77);
  static const Color zoneThumb = Color(0xFF74B9FF);
  static const Color zoneIndexR = Color(0xFFA29BFE);
  static const Color zoneMiddleR = Color(0xFFFD79A8);
  static const Color zoneRingR = Color(0xFFE17055);
  static const Color zonePinkyR = Color(0xFF00CEC9);

  // GLASSMORPHISM COLORS
  static const Color glassBackground = Color(0x1AFFFFFF);
  static const Color glassBorderColor = Color(0x33FFFFFF);
  static const Color glassHighlight = Color(0x0DFFFFFF);
  static const Color glassShadow = Color(0x40000000);
  
  // Convenience getter for glass border color (for backward compatibility)
  static Color get glassBorder => glassBorderColor;

  // TEXT COLORS
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x80FFFFFF);
  static const Color textHint = Color(0x4DFFFFFF);

  // GRADIENTS
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary900, primary800, primary700],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentLight, accent, accentDark],
  );

  // SHADOWS
  static const List<BoxShadow> neonShadow = [
    BoxShadow(
      color: neonGreen,
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  // BORDER RADIUS
  static BorderRadius cardRadius = BorderRadius.circular(20);
  static BorderRadius buttonRadius = BorderRadius.circular(12);

  // SPACING
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  // LASER COLORS
  static const Color laserLeft = Color(0xFF4F8EF7);
  static const Color laserRight = Color(0xFFF74F4F);

  // THEME DATA
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: accent,
      scaffoldBackgroundColor: primary900,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentLight,
        surface: primary800,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: buttonRadius,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x1AFFFFFF),
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: textPrimary,
      ),
    );
  }
}
