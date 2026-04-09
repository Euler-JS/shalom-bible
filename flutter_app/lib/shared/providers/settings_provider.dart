import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class SettingsState {
  final String translation;
  final String language;
  final double fontSize;
  final bool onboardingDone;
  final ThemeMode themeMode;

  const SettingsState({
    this.translation = AppConstants.defaultPortugueseTranslation,
    this.language = 'pt',
    this.fontSize = 17.0,
    this.onboardingDone = false,
    this.themeMode = ThemeMode.system,
  });

  SettingsState copyWith({
    String? translation,
    String? language,
    double? fontSize,
    bool? onboardingDone,
    ThemeMode? themeMode,
  }) {
    return SettingsState(
      translation: translation ?? this.translation,
      language: language ?? this.language,
      fontSize: fontSize ?? this.fontSize,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  String _normalizeTranslation(String? translation, String language) {
    if (translation == null || translation.isEmpty) {
      return AppConstants.defaultTranslationForLanguage(language);
    }

    if (translation == 'ARC' || translation == 'ARA') {
      return AppConstants.defaultPortugueseTranslation;
    }

    if (translation == 'KJV') {
      return AppConstants.defaultEnglishTranslation;
    }

    final normalized = translation.toLowerCase();
    return AppConstants.languageForTranslation(normalized) == language
        ? normalized
        : AppConstants.defaultTranslationForLanguage(language);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
    final language = prefs.getString(AppConstants.selectedLanguageKey) ?? 'pt';
    state = state.copyWith(
      translation: _normalizeTranslation(
        prefs.getString(AppConstants.selectedTranslationKey),
        language,
      ),
      language: language,
      fontSize: prefs.getDouble(AppConstants.fontSizeKey) ?? 17.0,
      onboardingDone: prefs.getBool(AppConstants.onboardingDoneKey) ?? false,
      themeMode: ThemeMode.values[themeModeIndex.clamp(0, 2)],
    );
  }

  Future<void> setTranslation(String translation) async {
    final normalizedTranslation = _normalizeTranslation(
      translation,
      state.language,
    );
    state = state.copyWith(translation: normalizedTranslation);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.selectedTranslationKey,
      normalizedTranslation,
    );
  }

  Future<void> setLanguage(String language) async {
    final translation = AppConstants.defaultTranslationForLanguage(language);
    state = state.copyWith(language: language, translation: translation);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.selectedLanguageKey, language);
    await prefs.setString(AppConstants.selectedTranslationKey, translation);
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.fontSizeKey, size);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingDoneKey, true);
    state = state.copyWith(onboardingDone: true);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
