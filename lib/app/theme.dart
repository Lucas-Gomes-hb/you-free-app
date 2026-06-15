import 'package:flutter/material.dart';

/// Shared color tokens for the app. Two instances are provided:
/// [AppPalette.dark] (default) and [AppPalette.light].
class AppPalette {
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color text;
  final Color textMuted;

  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.text,
    required this.textMuted,
  });

  static const AppPalette dark = AppPalette(
    primary: Color(0xFFFF6A56),
    onPrimary: Color(0xFF1E1E1E),
    secondary: Color(0xFFFFC857),
    onSecondary: Color(0xFF1E1E1E),
    background: Color(0xFF1E1E1E),
    surface: Color(0xFF2A2A2A),
    surfaceHigh: Color(0xFF333333),
    border: Color(0xFF3A3A3A),
    text: Color(0xFFF2ECE2),
    textMuted: Color(0xFFA89E92),
  );

  static const AppPalette light = AppPalette(
    primary: Color(0xFFFF4B3E),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFFFD35C),
    onSecondary: Color(0xFF2B2B2B),
    background: Color(0xFFFFF2D8),
    surface: Color(0xFFFFE8BD),
    surfaceHigh: Color(0xFFFFEFCC),
    border: Color(0xFFE9D4A8),
    text: Color(0xFF2B2B2B),
    textMuted: Color(0xFF6D645A),
  );
}

/// Convenience accessor: `context.c.primary`, etc.
extension AppPaletteX on BuildContext {
  AppPalette get c =>
      Theme.of(this).brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
}

/// Builds the [ThemeData] for a given palette + brightness, reproducing the
/// app's original visual style from shared tokens.
class AppTheme {
  static ThemeData _build(AppPalette p, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.secondary,
      onSecondary: p.onSecondary,
      surface: p.surface,
      onSurface: p.text,
      error: const Color(0xFFE53935),
      onError: Colors.white,
    );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: p.background,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: p.text),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: TextStyle(color: p.textMuted, fontSize: 15),
        prefixIconColor: p.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.surfaceHigh,
        thumbColor: p.primary,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      iconTheme: IconThemeData(color: p.text),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: p.text),
        bodySmall: TextStyle(color: p.textMuted),
      ),
      useMaterial3: false,
    );
  }

  static final ThemeData dark = _build(AppPalette.dark, Brightness.dark);
  static final ThemeData light = _build(AppPalette.light, Brightness.light);
}
