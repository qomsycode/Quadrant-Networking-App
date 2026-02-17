import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- MASTER COLORS ---
  static const Color primaryBlue = Color(0xFF2575FC);
  static const Color deepNavy = Color(0xFF1B1F23);
  static const Color accentPurple = Color(0xFF6A11CB);
  static const Color lightGray = Color(0xFFF5F5F5);

  // FIX: Re-added glassWhite to resolve 'undefined getter' errors in SplashScreen
  static const Color glassWhite = Colors.white;

  // --- LIGHT THEME ---
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: Colors.white,
    // Ensures headers remain clean white in light mode
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: deepNavy,
      elevation: 0,
    ),
    // Standardizes icon colors for light backgrounds
    iconTheme: const IconThemeData(color: deepNavy),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: deepNavy,
      ),
      bodyMedium: GoogleFonts.inter(fontSize: 16, color: deepNavy),
    ),
  );

  // --- DARK THEME ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryBlue,
    // Setting background to your specific Deep Navy
    scaffoldBackgroundColor: deepNavy,
    // FIX: Tells AppBars to blend into the Deep Navy background
    appBarTheme: const AppBarTheme(
      backgroundColor: deepNavy,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    // Standardizes icon colors to white for dark backgrounds
    iconTheme: const IconThemeData(color: Colors.white),
    // Standardizes the color scheme so buttons and inputs react to dark mode
    colorScheme: const ColorScheme.dark(
      primary: primaryBlue,
      surface: deepNavy,
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      bodyMedium: GoogleFonts.inter(fontSize: 16, color: Colors.white70),
    ),
  );
}
