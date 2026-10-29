import 'package:flutter/material.dart';

const Color primaryGreen = Color(0xFF247447);
const Color lightGreen = Color(0xFFEAF5ED);

const Color statusGood = Color(0xFF2E7D32);
const Color statusWarn = Color(0xFFEF8F00);
const Color statusBad = Color(0xFFC62828);

/// Color for any status string the API returns.
Color statusColor(String? status) {
  switch ((status ?? '').toUpperCase()) {
    case 'SUITABLE':
    case 'GOOD':
      return statusGood;
    case 'CAUTION':
    case 'BREAK EVEN':
      return statusWarn;
    case 'NOT SUITABLE':
    case 'NOT GOOD':
      return statusBad;
    default:
      return Colors.grey;
  }
}

ThemeData buildTheme() {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
    scaffoldBackgroundColor: const Color(0xFFF7FAF7),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border(const Color(0xFFDCE5DE)),
      enabledBorder: border(const Color(0xFFDCE5DE)),
      focusedBorder: border(primaryGreen, 1.5),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
