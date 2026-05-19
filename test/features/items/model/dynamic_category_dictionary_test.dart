import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/dynamic_category_dictionary.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/services/category_infer_service.dart';

const _sampleJson = {
  'version': 2,
  'locale': 'it',
  'exactMatches': {
    'maglietta': 'vestiti',
    'shampoo': 'toiletries',
    'laptop': 'elettronica',
    'quaderno': 'varie',
  },
  'stopWords': ['il', 'lo', 'la', 'di', 'da'],
  'rootKeywords': [
    {'root': 'magli', 'category': 'vestiti'},
    {'root': 'sham', 'category': 'toiletries'},
  ],
  'irregularPlurals': {'jeans': 'jeans', 'shorts': 'shorts'},
  'lemmatizeSuffixes': [
    {'from': 'i', 'to': ''},
    {'from': 'e', 'to': 'a'},
  ],
};

void main() {
  group('DynamicCategoryDictionary.fromJson', () {
    late DynamicCategoryDictionary dictionary;

    setUp(() {
      dictionary = DynamicCategoryDictionary.fromJson(_sampleJson);
    });

    test('parses version and locale', () {
      expect(dictionary.version, 2);
      expect(dictionary.locale, 'it');
    });

    test('parses exactMatches with correct categories', () {
      expect(dictionary.exactMatches['maglietta'], ItemCategory.vestiti);
      expect(dictionary.exactMatches['shampoo'], ItemCategory.toiletries);
      expect(dictionary.exactMatches['laptop'], ItemCategory.elettronica);
      expect(dictionary.exactMatches['quaderno'], ItemCategory.varie);
    });

    test('parses stopWords as Set', () {
      expect(dictionary.stopWords, containsAll(['il', 'lo', 'la', 'di', 'da']));
      expect(dictionary.stopWords.length, 5);
    });

    test('parses rootKeywords', () {
      expect(dictionary.rootKeywords.length, 2);
      expect(dictionary.rootKeywords[0].root, 'magli');
      expect(dictionary.rootKeywords[0].category, ItemCategory.vestiti);
    });

    test('unknown category name falls back to varie', () {
      final json = Map<String, dynamic>.from(_sampleJson);
      json['exactMatches'] = {'test': 'nonexistent_category'};
      final d = DynamicCategoryDictionary.fromJson(json);
      expect(d.exactMatches['test'], ItemCategory.varie);
    });
  });

  group('DynamicCategoryDictionary.parseFromJsonString', () {
    test('parses JSON string correctly', () {
      final jsonString = jsonEncode(_sampleJson);
      final dictionary = DynamicCategoryDictionary.parseFromJsonString(
        jsonString,
      );
      expect(dictionary.version, 2);
      expect(dictionary.exactMatches['maglietta'], ItemCategory.vestiti);
    });
  });

  group('DynamicCategoryDictionary lemmatization', () {
    late DynamicCategoryDictionary dictionary;

    setUp(() {
      dictionary = DynamicCategoryDictionary.fromJson(_sampleJson);
    });

    test('returns word unchanged if <= 3 chars', () {
      expect(dictionary.lemmatize('abc'), 'abc');
      expect(dictionary.lemmatize('il'), 'il');
    });

    test('handles irregular plurals', () {
      expect(dictionary.lemmatize('jeans'), 'jeans');
      expect(dictionary.lemmatize('shorts'), 'shorts');
    });

    test('applies suffix rules in order', () {
      expect(dictionary.lemmatize('pantaloni'), 'pantalon');
      expect(dictionary.lemmatize('scarpe'), 'scarpa');
    });

    test('returns unchanged word if no suffix matches', () {
      expect(dictionary.lemmatize('laptop'), 'laptop');
    });
  });

  group('DynamicCategoryDictionary with CategoryInferService', () {
    late CategoryInferService service;

    setUp(() {
      final dictionary = DynamicCategoryDictionary.fromJson(_sampleJson);
      service = CategoryInferService(dictionary);
    });

    test('exact match works', () {
      final result = service.infer('maglietta');
      expect(result.category, ItemCategory.vestiti);
      expect(result.confidence, InferConfidence.exact);
    });

    test('root match works', () {
      final result = service.infer('maglioncino');
      expect(result.category, ItemCategory.vestiti);
      expect(result.confidence, InferConfidence.partial);
    });

    test('stop words are filtered', () {
      final result = service.infer('il laptop');
      expect(result.category, ItemCategory.elettronica);
    });

    test('fallback on unknown word', () {
      final result = service.infer('xyznotfound');
      expect(result.category, ItemCategory.varie);
      expect(result.confidence, InferConfidence.fallback);
    });
  });

  group('DynamicCategoryDictionary optional fields', () {
    test('works without irregularPlurals and lemmatizeSuffixes', () {
      final minimalJson = {
        'version': 1,
        'locale': 'en',
        'exactMatches': {'shirt': 'vestiti'},
        'stopWords': ['the'],
        'rootKeywords': [
          {'root': 'shirt', 'category': 'vestiti'},
        ],
      };
      final dictionary = DynamicCategoryDictionary.fromJson(minimalJson);
      expect(dictionary.exactMatches['shirt'], ItemCategory.vestiti);
      expect(dictionary.lemmatize('shirts'), 'shirts');
    });
  });
}
