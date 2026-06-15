import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the current [ThemeMode] and persists it to shared_preferences.
/// Default is [ThemeMode.dark].
class ThemeController extends ValueNotifier<ThemeMode> {
  static const String _key = 'theme_mode';

  ThemeController() : super(ThemeMode.dark);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    value = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark,
    };
  }

  bool get isDark => value == ThemeMode.dark;

  Future<void> setDark(bool dark) async {
    value = dark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, dark ? 'dark' : 'light');
  }

  Future<void> toggle() => setDark(!isDark);
}
