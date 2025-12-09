import 'package:flutter/material.dart';

/// App color palette - vibrant and modern
class AppColors {
  // Primary Colors - Vibrant Purple/Blue gradient theme
  static const primary = Color(0xFF6B4CE6);
  static const primaryDark = Color(0xFF5538D6);
  static const primaryLight = Color(0xFF8B6EF7);
  
  // Accent Colors
  static const accent = Color(0xFFFF6B9D);
  static const accentLight = Color(0xFFFF8FB5);
  static const secondary = accent; // Alias for secondary
  
  // Semantic Colors
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const error = Color(0xFFE53935);
  static const info = Color(0xFF2196F3);
  
  // Neutral Colors - Light Theme
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF3F4F6);
  
  // Text Colors - Light Theme
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  
  // Dark Theme Colors
  static const backgroundDark = Color(0xFF0F0F0F);
  static const surfaceDark = Color(0xFF1A1A1A);
  static const surfaceVariantDark = Color(0xFF2A2A2A);
  
  // Text Colors - Dark Theme
  static const textPrimaryDark = Color(0xFFF9FAFB);
  static const textSecondaryDark = Color(0xFFD1D5DB);
  static const textTertiaryDark = Color(0xFF9CA3AF);
  
  // Gradient Colors
  static const gradientStart = Color(0xFF6B4CE6);
  static const gradientEnd = Color(0xFF8B6EF7);
  
  // Map Colors
  static const mapUserMarker = Color(0xFF6B4CE6);
  static const mapWalkMarker = Color(0xFFFF6B9D);
  static const mapAnnouncementMarker = Color(0xFF4CAF50);
  
  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
