import 'package:flutter/material.dart';

/// AppColors defines the absolute bare bones color palette for the Grammatica app.
class AppColors {
  AppColors._();

  // Core Brand Colors
  static const Color primary = Color(0xFF2E7D32);
  static const Color secondary = Color(0xFF455A64);

  // Backgrounds and Surfaces
  static const Color backgroundLight = Color(0xFFFDFDFD);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF1D1B20);
  static const Color textPrimaryDark = Color(0xFFE6E1E5);
  static const Color textSecondaryLight = Color(0xFF49454F);
  static const Color textSecondaryDark = Color(0xFFCAC4D0);

  // Status
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF2E7D32);

  // Retained for minimal functional mapping
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimaryDark
        : textPrimaryLight;
  }
}
