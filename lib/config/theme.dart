import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppTheme {
  // --- CONSTANTS ---
  static const double glassBlur = 20.0;
  
  // Standard iOS Backgrounds
  static const Color _darkBackground = Colors.black;
  static const Color _darkSurface = Color(0xFF1C1C1E);
  static const Color _lightBackground = Color(0xFFF2F2F7);
  static const Color _lightSurface = Colors.white;

  // --- THEME GENERATOR ---
  static ThemeData createTheme({
    required bool isDark,
    required Color accentColor,
  }) {
    final bg = isDark ? _darkBackground : _lightBackground;
    final surface = isDark ? _darkSurface : _lightSurface;
    final text = isDark ? Colors.white : Colors.black;
    final textSec = isDark ? Colors.white70 : Colors.black54;

    // Ensure accent is visible (e.g., don't allow black accent on black bg)
    final safeAccent = _adjustAccent(accentColor, isDark);

    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      primaryColor: safeAccent,
      cardColor: surface,
      canvasColor: surface, // For bottom sheets
      
      // Text Styling
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: textSec),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: text, fontWeight: FontWeight.w600),
      ),

      // Icon Styling
      iconTheme: IconThemeData(color: safeAccent),
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.bold),
      ),

      // Color Scheme (Controls Widgets like Switches, FABs, etc.)
      colorScheme: isDark 
          ? ColorScheme.dark(
              primary: safeAccent,
              secondary: safeAccent,
              surface: surface,
              background: bg,
              onBackground: text,
              onSurface: text,
            )
          : ColorScheme.light(
              primary: safeAccent,
              secondary: safeAccent,
              surface: surface,
              background: bg,
              onBackground: text,
              onSurface: text,
            ),
      
      // Cupertino Overrides (for iOS widgets)
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: safeAccent,
        barBackgroundColor: surface.withOpacity(0.8),
        scaffoldBackgroundColor: bg,
        textTheme: CupertinoTextThemeData(
          primaryColor: safeAccent,
          textStyle: TextStyle(color: text, fontFamily: 'SF Pro Display'),
        ),
      ),
    );
  }

  // Helper: Prevents invisible colors (e.g. white accent on white background)
  static Color _adjustAccent(Color color, bool isDark) {
    if (isDark && color.computeLuminance() < 0.15) return Colors.white; // Too dark for dark mode
    if (!isDark && color.computeLuminance() > 0.85) return Colors.black; // Too bright for light mode
    return color;
  }
}