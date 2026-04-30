import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/features/items/model/category_dictionary.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/item_model.dart';
import '../model/italian_dictionary.dart';
import 'package:pack_log/shared/providers/language_locale.dart';

part 'category_infer_service.g.dart';

enum InferConfidence { exact, partial, fallback }

class CategoryInferService {
  final CategoryDictionary _dictionary;

  const CategoryInferService(this._dictionary);

  ({ItemCategory category, InferConfidence confidence}) infer(String rawName) {
    final normalized = _normalize(rawName);
    if (normalized.isEmpty) {
      return (
        category: ItemCategory.varie,
        confidence: InferConfidence.fallback,
      );
    }

    final lemmatizedFull = _dictionary.lemmatize(normalized);

    if (_dictionary.exactMatches.containsKey(lemmatizedFull)) {
      return (
        category: _dictionary.exactMatches[lemmatizedFull]!,
        confidence: InferConfidence.exact,
      );
    }

    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3 && !_dictionary.stopWords.contains(t))
        .toList();

    for (final token in tokens) {
      final lemmatizedToken = _dictionary.lemmatize(token);

      final exactMatch = _dictionary.exactMatches[lemmatizedToken];
      if (exactMatch != null) {
        return (category: exactMatch, confidence: InferConfidence.partial);
      }

      for (final exactKey in _dictionary.exactMatches.keys) {
        if (exactKey.startsWith(lemmatizedToken)) {
          return (
            category: _dictionary.exactMatches[exactKey]!,
            confidence: InferConfidence.partial,
          );
        }
      }
    }

    for (final entry in _dictionary.rootKeywords) {
      if (tokens.any((token) => token.startsWith(entry.root))) {
        return (category: entry.category, confidence: InferConfidence.partial);
      }
    }

    return (category: ItemCategory.varie, confidence: InferConfidence.fallback);
  }

  String _normalize(String input) {
    var result = input.trim().toLowerCase();
    result = _removeAccents(result);
    return result.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _removeAccents(String input) {
    const accents = {
      'à': 'a',
      'è': 'e',
      'é': 'e',
      'ì': 'i',
      'ò': 'o',
      'ù': 'u',
    };
    var result = input;
    for (final entry in accents.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}

@Riverpod(keepAlive: true)
CategoryInferService categoryInferService(Ref ref) {
  final currentLocaleCode = ref.watch(languageLocaleProvider);

  CategoryDictionary dictionary = ItalianDictionary(); // Default
  switch (currentLocaleCode) {
    case 'it':
      dictionary = ItalianDictionary();
      break;
    case 'en':
      // dictionary = EnglishDictionary(); // Da implementare
      break;
    default:
      dictionary = ItalianDictionary();
      break;
  }

  return CategoryInferService(dictionary);
}
