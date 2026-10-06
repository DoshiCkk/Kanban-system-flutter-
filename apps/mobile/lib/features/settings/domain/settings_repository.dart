import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';

abstract interface class SettingsRepository {
  AppSettings load();

  Future<void> saveThemeMode(ThemeMode mode);

  Future<void> saveLanguage(AppLanguage language);
}
