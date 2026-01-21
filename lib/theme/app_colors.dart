import 'package:flutter/material.dart';

/// AppColors defines the color palette for the Grammatica app.
/// This file is designed to be easily customizable.
///
/// The [rainbow] class contains the core pastel rainbow palette.
/// You can change these hex values to adjust the theme of the entire app.
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  /// The primary rainbow palette.
  ///
  /// How to customize:
  /// Simply replace the Color(0xFF...) values with your desired colors.
  ///
  /// Tools for picking colors:
  /// - https://coolors.co/
  /// - https://material.io/resources/color/
  ///
  /// Current Palette: Pastel Rainbow
  static const rainbow = _RainbowColors();

  /// Solid colors for text and backgrounds
  static const Color textPrimary = Colors.black; // Maximum contrast for 'Pop'
  static const Color textSecondary = Color(0xFF86868B); // Apple-style gray
  static const Color backgroundLight = Color(
    0xFFF5F5F7,
  ); // Light gray background
  static const Color backgroundDark = Color(
    0xFF1C1C1E,
  ); // iOS dark gray background
  static const Color glassWhite = Color(0xCCFFFFFF); // Semi-transparent white
  static const Color glassBlack = Color(0xCC1C1C1E); // Semi-transparent black
  static const Color glassBorder = Color(0x33FFFFFF); // Subtle border
  static const Color glassBorderDark = Color(0x33000000); // Subtle border dark

  /// Gradients
  /// Used for backgrounds and active elements.
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFDE4E1), // Very pale pink
      Color(0xFFF8C8DC), // Pastel Pink
      Color(0xFFFFDAC1), // Peach
      Color(0xFFFFB7B2), // Melon (darker pink/red)
    ],
  );
}

/// Helper class to group rainbow colors (Pink-Focused).
class _RainbowColors {
  const _RainbowColors();

  /// Pastel Red/Melon
  final Color red = const Color(0xFFFFB7B2);

  /// Pastel Peach
  final Color orange = const Color(0xFFFFDAC1);

  /// Creamy Yellow
  final Color yellow = const Color(0xFFFFF5BA);

  /// Pale Green
  final Color green = const Color(0xFFE2F0CB);

  /// Mint
  final Color mint = const Color(0xFFB5EAD7);

  /// Pale Blue
  final Color blue = const Color(0xFFC7CEEA);

  /// Classic Pastel Pink
  final Color violet = const Color(0xFFF8C8DC);

  /// Returns a list of all colors.
  List<Color> get all => [violet, red, orange, yellow, green, mint, blue];

  /// Returns a color by index.
  Color elementAt(int index) => all[index % all.length];
}
