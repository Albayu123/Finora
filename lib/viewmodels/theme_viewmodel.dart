import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mengelola pilihan tema terang/gelap pengguna.
class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel({this._preferences});

  static const String _themePrefKey = 'finora_theme_mode';

  final SharedPreferences? _preferences;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<void> loadTheme() async {
    final prefs = await _prefs;
    final saved = prefs.getString(_themePrefKey);
    if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (saved == 'light') {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();

    final prefs = await _prefs;
    await prefs.setString(
      _themePrefKey,
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}
