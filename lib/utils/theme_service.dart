import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global theme state — listened to by MaterialApp in main.dart.
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

Future<void> initTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final saved  = prefs.getString('app_theme') ?? 'light';
  themeNotifier.value = switch (saved) {
    'dark'   => ThemeMode.dark,
    'system' => ThemeMode.system,
    _        => ThemeMode.light,
  };
}

Future<void> setTheme(ThemeMode mode) async {
  themeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  final key = switch (mode) {
    ThemeMode.dark   => 'dark',
    ThemeMode.system => 'system',
    _                => 'light',
  };
  await prefs.setString('app_theme', key);
}

String themeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.dark   => 'Dark',
  ThemeMode.system => 'System',
  _                => 'Light',
};
