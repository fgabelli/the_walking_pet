import 'package:flutter/material.dart';

/// App color palette - DOGZN Brand Kit
class AppColors {
  // Primary Colors - Emerald Green & Coral
  // Primary Colors - DOGZN Brand
  static const primary = Color(0xFF0A2342); // DOGZN Dark Blue
  static const primaryDark = Color(0xFF051121); // Darker shade of Dark Blue
  static const primaryLight = Color(0xFF1E3A5F); // Lighter shade of Dark Blue (derived)
  
  // Accent Colors
  static const accent = Color(0xFFFF6B4A); // Coral Energy
  static const accentLight = Color(0xFFFF8A6F); // Lighter Coral
  static const secondary = accent; // Alias for secondary
  
  // Semantic Colors
  static const success = Color(0xFF2E7D32); // Standard Success Green
  static const warning = Color(0xFFFFA000); // Standard Warning Amber
  static const error = Color(0xFFD32F2F);   // Standard Error Red
  static const info = Color(0xFF0288D1);    // Standard Info Blue
  
  // Neutral Colors - Light Theme
  static const background = Colors.white; // Pure White
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF5F5F5); // UI Gray
  
  // Text Colors - Light Theme
  static const textPrimary = Color(0xFF0A2342); // Dark Blue as Primary Text
  static const textSecondary = Color(0xFF424242); // Dark Grey
  static const textTertiary = Color(0xFF757575); // Medium Grey
  
  // Dark Theme Colors
  static const backgroundDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const surfaceVariantDark = Color(0xFF0A2342); // Dark Blue as variant in Dark Mode? Maybe too blue.
  
  // Text Colors - Dark Theme
  static const textPrimaryDark = Color(0xFFFFFFFF); // White
  static const textSecondaryDark = Color(0xFFB0BEC5); // Light Blue Grey
  static const textTertiaryDark = Color(0xFF78909C);
  
  // Gradient Colors
  static const gradientStart = Color(0xFF0A2342); // Dark Blue
  static const gradientEnd = Color(0xFF1E3A5F); // Lighter Blue
  
  // Map Colors
  static const mapUserMarker = Color(0xFF0A2342);
  static const mapWalkMarker = Color(0xFFFF6B4A);
  static const mapAnnouncementMarker = Color(0xFFFF9800);
  
  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
