import 'package:flutter/material.dart';

class AppTheme {
  // --- CONSTANTS ---
  static const Color pureWhite = Colors.white;
  static const Color pureBlack = Colors.black;
  static const double glassBlur = 20.0;

  // --- LIGHT THEME ---
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
    primaryColor: Colors.blueAccent,
    cardColor: Colors.white,
    canvasColor: Colors.white,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black87),
      titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),
    iconTheme: const IconThemeData(color: Colors.black),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    colorScheme: const ColorScheme.light(
      primary: Colors.blueAccent,
      secondary: Colors.blue,
      surface: Colors.white,
      background: Color(0xFFF2F2F7),
      onBackground: Colors.black,
      onSurface: Colors.black,
    ),
  );

  // --- DARK THEME ---
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    primaryColor: Colors.blueAccent,
    cardColor: const Color(0xFF1C1C1E),
    canvasColor: const Color(0xFF1C1C1E),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Colors.blueAccent,
      secondary: Colors.blue,
      surface: Color(0xFF1C1C1E),
      background: Colors.black,
      onBackground: Colors.white,
      onSurface: Colors.white,
    ),
  );

  // [FIX] Helper method to support legacy code calling getThemeData
  static ThemeData getThemeData(dynamic themeId) {
    // If themeId is a bool (isDark), use that. If string, check value.
    if (themeId is bool) {
      return themeId ? darkTheme : lightTheme;
    }
    if (themeId.toString() == 'Light') return lightTheme;
    return darkTheme; // Default to dark
  }
}