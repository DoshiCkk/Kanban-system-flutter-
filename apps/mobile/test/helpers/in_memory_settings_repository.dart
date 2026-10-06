import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flowboard/features/settings/domain/settings_repository.dart';
import 'package:flutter/material.dart';

class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([this.settings = const AppSettings()]);

  AppSettings settings;

  @override
  AppSettings load() => settings;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    settings = settings.copyWith(themeMode: mode);
  }

  @override
  Future<void> saveLanguage(AppLanguage language) async {
    settings = settings.copyWith(language: language);
  }
}
