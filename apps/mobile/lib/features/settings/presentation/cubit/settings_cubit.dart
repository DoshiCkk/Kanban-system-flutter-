import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flowboard/features/settings/domain/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._repository) : super(_repository.load());

  final SettingsRepository _repository;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state.themeMode) return;
    emit(state.copyWith(themeMode: mode));
    await _repository.saveThemeMode(mode);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (language == state.language) return;
    emit(state.copyWith(language: language));
    await _repository.saveLanguage(language);
  }
}
