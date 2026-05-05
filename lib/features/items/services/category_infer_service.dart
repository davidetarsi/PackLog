import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/features/items/model/category_dictionary.dart';
import 'package:pack_log/features/items/repositories/dictionary_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/item_model.dart';
import '../model/italian_dictionary.dart';
import 'package:pack_log/shared/providers/language_locale.dart';

part 'category_infer_service.g.dart';

enum InferConfidence { exact, partial, fallback }

typedef InferResult = ({ItemCategory category, InferConfidence confidence});

class CategoryInferService {
  final CategoryDictionary _dictionary;

  static final RegExp _whitespaceRegExp = RegExp(r'\s+');

  static const Map<String, String> _accentsMap = {
    'à': 'a',
    'è': 'e',
    'é': 'e',
    'ì': 'i',
    'ò': 'o',
    'ù': 'u',
  };

  const CategoryInferService(this._dictionary);

  InferResult infer(String rawName) {
    if (rawName.trim().isEmpty) {
      return _fallback();
    }

    final normalized = _normalize(rawName);

    final lemmatizedFull = _dictionary.lemmatize(normalized);
    final fullExactMatch = _dictionary.exactMatches[lemmatizedFull];

    if (fullExactMatch != null) {
      return (category: fullExactMatch, confidence: InferConfidence.exact);
    }

    final tokens = normalized
        .split(_whitespaceRegExp)
        .where((t) => t.length >= 3 && !_dictionary.stopWords.contains(t))
        .toList(growable: false);

    if (tokens.isEmpty) {
      return _fallback();
    }

    for (final token in tokens) {
      final lemmatizedToken = _dictionary.lemmatize(token);

      final tokenExactMatch = _dictionary.exactMatches[lemmatizedToken];
      if (tokenExactMatch != null) {
        return (category: tokenExactMatch, confidence: InferConfidence.partial);
      }

      for (final rootEntry in _dictionary.rootKeywords) {
        if (lemmatizedToken.startsWith(rootEntry.root)) {
          return (
            category: rootEntry.category,
            confidence: InferConfidence.partial
          );
        }
      }

      for (final exactEntry in _dictionary.exactMatches.entries) {
        if (exactEntry.key.startsWith(lemmatizedToken)) {
          return (
            category: exactEntry.value,
            confidence: InferConfidence.partial
          );
        }
      }
    }

    return _fallback();
  }

  InferResult _fallback() =>
      (category: ItemCategory.varie, confidence: InferConfidence.fallback);

  String _normalize(String input) {
    String result = input.trim().toLowerCase();

    for (final entry in _accentsMap.entries) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }

    return result.replaceAll(_whitespaceRegExp, ' ');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

@Riverpod(keepAlive: true)
DictionaryRepository dictionaryRepository(Ref ref) {
  return DictionaryRepository(Supabase.instance.client);
}

@Riverpod(keepAlive: true)
Future<CategoryDictionary> dynamicDictionary(Ref ref) async {
  final locale = ref.watch(languageLocaleProvider);
  final repo = ref.read(dictionaryRepositoryProvider);

  try {
    return await repo.loadDictionary(locale);
  } catch (e) {
    debugPrint('[dynamicDictionaryProvider] Fallback to bundled dictionary: $e');
    return ItalianDictionary();
  }
}

@Riverpod(keepAlive: true)
Future<CategoryInferService> categoryInferService(Ref ref) async {
  final dictionary = await ref.watch(dynamicDictionaryProvider.future);
  return CategoryInferService(dictionary);
}
