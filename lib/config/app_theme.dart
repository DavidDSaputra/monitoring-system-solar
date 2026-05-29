import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Colors (JARWINN Orange)
  static const Color primary = Color(0xFFF97316); // Vibrant orange
  static const Color primaryLight = Color(0xFFFBBF24); // Solar gold
  static const Color primaryDark = Color(0xFFEA580C); // Deep orange

  // Background Colors (Clean Light Theme)
  static const Color background = Color(0xFFF8FAFC); // Off-white
  static const Color surface = Colors.white; // Card surface
  static const Color surfaceLight = Color(0xFFF1F5F9); // Elevated surface
  static const Color surfaceBorder = Color(0xFFE2E8F0); // Light borders

  // Status Colors
  static const Color online = Color(0xFF10B981); // Green - active
  static const Color offline = Color(0xFF9CA3AF); // Gray - inactive
  static const Color alarm = Color(0xFFEF4444); // Red - alarm
  static const Color warning = Color(0xFFF59E0B); // Amber - warning

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Dark navy
  static const Color textSecondary = Color(0xFF64748B); // Slate
  static const Color textTertiary = Color(0xFF94A3B8); // Light slate

  // Chart Colors
  static const Color chartLine = Color(0xFFF97316);
  static const Color chartFill = Color(0x33F97316);
  static const Color chartGrid = Color(0xFFE2E8F0);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryLight, primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFFFFBF5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.surface,
        error: AppColors.alarm,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textTertiary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 24),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceBorder,
        thickness: 1,
      ),
    );
  }
}
