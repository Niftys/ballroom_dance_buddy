import 'package:flutter/material.dart';
import 'colors.dart';

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: DarkAppColors.primary,
  scaffoldBackgroundColor: DarkAppColors.background,
  dividerColor: DarkAppColors.surface,

  colorScheme: ColorScheme.dark(
    primary: DarkAppColors.primary,
    secondary: DarkAppColors.highlight,
    error: DarkAppColors.error,
    surface: DarkAppColors.surface,
  ),

  appBarTheme: AppBarTheme(
    backgroundColor: DarkAppColors.primary,
    elevation: 5,
    iconTheme: IconThemeData(color: DarkAppColors.textPrimary),
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: DarkAppColors.textPrimary,
    ),
  ),

  textTheme: const TextTheme(
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: DarkAppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: DarkAppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: DarkAppColors.textSecondary,
    ),
    bodyLarge: TextStyle(color: DarkAppColors.textPrimary),
    bodyMedium: TextStyle(color: DarkAppColors.textSecondary),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: DarkAppColors.surfaceLight,
      foregroundColor: DarkAppColors.textPrimary,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),

  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: DarkAppColors.primaryLight,
    foregroundColor: DarkAppColors.textPrimary,
  ),

  cardTheme: CardTheme(
    color: DarkAppColors.surface,
    elevation: 3,
    shadowColor: DarkAppColors.surfaceLight,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),

  iconTheme: IconThemeData(
    color: DarkAppColors.textSecondary,
  ),

  inputDecorationTheme: InputDecorationTheme(
    contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
    filled: true,
    fillColor: DarkAppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: DarkAppColors.primary),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: DarkAppColors.primary),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: DarkAppColors.highlight),
    ),
  ),
  extensions: [
    FloatingMusicPlayerTheme(
      background: DarkAppColors.surface,
      border: DarkAppColors.surfaceLight,
      icon: DarkAppColors.textPrimary,
      text: DarkAppColors.textPrimary,
      playPauseButtonBackground: DarkAppColors.primary,
      playPauseButtonIcon: DarkAppColors.textPrimary,
      tapButtonBackground: DarkAppColors.primaryLight,
      tapButtonBorder: DarkAppColors.highlight,
      tapButtonText: DarkAppColors.textPrimary,
      resetButtonBackground: DarkAppColors.primaryLight,
      resetButtonBorder: DarkAppColors.error,
      resetButtonText: DarkAppColors.textPrimary,
      sliderActiveTrack: DarkAppColors.highlight,
      sliderInactiveTrack: DarkAppColors.surfaceLight,
      sliderThumb: DarkAppColors.highlight,
    ),
  ],
);

