import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeProvider extends ChangeNotifier {
  ThemeModeProvider({Future<SharedPreferences>? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance();

  static const _preferenceKey = 'darkModeEnabled';

  final Future<SharedPreferences> _preferences;
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  Future<void> load() async {
    final preferences = await _preferences;
    final isDarkMode = preferences.getBool(_preferenceKey) ?? false;
    if (_isDarkMode == isDarkMode) return;
    _isDarkMode = isDarkMode;
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    final preferences = await _preferences;
    final saved = await preferences.setBool(_preferenceKey, enabled);
    if (!saved) {
      throw StateError('Could not save the appearance setting.');
    }
    if (_isDarkMode == enabled) return;
    _isDarkMode = enabled;
    notifyListeners();
  }
}
