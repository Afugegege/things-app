import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- STATIC COLORS ---
  static const Color pureBlack = Color(0xFF000000);
  static const Color pureWhite = Color(0xFFFFFFFF);
  
  // --- GLASS CONSTANTS ---
  static const double glassOpacity = 0.12; 
  static const double glassBlur = 20.0;
  static const Color glassBorderColor = Colors.white12;

  // --- THEME VARIANTS ---
  static Map<String, Color> themeBackgrounds = {
    'Minimalist Dark': const Color(0xFF000000),
    'Cyberpunk': const Color(0xFF0F0C29), // Deep Indigo
    'OLED Black': const Color(0xFF000000),
    'Paper': const Color(0xFFF5F5DC), // Beige
  };

  static Map<String, Color> themeAccents = {
    'Minimalist Dark': Colors.white,
    'Cyberpunk': Colors.cyanAccent,
    'OLED Black': Colors.white38,
    'Paper': Colors.brown,
  };

  // --- TEXT THEME ---
  static TextTheme _buildTextTheme(Color color) {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 32),
      displayMedium: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 24),
      bodyLarge: TextStyle(color: color, fontSize: 16),
      bodyMedium: TextStyle(color: color.withOpacity(0.7), fontSize: 14),
      labelSmall: TextStyle(color: color.withOpacity(0.5), fontSize: 10, letterSpacing: 1.0),
    );
  }

  // --- THEME DATA GENERATOR ---
  static ThemeData getThemeData(String themeId) {
    // Default to Dark
    Color bg = themeBackgrounds[themeId] ?? pureBlack;
    Color text = (themeId == 'Paper') ? Colors.black87 : pureWhite;
    
    return ThemeData(
      brightness: (themeId == 'Paper') ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: bg,
      primaryColor: text,
      colorScheme: ColorScheme.fromSeed(
        seedColor: themeAccents[themeId] ?? Colors.blue,
        background: bg,
        surface: bg,
        onSurface: text,
        brightness: (themeId == 'Paper') ? Brightness.light : Brightness.dark,
      ),
      textTheme: _buildTextTheme(text),
      useMaterial3: true,
      iconTheme: IconThemeData(color: text, size: 24),
      dividerTheme: const DividerThemeData(color: Colors.white10, thickness: 1),
    );
  }
}