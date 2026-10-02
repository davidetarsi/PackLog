import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/dictionary_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

const _sampleDictionaryJson = {
  'version': 3,
  'locale': 'it',
  'exactMatches': {'maglietta': 'vestiti', 'laptop': 'elettronica'},
  'stopWords': ['il', 'lo'],
  'rootKeywords': [
    {'root': 'magli', 'category': 'vestiti'},
  ],
  'irregularPlurals': {'jeans': 'jeans'},
  'lemmatizeSuffixes': [
    {'from': 'i', 'to': ''},
  ],
};

void main() {
  late MockSupabaseClient mockSupabase;
  late DictionaryRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockSupabase = MockSupabaseClient();
    repository = DictionaryRepository(mockSupabase);
  });

  group('loadDictionary', () {
    test(
      'returns cached dictionary when available in SharedPreferences',
      () async {
        final jsonString = jsonEncode(_sampleDictionaryJson);
        SharedPreferences.setMockInitialValues({
          'dictionary_json_cache_it': jsonString,
          'dictionary_version_cache_it': 3,
        });

        final dictionary = await repository.loadDictionary('it');

        expect(dictionary.version, 3);
        expect(dictionary.locale, 'it');
        expect(dictionary.exactMatches['maglietta'], ItemCategory.vestiti);
        expect(dictionary.exactMatches['laptop'], ItemCategory.elettronica);
      },
    );

    test('downloads from Supabase when cache is empty', () async {
      SharedPreferences.setMockInitialValues({});

      final jsonString = jsonEncode(_sampleDictionaryJson);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      final mockStorage = MockSupabaseStorageClient();
      final mockFileApi = MockStorageFileApi();

      when(() => mockSupabase.storage).thenReturn(mockStorage);
      when(() => mockStorage.from('dictionaries')).thenReturn(mockFileApi);
      when(
        () => mockFileApi.download('dictionary_it.json'),
      ).thenAnswer((_) async => bytes);

      final dictionary = await repository.loadDictionary('it');

      expect(dictionary.version, 3);
      expect(dictionary.exactMatches['maglietta'], ItemCategory.vestiti);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dictionary_json_cache_it'), isNotNull);
      expect(prefs.getInt('dictionary_version_cache_it'), 3);
    });

    test('uses locale-specific cache keys', () async {
      final jsonIt = jsonEncode(_sampleDictionaryJson);
      final enJson = Map<String, dynamic>.from(_sampleDictionaryJson);
      enJson['locale'] = 'en';
      enJson['version'] = 5;
      final jsonEn = jsonEncode(enJson);

      SharedPreferences.setMockInitialValues({
        'dictionary_json_cache_it': jsonIt,
        'dictionary_version_cache_it': 3,
        'dictionary_json_cache_en': jsonEn,
        'dictionary_version_cache_en': 5,
      });

      final itDict = await repository.loadDictionary('it');
      final enDict = await repository.loadDictionary('en');

      expect(itDict.locale, 'it');
      expect(itDict.version, 3);
      expect(enDict.locale, 'en');
      expect(enDict.version, 5);
    });

    test('throws when cache is empty and Supabase download fails', () async {
      SharedPreferences.setMockInitialValues({});

      final mockStorage = MockSupabaseStorageClient();
      final mockFileApi = MockStorageFileApi();

      when(() => mockSupabase.storage).thenReturn(mockStorage);
      when(() => mockStorage.from('dictionaries')).thenReturn(mockFileApi);
      when(
        () => mockFileApi.download('dictionary_it.json'),
      ).thenThrow(StorageException('Network error'));

      expect(
        () => repository.loadDictionary('it'),
        throwsA(isA<StorageException>()),
      );
    });
  });
}
