import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// UI language choice. [system] follows the device locale.
enum AppLanguage {
  system(null),
  en(Locale('en')),
  ru(Locale('ru')),
  kk(Locale('kk'));

  const AppLanguage(this.locale);

  final Locale? locale;
}

class AppSettings extends Equatable {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.system,
  });

  final ThemeMode themeMode;
  final AppLanguage language;

  AppSettings copyWith({ThemeMode? themeMode, AppLanguage? language}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        language: language ?? this.language,
      );

  @override
  List<Object?> get props => [themeMode, language];
}
