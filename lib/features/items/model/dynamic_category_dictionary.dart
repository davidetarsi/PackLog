import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'category_dictionary.dart';
import 'item_model.dart';

class DynamicCategoryDictionary implements CategoryDictionary {
  final int version;
  final String locale;

  @override
  final Map<String, ItemCategory> exactMatches;

  @override
  final List<({String root, ItemCategory category})> rootKeywords;

  @override
  final Set<String> stopWords;

  final Map<String, String> _irregularPlurals;
  final List<({String from, String to})> _lemmatizeSuffixes;

  const DynamicCategoryDictionary({
    required this.version,
    required this.locale,
    required this.exactMatches,
    required this.rootKeywords,
    required this.stopWords,
    required Map<String, String> irregularPlurals,
    required List<({String from, String to})> lemmatizeSuffixes,
  })  : _irregularPlurals = irregularPlurals,
        _lemmatizeSuffixes = lemmatizeSuffixes;

  @override
  String lemmatize(String word) {
    if (word.length <= 3) return word;

    if (_irregularPlurals.containsKey(word)) {
      return _irregularPlurals[word]!;
    }

    for (final suffix in _lemmatizeSuffixes) {
      if (word.endsWith(suffix.from)) {
        return '${word.substring(0, word.length - suffix.from.length)}${suffix.to}';
      }
    }

    return word;
  }

  static DynamicCategoryDictionary parseFromJsonString(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return fromJson(map);
  }

  static DynamicCategoryDictionary fromJson(Map<String, dynamic> json) {
    final rawExact = json['exactMatches'] as Map<String, dynamic>;
    final exactMatches = rawExact.map(
      (key, value) => MapEntry(key, _parseCategory(value as String)),
    );

    final rawRoots = json['rootKeywords'] as List<dynamic>;
    final rootKeywords = rawRoots.map((e) {
      final map = e as Map<String, dynamic>;
      return (
        root: map['root'] as String,
        category: _parseCategory(map['category'] as String),
      );
    }).toList(growable: false);

    final rawStop = json['stopWords'] as List<dynamic>;
    final stopWords = rawStop.cast<String>().toSet();

    final rawIrregular =
        json['irregularPlurals'] as Map<String, dynamic>? ?? {};
    final irregularPlurals = rawIrregular.cast<String, String>();

    final rawSuffixes = json['lemmatizeSuffixes'] as List<dynamic>? ?? [];
    final lemmatizeSuffixes = rawSuffixes.map((e) {
      final map = e as Map<String, dynamic>;
      return (from: map['from'] as String, to: map['to'] as String);
    }).toList(growable: false);

    return DynamicCategoryDictionary(
      version: json['version'] as int,
      locale: json['locale'] as String,
      exactMatches: exactMatches,
      rootKeywords: rootKeywords,
      stopWords: stopWords,
      irregularPlurals: irregularPlurals,
      lemmatizeSuffixes: lemmatizeSuffixes,
    );
  }

  static ItemCategory _parseCategory(String value) {
    return ItemCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => ItemCategory.varie,
    );
  }

  static Future<DynamicCategoryDictionary> parseInIsolate(
    String jsonString,
  ) {
    return compute(parseFromJsonString, jsonString);
  }
}
