import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the user's appearance choices -- the theme mode and the text scale --
/// and persists them so they survive a restart.
///
/// Defaults are deliberately the app's original look: light mode and 1.0 text
/// scale. Nothing changes for a user who never opens the Appearance screen.
class AppThemeController extends ChangeNotifier {
  /// Persisted as a string (one of `system`, `light`, `dark`).
  static const String preferenceKey = 'pharmaguide_theme_mode';

  /// The original key, a bool. Read once on [load] to migrate preferences
  /// written before the theme gained a System option.
  static const String legacyDarkKey = 'pharmaguide_dark_mode';

  /// Persisted as a double, the multiplier applied to the platform text scale.
  static const String textScaleKey = 'pharmaguide_text_scale';

  static const ThemeMode defaultMode = ThemeMode.light;
  static const double defaultTextScale = 1.0;

  ThemeMode _mode = defaultMode;
  double _textScale = defaultTextScale;
  bool _changedManually = false;

  ThemeMode get themeMode => _mode;

  /// Kept for callers that only care whether a dark palette is in effect.
  /// [ThemeMode.system] resolves against the platform brightness at paint time,
  /// so it reports the last explicitly chosen value.
  bool get isDark => _mode == ThemeMode.dark;

  double get textScale => _textScale;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_changedManually) return;

      final stored = preferences.getString(preferenceKey);
      final mode = stored != null
          ? _modeFromStorage(stored) ?? _migrateLegacy(preferences)
          : _migrateLegacy(preferences);

      final scale = preferences.getDouble(textScaleKey);

      var changed = false;
      if (mode != _mode) {
        _mode = mode;
        changed = true;
      }
      if (scale != null && scale != _textScale) {
        _textScale = scale;
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (_) {
      // The app remains usable with the defaults if storage fails.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _changedManually = true;
    if (_mode != mode) {
      _mode = mode;
      notifyListeners();
    }
    await _write((prefs) => prefs.setString(preferenceKey, mode.name));
  }

  Future<void> setTextScale(double scale) async {
    _changedManually = true;
    if (_textScale != scale) {
      _textScale = scale;
      notifyListeners();
    }
    await _write((prefs) => prefs.setDouble(textScaleKey, scale));
  }

  Future<void> resetToDefaults() async {
    _changedManually = true;
    final changed =
        _mode != defaultMode || _textScale != defaultTextScale;
    _mode = defaultMode;
    _textScale = defaultTextScale;
    if (changed) notifyListeners();
    await _write((prefs) async {
      await prefs.setString(preferenceKey, defaultMode.name);
      await prefs.setDouble(textScaleKey, defaultTextScale);
    });
  }

  ThemeMode _migrateLegacy(SharedPreferences preferences) {
    final legacy = preferences.getBool(legacyDarkKey);
    if (legacy == null) return defaultMode;
    return legacy ? ThemeMode.dark : ThemeMode.light;
  }

  static ThemeMode? _modeFromStorage(String value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }

  Future<void> _write(Future<void> Function(SharedPreferences) action) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await action(preferences);
    } catch (_) {
      // The choice still applies for this session if storage fails.
    }
  }
}
