import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/ai_input/helpers/scan_analytics.dart';
import 'package:pack_log/features/ai_input/model/ai_import_state.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';

ClothingAnalysisResult _capo(
  String subCategory, {
  String? name,
  int warmth = 3,
  String formality = 'Casual',
  List<String> doubts = const [],
  Map<String, Object?> doubtJev = const {},
}) => ClothingAnalysisResult(
  name: name ?? subCategory.toLowerCase(),
  category: 'Upper Body',
  subCategory: subCategory,
  baseColor: 'Nero',
  pattern: 'Solid',
  coverage: '',
  fit: 'Regular',
  warmth: warmth,
  formality: formality,
  activityTags: const ['Everyday'],
  doubts: doubts,
  doubtJev: doubtJev,
);

void main() {
  group('scanSaveStats', () {
    final originals = [
      _capo('Shorts'),
      _capo('T-Shirt'),
      _capo('Jewelry'),
      _capo('Sneakers'),
    ];
    final analyzed = {
      for (var i = 0; i < originals.length; i++) (0, i): originals[i],
    };

    AiImportState stateWith(List<ClothingAnalysisResult> results) =>
        AiImportState(
          photoGroups: [
            PhotoGroup(
              photo: File('foto.jpg'),
              results: results,
              excluded: {2},
            ),
          ],
        );

    test('conta trovati, salvati, esclusi e rinominati', () {
      final state = stateWith([
        originals[0].copyWith(name: 'i miei pantaloncini'),
        originals[1],
        originals[2],
        originals[3].copyWith(warmth: 1),
      ]);
      final stats = scanSaveStats(state, analyzed);
      expect(stats.found, 4);
      expect(stats.saved, 3);
      expect(stats.excluded, 1);
      expect(stats.renamed, 1);
      expect(stats.detailsEdited, 1);
      expect(stats.photos, 1);
      expect(stats.excludedTypes, ['Jewelry']);
      expect(stats.renamedTypes, ['Shorts']);
    });

    test('una rinomina che cambia solo gli spazi non conta', () {
      final state = stateWith([
        originals[0].copyWith(name: '  shorts '),
        ...originals.skip(1),
      ]);
      expect(scanSaveStats(state, analyzed).renamed, 0);
    });
  });

  group('doubtOutcome', () {
    final dubbioCalore = _capo(
      'Sweater',
      warmth: 3,
      doubts: const ['warmth'],
      doubtJev: const {'warmth': 4},
    );

    test('scelto il valore di Jev', () {
      final outcome = doubtOutcome(
        dubbioCalore,
        dubbioCalore.copyWith(warmth: 4),
      );
      expect(outcome!.doubtFields, ['warmth']);
      expect(outcome.choseJev, ['warmth']);
      expect(outcome.keptGpt, isEmpty);
      expect(outcome.otherValue, isEmpty);
      expect(outcome.subCategory, 'Sweater');
    });

    test('tenuto il valore di GPT', () {
      expect(doubtOutcome(dubbioCalore, dubbioCalore)!.keptGpt, ['warmth']);
    });

    test('scelto un terzo valore', () {
      final outcome = doubtOutcome(
        dubbioCalore,
        dubbioCalore.copyWith(warmth: 5),
      );
      expect(outcome!.otherValue, ['warmth']);
    });

    test('corretto un campo senza dubbio', () {
      final senzaDubbi = _capo('Sweater');
      final outcome = doubtOutcome(
        senzaDubbi,
        senzaDubbi.copyWith(formality: 'Formal'),
      );
      expect(outcome!.doubtFields, isEmpty);
      expect(outcome.correctedWithoutDoubt, ['formality']);
    });

    test('niente dubbi e niente cambiato: null', () {
      final senzaDubbi = _capo('Sweater');
      expect(doubtOutcome(senzaDubbi, senzaDubbi), isNull);
    });
  });

  group('ClothingAnalysisResult.doubtJev', () {
    test('tiene la proposta di Jev ma non la scrive in ai_metadata', () {
      final result = ClothingAnalysisResult.fromItemMetadata({
        'metadata': {'name': 'felpa', 'warmth': 3},
        'app_category': 'vestiti',
        'dubbi': [
          {'campo': 'warmth', 'valore': 3, 'jev': 4, 'sicurezza': 0.6},
        ],
      });
      expect(result.doubts, ['warmth']);
      expect(result.doubtJev, {'warmth': 4});
      expect(result.toJson().containsKey('doubtJev'), isFalse);
    });
  });
}
