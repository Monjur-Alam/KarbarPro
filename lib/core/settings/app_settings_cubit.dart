import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyLocale = 'app_locale';
const String _keyThemeMode = 'app_theme_mode';

enum AppThemeMode { light, dark, system }

class AppSettingsState {
  final Locale locale;
  final AppThemeMode themeMode;

  const AppSettingsState({
    this.locale = const Locale('bn', 'BD'),
    this.themeMode = AppThemeMode.system,
  });

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  AppSettingsState copyWith({Locale? locale, AppThemeMode? themeMode}) {
    return AppSettingsState(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit() : super(const AppSettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_keyLocale);
    final themeIndex = prefs.getInt(_keyThemeMode);

    Locale locale = const Locale('bn', 'BD');
    if (localeCode == 'en') {
      locale = const Locale('en', 'US');
    } else if (localeCode == 'bn') {
      locale = const Locale('bn', 'BD');
    }

    AppThemeMode mode = AppThemeMode.system;
    if (themeIndex != null && themeIndex >= 0 && themeIndex <= 2) {
      mode = AppThemeMode.values[themeIndex];
    }

    emit(state.copyWith(locale: locale, themeMode: mode));
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale.languageCode);
    emit(state.copyWith(locale: locale));
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
    emit(state.copyWith(themeMode: mode));
  }
}
