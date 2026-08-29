import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App typography using Google Fonts (Montserrat)
class AppTypography {
  // Font Family
  // static const String fontFamily = 'Montserrat'; // No longer used string directly
  static const String displayFontFamily = 'Montserrat';
  
  // Display Styles
  static TextStyle displayLarge = GoogleFonts.montserrat(
    fontSize: 57,
    fontWeight: FontWeight.w700,
    height: 1.12,
    letterSpacing: -0.25,
  );
  
  static TextStyle displayMedium = GoogleFonts.montserrat(
    fontSize: 45,
    fontWeight: FontWeight.w700,
    height: 1.16,
  );
  
  static TextStyle displaySmall = GoogleFonts.montserrat(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    height: 1.22,
  );
  
  // Headline Styles
  static TextStyle headlineLarge = GoogleFonts.montserrat(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
  
  static TextStyle headlineMedium = GoogleFonts.montserrat(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.29,
  );
  
  static TextStyle headlineSmall = GoogleFonts.montserrat(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.33,
  );
  
  // Title Styles
  static TextStyle titleLarge = GoogleFonts.montserrat(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.27,
  );
  
  static TextStyle titleMedium = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.15,
  );
  
  static TextStyle titleSmall = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.43,
    letterSpacing: 0.1,
  );
  
  // Body Styles
  static TextStyle bodyLarge = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.5,
  );
  
  static TextStyle bodyMedium = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
    letterSpacing: 0.25,
  );
  
  static TextStyle bodySmall = GoogleFonts.montserrat(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.33,
    letterSpacing: 0.4,
  );
  
  // Label Styles
  static TextStyle labelLarge = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.43,
    letterSpacing: 0.1,
  );
  
  static TextStyle labelMedium = GoogleFonts.montserrat(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.33,
    letterSpacing: 0.5,
  );
  
  static TextStyle labelSmall = GoogleFonts.montserrat(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: 0.5,
  );
}
