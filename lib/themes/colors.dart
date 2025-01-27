import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryDark = Color(0xFF351175); // Deep Purple
  static const Color primaryLightester = Color(0xFFF2EDFB);
  static const Color primaryLightest = Color(0xFFDED0F6); // Purple Shade 50
  static const Color primaryLighter = Color(0xFFD2BAFA); // Purple Shade 100
  static const Color primaryLight = Color(0xFF9877C3); // Purple Shade 200
  static const Color primary = Color(0xFF673AB7); // Purple Shade 300

  // Error and Warning Colors
  static const Color errorDark = Color(0xFFFF5252); // Red Accent
  static const Color errorLight = Color(0xFFFFEBEE); // Red Shade 50
  static const Color error = Color(0xFFE57373); // Red Shade 300

  // Neutral Colors
  static const Color neutralLightest = Color(0xFFF5F5F5); // Grey Shade 100
  static const Color neutralLighter = Color(0xFFE6E6E6); // Grey Shade 300
  static const Color neutralLight = Color(0xFFAAAAAA);
  static const Color neutralDark = Color(0xFF757575); // Grey Shade 600

  // Text Colors
  static const Color textPrimary = Color(0xFF212121); // Black 87
  static const Color textSecondary = Color(0xFF757575); // Black 54
  static const Color textOnPrimary = Color(0xFFFFFFFF); // White

  // Background Colors
  static const Color backgroundLight = Color(0xFFF5F5F5); // Grey Shade 100

  // Highlight Colors
  static const Color highlight = Color(0xFF673AB7); // Deep Purple
  static const Color gold = Color(0xFFFFC107); // Gold
  static const Color bronze = Color(0xFF795548); // Brown
  static const Color silver = Color(0xFF9E9E9E); // Silver
  static const Color blueAccent = Color(0xFF448AFF); // Blue Accent
}

class DarkAppColors {
  // Primary Colors
  static const Color primary = Color(0xFF1C1C1E); // Dark gray (AppBar/Primary elements)
  static const Color primaryLight = Color(0xFF2C2C2E); // Slightly lighter gray
  static const Color primaryDark = Color(0xFF121212); // Very dark gray for backgrounds

  // Background Colors
  static const Color background = Color(0xFF1C1C1E); // Primary background
  static const Color surface = Color(0xFF2C2C2E); // Slightly elevated surface
  static const Color surfaceLight = Color(0xFF3A3A3C); // Elevated surface for cards and modals

  // Text Colors
  static const Color textPrimary = Color(0xFFE5E5E7); // High contrast light text
  static const Color textSecondary = Color(0xFF8E8E93); // Muted gray for secondary text

  // Error Colors
  static const Color error = Color(0xFFFF453A); // Vibrant red for errors

  // Highlights
  static const Color highlight = Color(0xFF956DDF); // Deep Purple
  static const Color gold = Color(0xFFFFC107); // Gold
  static const Color bronze = Color(0xFF956F66); // Brown
  static const Color silver = Color(0xFF9E9E9E); // Silver
  static const Color blueAccent = Color(0xFF0A84FF); // Bright blue for accents
}


class FloatingMusicPlayerTheme extends ThemeExtension<FloatingMusicPlayerTheme> {
  final Color background;
  final Color border;
  final Color icon;
  final Color text;

  // Button Colors
  final Color playPauseButtonBackground;
  final Color playPauseButtonIcon;
  final Color tapButtonBackground;
  final Color tapButtonBorder;
  final Color tapButtonText;
  final Color resetButtonBackground;
  final Color resetButtonBorder;
  final Color resetButtonText;

  // Slider Colors
  final Color sliderActiveTrack;
  final Color sliderInactiveTrack;
  final Color sliderThumb;

  const FloatingMusicPlayerTheme({
    required this.background,
    required this.border,
    required this.icon,
    required this.text,
    required this.playPauseButtonBackground,
    required this.playPauseButtonIcon,
    required this.tapButtonBackground,
    required this.tapButtonBorder,
    required this.tapButtonText,
    required this.resetButtonBackground,
    required this.resetButtonBorder,
    required this.resetButtonText,
    required this.sliderActiveTrack,
    required this.sliderInactiveTrack,
    required this.sliderThumb,
  });

  @override
  FloatingMusicPlayerTheme copyWith({
    Color? background,
    Color? border,
    Color? icon,
    Color? text,
    Color? playPauseButtonBackground,
    Color? playPauseButtonIcon,
    Color? tapButtonBackground,
    Color? tapButtonBorder,
    Color? tapButtonText,
    Color? resetButtonBackground,
    Color? resetButtonBorder,
    Color? resetButtonText,
    Color? sliderActiveTrack,
    Color? sliderInactiveTrack,
    Color? sliderThumb,
  }) {
    return FloatingMusicPlayerTheme(
      background: background ?? this.background,
      border: border ?? this.border,
      icon: icon ?? this.icon,
      text: text ?? this.text,
      playPauseButtonBackground: playPauseButtonBackground ?? this.playPauseButtonBackground,
      playPauseButtonIcon: playPauseButtonIcon ?? this.playPauseButtonIcon,
      tapButtonBackground: tapButtonBackground ?? this.tapButtonBackground,
      tapButtonBorder: tapButtonBorder ?? this.tapButtonBorder,
      tapButtonText: tapButtonText ?? this.tapButtonText,
      resetButtonBackground: resetButtonBackground ?? this.resetButtonBackground,
      resetButtonBorder: resetButtonBorder ?? this.resetButtonBorder,
      resetButtonText: resetButtonText ?? this.resetButtonText,
      sliderActiveTrack: sliderActiveTrack ?? this.sliderActiveTrack,
      sliderInactiveTrack: sliderInactiveTrack ?? this.sliderInactiveTrack,
      sliderThumb: sliderThumb ?? this.sliderThumb,
    );
  }

  @override
  FloatingMusicPlayerTheme lerp(ThemeExtension<FloatingMusicPlayerTheme>? other, double t) {
    if (other is! FloatingMusicPlayerTheme) return this;
    return FloatingMusicPlayerTheme(
      background: Color.lerp(background, other.background, t)!,
      border: Color.lerp(border, other.border, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
      text: Color.lerp(text, other.text, t)!,
      playPauseButtonBackground: Color.lerp(playPauseButtonBackground, other.playPauseButtonBackground, t)!,
      playPauseButtonIcon: Color.lerp(playPauseButtonIcon, other.playPauseButtonIcon, t)!,
      tapButtonBackground: Color.lerp(tapButtonBackground, other.tapButtonBackground, t)!,
      tapButtonBorder: Color.lerp(tapButtonBorder, other.tapButtonBorder, t)!,
      tapButtonText: Color.lerp(tapButtonText, other.tapButtonText, t)!,
      resetButtonBackground: Color.lerp(resetButtonBackground, other.resetButtonBackground, t)!,
      resetButtonBorder: Color.lerp(resetButtonBorder, other.resetButtonBorder, t)!,
      resetButtonText: Color.lerp(resetButtonText, other.resetButtonText, t)!,
      sliderActiveTrack: Color.lerp(sliderActiveTrack, other.sliderActiveTrack, t)!,
      sliderInactiveTrack: Color.lerp(sliderInactiveTrack, other.sliderInactiveTrack, t)!,
      sliderThumb: Color.lerp(sliderThumb, other.sliderThumb, t)!,
    );
  }
}
