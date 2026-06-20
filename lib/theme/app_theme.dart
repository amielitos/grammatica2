import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // Shared text theme: Outfit for headings, Inter for body
  static TextTheme _buildTextTheme({required bool dark}) {
    final baseColor = dark ? Colors.white : AppColors.textPrimary;
    final subtleColor = dark ? Colors.white70 : AppColors.textSecondary;

    return GoogleFonts.interTextTheme().copyWith(
      // Display & headline styles → Outfit (bold, display-grade)
      displayLarge: GoogleFonts.outfit(
        fontSize: 57, fontWeight: FontWeight.w900,
        letterSpacing: -2.0, color: baseColor,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 45, fontWeight: FontWeight.w900,
        letterSpacing: -1.5, color: baseColor,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 36, fontWeight: FontWeight.w800,
        letterSpacing: -1.0, color: baseColor,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 32, fontWeight: FontWeight.w800,
        letterSpacing: -0.5, color: baseColor,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 28, fontWeight: FontWeight.bold,
        letterSpacing: -0.5, color: baseColor,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 24, fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 22, fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleSmall: GoogleFonts.outfit(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      // Body & label styles → Inter (clean, readable)
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, height: 1.6, color: baseColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, height: 1.6, color: baseColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12, height: 1.5, color: subtleColor,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14, fontWeight: FontWeight.w600, color: baseColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w500, color: subtleColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w500, color: subtleColor,
      ),
    );
  }

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme(dark: false);
    return ThemeData(
      useMaterial3: true,
      textTheme: textTheme,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.backgroundLight,
        error: AppColors.premium,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      cardTheme: CardThemeData(
        color: AppColors.surfaceWhite,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWhite,
        hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = _buildTextTheme(dark: true);
    return ThemeData(
      useMaterial3: true,
      textTheme: textTheme,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: const Color(0xFF222222),
        error: AppColors.premium,
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
      ),
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      cardTheme: CardThemeData(
        color: const Color(0xFF333333),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF333333),
        hintStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
