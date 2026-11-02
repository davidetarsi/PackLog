import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/once_per_day.dart';
import '../model/dynamic_category_dictionary.dart';

class DictionaryRepository {
  final SupabaseClient _supabase;
  final bool Function() _hasSession;

  /// [hasSession] solo per i test: di norma si guarda la sessione di Supabase.
  DictionaryRepository(this._supabase, {bool Function()? hasSession})
    : _hasSession = hasSession ?? (() => _supabase.auth.currentSession != null);

  static const _jsonCachePrefix = 'dictionary_json_cache_';
  static const _versionCachePrefix = 'dictionary_version_cache_';
  static const _checkedOnPrefix = 'dictionary_checked_on_';
  static const _storageBucket = 'dictionaries';

  Future<DynamicCategoryDictionary> loadDictionary(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('$_jsonCachePrefix$locale');

    if (cachedJson != null) {
      final dictionary = await DynamicCategoryDictionary.parseInIsolate(
        cachedJson,
      );

      _checkForUpdatesInBackground(locale, prefs);

      return dictionary;
    }

    return _downloadAndCache(locale, prefs);
  }

  void _checkForUpdatesInBackground(String locale, SharedPreferences prefs) {
    _checkForUpdates(locale, prefs).catchError((Object e) {
      debugPrint('[DictionaryRepository] Background update check failed: $e');
    });
  }

  Future<void> _checkForUpdates(String locale, SharedPreferences prefs) async {
    // Al massimo una volta al giorno (decisione di Davide del 31 ottobre), e il
    // giorno si segna solo dopo una risposta del server con l'utente autenticato.
    await runOncePerDay<Object?>(
      key: '$_checkedOnPrefix$locale',
      hasSession: _hasSession(),
      action: () async {
        final response = await _supabase
            .from('app_config')
            .select('value')
            .eq('key', 'dictionary_version_$locale')
            .maybeSingle();

        if (response == null) return null;

        final remoteVersion = int.tryParse(response['value'] as String) ?? 0;
        final localVersion = prefs.getInt('$_versionCachePrefix$locale') ?? 0;

        if (remoteVersion > localVersion) {
          await _downloadAndCache(locale, prefs);
        }
        return null;
      },
    );
  }

  Future<DynamicCategoryDictionary> _downloadAndCache(
    String locale,
    SharedPreferences prefs,
  ) async {
    final bytes = await _supabase.storage
        .from(_storageBucket)
        .download('dictionary_$locale.json');

    final jsonString = utf8.decode(bytes);
    final dictionary = await DynamicCategoryDictionary.parseInIsolate(
      jsonString,
    );

    await prefs.setString('$_jsonCachePrefix$locale', jsonString);
    await prefs.setInt('$_versionCachePrefix$locale', dictionary.version);

    return dictionary;
  }
}
