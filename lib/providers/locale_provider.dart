import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

/// Provides the SharedPreferences instance. Must be overridden at app startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

/// Whether the user has chosen a language (first launch gate).
final hasChosenLocaleProvider = Provider<bool>((ref) {
  return ref.watch(localeProvider) != null;
});

/// Current app locale. Null means no language has been chosen yet.
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocaleNotifier(prefs);
});

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier(this._prefs) : super(_loadLocale(_prefs));

  final SharedPreferences _prefs;

  static Locale? _loadLocale(SharedPreferences prefs) {
    final code = prefs.getString(_kLocaleKey);
    if (code == null) return null;
    return Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _prefs.setString(_kLocaleKey, locale.languageCode);
  }
}
