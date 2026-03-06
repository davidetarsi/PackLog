import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_provider.g.dart';

/// Chiave per salvare la preferenza tema in SharedPreferences
const String _themeModeKey = 'theme_mode';

/// Provider per gestire il ThemeMode dell'applicazione.
/// Salva e carica la preferenza da SharedPreferences.
@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  static const ThemeMode _defaultThemeMode = ThemeMode.dark;

  @override
  Future<ThemeMode> build() async {
    return await _loadThemeMode();
  }

  /// Carica la preferenza tema salvata
  Future<ThemeMode> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString(_themeModeKey);
      
      if (themeModeString == null) return _defaultThemeMode;
      
      return ThemeMode.values.firstWhere(
        (mode) => mode.name == themeModeString,
        orElse: () => _defaultThemeMode,
      );
    } catch (e) {
      debugPrint('[ThemeProvider] Errore caricamento tema: $e');
      return _defaultThemeMode;
    }
  }

  /// Cambia il tema e salva la preferenza
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
      state = AsyncValue.data(mode);
    } catch (e) {
      debugPrint('[ThemeProvider] Errore salvataggio tema: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
