import 'package:flutter/material.dart';
import 'colors.dart';

final lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.backgroundLight,
  dividerColor: AppColors.neutralLighter,

  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.primaryLight,
    error: AppColors.error,
    surface: AppColors.backgroundLight,
  ),

  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.primaryLightester, // Background for AppBar
    elevation: 5, // Shadow height
    iconTheme: IconThemeData(color: AppColors.textPrimary), // Icon color
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
    shadowColor: AppColors.textSecondary, // Shadow color
  ),

  textTheme: const TextTheme(
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary
    ),
    titleSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary
    ),
    bodyLarge: TextStyle(color: AppColors.textPrimary), // For body text
    bodyMedium: TextStyle(color: AppColors.textSecondary), // For secondary text
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all(AppColors.primaryLightester),
      foregroundColor: WidgetStateProperty.all(AppColors.primary),
      padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) return AppColors.primaryLightest;
        if (states.contains(WidgetState.pressed)) return AppColors.primaryDark;
        return null;
      }),
    ),
  ),

  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppColors.primaryLightester, // Background color
    foregroundColor: AppColors.primary, // Icon color
    hoverColor: AppColors.primaryLightest, // Hover color
    focusColor: AppColors.primaryDark, // Focus color
    elevation: 5, // Shadow elevation
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16), // Custom rounded shape
    ),
  ),

  cardTheme: CardTheme(
    color: AppColors.neutralLightest,
    elevation: 3,
    shadowColor: AppColors.primaryLightest,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.symmetric(vertical: 4.0),
  ),

  iconTheme: IconThemeData(
    color: AppColors.textSecondary,
  ),

  inputDecorationTheme: InputDecorationTheme(
    contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: AppColors.neutralLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: AppColors.neutralLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: Colors.deepPurple),
    ),
  ),
  extensions: [
    FloatingMusicPlayerTheme(
      background: AppColors.neutralLightest, // Light grey background
      border: AppColors.neutralLighter, // Subtle border color
      icon: AppColors.primary, // Deep purple for icons
      text: AppColors.textPrimary, // Primary text color
      playPauseButtonBackground: AppColors.primaryLighter, // Slightly lighter purple
      playPauseButtonIcon: AppColors.textOnPrimary, // White for contrast
      tapButtonBackground: AppColors.primaryLightest, // Light purple for the tap button
      tapButtonBorder: AppColors.primary, // Deep purple for button border
      tapButtonText: AppColors.textPrimary, // White text on tap button
      resetButtonBackground: AppColors.errorLight, // Light red for reset
      resetButtonBorder: AppColors.error, // Standard red for border
      resetButtonText: AppColors.textPrimary, // Primary text color
      sliderActiveTrack: AppColors.primary, // Active track uses deep purple
      sliderInactiveTrack: AppColors.neutralLighter, // Subtle inactive track
      sliderThumb: AppColors.primary, // Purple thumb
    ),
  ],
);