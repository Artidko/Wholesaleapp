import 'package:flutter/material.dart';

/// โทน horse green & white
const _horseGreen = Color(0xFF2F8F2F);

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _horseGreen,
    primary: _horseGreen,
    onPrimary: Colors.white,
    secondary: const Color(0xFF0E7C86),
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: _horseGreen,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _horseGreen,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      minimumSize: const Size.fromHeight(48),
    ),
  ),
  chipTheme: const ChipThemeData(
    selectedColor: _horseGreen,
    labelStyle: TextStyle(color: Colors.white),
  ),
);
