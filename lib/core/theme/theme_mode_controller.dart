import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  static const String preferenceKey = 'pharmaguide_dark_mode';

  bool _isDark = false;
  bool _changedManually = false;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_changedManually) return;

      final savedValue = preferences.getBool(preferenceKey);
      if (savedValue == null || savedValue == _isDark) return;

      _isDark = savedValue;
      notifyListeners();
    } catch (_) {
      // The app remains usable with the default light theme if storage fails.
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    _changedManually = true;
    if (_isDark != enabled) {
      _isDark = enabled;
      notifyListeners();
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(preferenceKey, enabled);
    } catch (_) {
      // The selected theme still applies for this session if storage fails.
    }
  }
}
