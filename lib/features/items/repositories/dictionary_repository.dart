import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/dynamic_category_dictionary.dart';

class DictionaryRepository {
  final SupabaseClient _supabase;

  DictionaryRepository(this._supabase);

  static const _jsonCachePrefix = 'dictionary_json_cache_';
  static const _versionCachePrefix = 'dictionary_version_cache_';
  static const _storageBucket = 'dictionaries';

  Future<DynamicCategoryDictionary> loadDictionary(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('$_jsonCachePrefix$locale');

    if (cachedJson != null) {
      final dictionary =
          await DynamicCategoryDictionary.parseInIsolate(cachedJson);

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

  Future<void> _checkForUpdates(
    String locale,
    SharedPreferences prefs,
  ) async {
    final response = await _supabase
        .from('app_config')
        .select('value')
        .eq('key', 'dictionary_version_$locale')
        .maybeSingle();

    if (response == null) return;

    final remoteVersion = int.tryParse(response['value'] as String) ?? 0;
    final localVersion = prefs.getInt('$_versionCachePrefix$locale') ?? 0;

    if (remoteVersion > localVersion) {
      await _downloadAndCache(locale, prefs);
    }
  }

  Future<DynamicCategoryDictionary> _downloadAndCache(
    String locale,
    SharedPreferences prefs,
  ) async {
    final bytes = await _supabase.storage
        .from(_storageBucket)
        .download('dictionary_$locale.json');

    final jsonString = utf8.decode(bytes);
    final dictionary =
        await DynamicCategoryDictionary.parseInIsolate(jsonString);

    await prefs.setString('$_jsonCachePrefix$locale', jsonString);
    await prefs.setInt('$_versionCachePrefix$locale', dictionary.version);

    return dictionary;
  }
}
