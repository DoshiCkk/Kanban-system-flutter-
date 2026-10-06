import 'package:bloc_test/bloc_test.dart';
import 'package:flowboard/features/settings/domain/app_settings.dart';
import 'package:flowboard/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_settings_repository.dart';

void main() {
  group(SettingsCubit, () {
    late InMemorySettingsRepository repository;

    setUp(() => repository = InMemorySettingsRepository());

    test('initial state is loaded from repository', () {
      repository.settings = const AppSettings(
        themeMode: ThemeMode.dark,
        language: AppLanguage.kk,
      );
      expect(
        SettingsCubit(repository).state,
        const AppSettings(themeMode: ThemeMode.dark, language: AppLanguage.kk),
      );
    });

    blocTest<SettingsCubit, AppSettings>(
      'setThemeMode emits and persists',
      build: () => SettingsCubit(repository),
      act: (cubit) => cubit.setThemeMode(ThemeMode.light),
      expect: () => [const AppSettings(themeMode: ThemeMode.light)],
      verify: (_) => expect(repository.settings.themeMode, ThemeMode.light),
    );

    blocTest<SettingsCubit, AppSettings>(
      'setLanguage emits and persists',
      build: () => SettingsCubit(repository),
      act: (cubit) => cubit.setLanguage(AppLanguage.ru),
      expect: () => [const AppSettings(language: AppLanguage.ru)],
      verify: (_) => expect(repository.settings.language, AppLanguage.ru),
    );

    blocTest<SettingsCubit, AppSettings>(
      'does not emit when value is unchanged',
      build: () => SettingsCubit(repository),
      act: (cubit) => cubit.setThemeMode(ThemeMode.system),
      expect: () => <AppSettings>[],
    );
  });
}
