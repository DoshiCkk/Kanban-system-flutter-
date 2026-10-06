import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flowboard/features/settings/domain/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores non-sensitive UI preferences. Tokens go to secure storage instead.
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  static const themeModeKey = 'settings.themeMode';
  static const languageKey = 'settings.language';
  static const Set<String> keys = {themeModeKey, languageKey};

  final SharedPreferencesWithCache _prefs;

  @override
  AppSettings load() => AppSettings(
    themeMode: _byName(
      ThemeMode.values,
      _prefs.getString(themeModeKey),
      ThemeMode.system,
    ),
    language: _byName(
      AppLanguage.values,
      _prefs.getString(languageKey),
      AppLanguage.system,
    ),
  );

  @override
  Future<void> saveThemeMode(ThemeMode mode) =>
      _prefs.setString(themeModeKey, mode.name);

  @override
  Future<void> saveLanguage(AppLanguage language) =>
      _prefs.setString(languageKey, language.name);

  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
