import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class SettingsState {
  final String translation;
  final String language;
  final double fontSize;
  final bool onboardingDone;

  const SettingsState({
    this.translation = AppConstants.translationARC,
    this.language = 'pt',
    this.fontSize = 17.0,
    this.onboardingDone = false,
  });

  SettingsState copyWith({
    String? translation,
    String? language,
    double? fontSize,
    bool? onboardingDone,
  }) {
    return SettingsState(
      translation: translation ?? this.translation,
      language: language ?? this.language,
      fontSize: fontSize ?? this.fontSize,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      translation: prefs.getString(AppConstants.selectedTranslationKey) ??
          AppConstants.translationARC,
      language: prefs.getString(AppConstants.selectedLanguageKey) ?? 'pt',
      fontSize: prefs.getDouble(AppConstants.fontSizeKey) ?? 17.0,
      onboardingDone: prefs.getBool(AppConstants.onboardingDoneKey) ?? false,
    );
  }

  Future<void> setTranslation(String translation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.selectedTranslationKey, translation);
    state = state.copyWith(translation: translation);
  }

  Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.selectedLanguageKey, language);
    state = state.copyWith(language: language);
  }

  Future<void> setFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.fontSizeKey, size);
    state = state.copyWith(fontSize: size);
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
