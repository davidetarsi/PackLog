import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/item_model.dart';
import 'category_keywords.dart';

part 'category_infer_service.g.dart';

enum InferConfidence { exact, partial, fallback }

class CategoryInferService {
  const CategoryInferService();

  ({ItemCategory category, InferConfidence confidence}) infer(String rawName) {
    final normalized = _normalize(rawName);
    if (normalized.isEmpty) {
      return (category: ItemCategory.varie, confidence: InferConfidence.fallback);
    }

    // 1. Exact match on the full normalized name
    final exactMatch = kExactMatchKeywords[normalized];
    if (exactMatch != null) {
      return (category: exactMatch, confidence: InferConfidence.exact);
    }

    // 1.5. Prefix match sulla stringa senza spazi (es. "t shirt" → "tshirt")
    // Usa startsWith anziché contains per evitare falsi positivi come
    // "pantaloni eleganti" → "pantaloneleganti" che contiene "anti"
    // (root per antistaminico) nel mezzo di "eleganti".
    final spaceStripped = normalized.replaceAll(' ', '');
    for (final entry in kRootKeywords) {
      if (spaceStripped.startsWith(entry.root)) {
        return (category: entry.category, confidence: InferConfidence.partial);
      }
    }

    // 2. Compound match: split into tokens, filter stop words + short tokens
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3 && !kStopWords.contains(t))
        .toList();

    for (final token in tokens) {
      final tokenMatch = kExactMatchKeywords[token];
      if (tokenMatch != null) {
        return (category: tokenMatch, confidence: InferConfidence.partial);
      }
    }

    // 3. Substring match against root keywords (ordered longest-first)
    for (final entry in kRootKeywords) {
      //if (normalized.contains(entry.root))
      if (tokens.any((token) => token.startsWith(entry.root))) {
        return (category: entry.category, confidence: InferConfidence.partial);
      }
    }

    // 4. Fallback
    return (category: ItemCategory.varie, confidence: InferConfidence.fallback);
  }

  String _normalize(String input) {
    var result = input.trim().toLowerCase();
    result = _removeAccents(result);
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    return result;
  }

  static String _removeAccents(String input) {
    const accents = {
      'à': 'a', 'è': 'e', 'é': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
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
  return const CategoryInferService();
}
