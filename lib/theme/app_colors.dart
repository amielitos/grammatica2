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
  static const Color textPrimaryLight = Colors.black;
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryLight = Color(0xFF86868B);
  static const Color textSecondaryDark = Color(0xFFAEB1B7);

  static const Color textPrimary =
      Colors.black; // Default, will be handled by theme
  static const Color textSecondary = Color(0xFF86868B); // Default
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

  /// Superadmin colors
  static const Color superAdminBgDark = Color(0xFF0F1A20);
  static const Color superAdminBgLight = Color(0xFFE2856E);
  static const Color primaryGreen = Color(0xFFA5D6A7); // Pastel Green
  static const Color adminBackgroundLight = Color(0xFFF8F9FA);
  static const Color salmonBackground = primaryGreen;
  static const Color cardOffWhite = Color(0xFFFDFDFD);
  static const Color cardNearBlack = Color(0xFF0F0F0F);
  static const Color softBorder = Color(0x1F000000);
  static const Color darkBorder = Color(0x1FFFFFFF);

  /// Redesign colors
  static const Color registrationGreen = Color(0xFF94C35F);
  static const Color authCardBg = Color(0xFFF1F5E9);
  static const Color authTextPrimary = Color(0xFF1D2125);
  static const Color authTextSecondary = Color(0xFF626F86);

  /// Gradients
  /// Used for backgrounds and active elements.
  static const LinearGradient authGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC8E6C9), // Green 100
      Color(0xFFDCEDC8), // Lime 100
      Color(0xFFC5E1A5), // Lime 200
    ],
  );

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

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A1A), // Dark Grey
      Color(0xFF2C2C2C), // Medium Dark Grey
      Color(0xFF121212), // Near Black
    ],
  );

  /// Returns the main background gradient based on the theme.
  static LinearGradient getMainGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkGradient : authGradient;
  }

  /// Returns the card background color based on the theme.
  static Color getCardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? cardNearBlack : cardOffWhite;
  }

  static Color getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? textPrimaryDark : textPrimaryLight;
  }

  static Color getSecondaryTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? textSecondaryDark : textSecondaryLight;
  }
}

/// Helper class to group rainbow colors (Pink-Focused).
class _RainbowColors {
  const _RainbowColors();

  /// Pastel Red/Melon
  final Color red = const Color(0xFFFFB7B2);

  /// Pale Yellow
  final Color orange = const Color(0xFFF0F4C3);

  /// Muted Pastel Yellow
  final Color yellow = const Color(0xFFFFF9E0);

  /// Pale Green
  final Color green = const Color(0xFFE2F0CB);

  /// Mint
  final Color mint = const Color(0xFFB5EAD7);

  /// Pale Blue
  final Color blue = const Color(0xFFC7CEEA);

  /// Classic Pastel Pink
  final Color violet = const Color(0xFFF8C8DC);

  /// Returns a list of all colors.
  List<Color> get all => [violet, red, yellow, green, mint, blue, orange];

  /// Returns a color by index.
  Color elementAt(int index) => all[index % all.length];
}
