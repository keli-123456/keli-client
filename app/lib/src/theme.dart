import 'package:flutter/material.dart';

const keliBlue = Color(0xFF2563EB);
const keliBlueStrong = Color(0xFF1677FF);
const keliBlueSoft = Color(0xFFEAF3FF);
const keliTeal = Color(0xFF0F9F9A);
const keliCyan = Color(0xFF12B6CB);
const keliGreen = Color(0xFF16A34A);
const keliOrange = Color(0xFFF59E0B);
const keliRed = Color(0xFFDC2626);
const keliInk = Color(0xFF111827);
const keliMuted = Color(0xFF6B7280);
const keliLine = Color(0xFFE5E7EB);
const keliLineSoft = Color(0xFFF0F3F8);
const keliSurface = Color(0xFFF6F8FB);
const keliPanel = Color(0xFFFFFFFF);

ThemeData buildKeliTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: keliBlue,
    brightness: Brightness.light,
    primary: keliBlue,
    secondary: keliTeal,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: keliSurface,
    fontFamily: 'Segoe UI',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1.12),
      headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1.18),
      titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1.22),
      titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1.25),
      bodyLarge: TextStyle(fontSize: 14, letterSpacing: 0, height: 1.35),
      bodyMedium: TextStyle(fontSize: 13, letterSpacing: 0, height: 1.35),
      labelLarge: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: keliLine),
      ),
    ),
    dividerTheme: const DividerThemeData(color: keliLine, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: keliLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: keliLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: keliBlueStrong, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: keliBlueStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(44, 40),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: keliInk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: keliLine),
        minimumSize: const Size(44, 40),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        side: const WidgetStatePropertyAll(BorderSide(color: keliLine)),
      ),
    ),
  );
}
