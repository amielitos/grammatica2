import 'package:flutter/material.dart';

/// AppColors defines the absolute bare bones color palette for the Grammatica app.
class AppColors {
  AppColors._();

  // Figma Brand Colors
  static const Color primary = Color(0xFF76A34F); // Soft leaf green
  static const Color secondary = Color(0xFFF5A623); // Yellow/Orange
  static const Color accent = Color(0xFF7ED321); // Bright Green
  static const Color premium = Color(0xFFD0021B); // Bright Red

  // Backgrounds and Surfaces from Figma
  static const Color backgroundBase = Color(0xFFFAF9F6); // Warm off-white
  static const Color backgroundLight = backgroundBase;
  static const Color blobLightGreen = Color(0xFFC5E1A5);
  static const Color blobLightYellow = Color(0xFFFFF9C4);
  static const Color surfaceWhite = Colors.white;
  static const Color cardShadow = Color(0x1A000000); // Subtle shadow

  // Text Colors
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);

  // Functional Colors
  static const Color divider = Color(0xFFE0E0E0);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFD32F2F);
  static const Color onSurfaceVariant = Color(0xFF70787D);

  static Color getTextColor(BuildContext context) {
    return textPrimary;
  }
}
