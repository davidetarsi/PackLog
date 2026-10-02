import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/model/italian_dictionary.dart';
import 'package:pack_log/features/items/services/category_infer_service.dart';

void main() {
  final dictionary = ItalianDictionary();
  final service = CategoryInferService(dictionary);

  group('Normalization', () {
    test('handles uppercase', () {
      final result = service.infer('MAGLIETTA');
      expect(result.category, ItemCategory.vestiti);
    });

    test('handles leading/trailing whitespace', () {
      final result = service.infer('  maglietta  ');
      expect(result.category, ItemCategory.vestiti);
    });

    test('handles accented characters', () {
      final result = service.infer('Magliétta');
      expect(result.category, ItemCategory.vestiti);
    });

    test('handles mixed case', () {
      final result = service.infer('Maglietta');
      expect(result.category, ItemCategory.vestiti);
    });
  });

  group('Exact match', () {
    final sampleEntries = <String, ItemCategory>{
      'maglietta': ItemCategory.vestiti,
      'jeans': ItemCategory.vestiti,
      'felpa': ItemCategory.vestiti,
      'scarpe': ItemCategory.vestiti,
      'cappello': ItemCategory.vestiti,
      'bikini': ItemCategory.vestiti,
      'pigiama': ItemCategory.vestiti,
      'cintura': ItemCategory.vestiti,
      'spazzolino': ItemCategory.toiletries,
      'dentifricio': ItemCategory.toiletries,
      'shampoo': ItemCategory.toiletries,
      'deodorante': ItemCategory.toiletries,
      'crema solare': ItemCategory.toiletries,
      'mascara': ItemCategory.toiletries,
      'cerotti': ItemCategory.toiletries,
      'profumo': ItemCategory.toiletries,
      'medicinali': ItemCategory.toiletries,
      'occhiali da sole': ItemCategory.toiletries,
      'caricatore': ItemCategory.elettronica,
      'cuffie': ItemCategory.elettronica,
      'laptop': ItemCategory.elettronica,
      'tablet': ItemCategory.elettronica,
      'power bank': ItemCategory.elettronica,
      'smartphone': ItemCategory.elettronica,
      'hard disk': ItemCategory.elettronica,
      'airpods': ItemCategory.elettronica,
      'treppiede': ItemCategory.elettronica,
      'drone': ItemCategory.elettronica,
    };

    for (final entry in sampleEntries.entries) {
      test('${entry.key} → ${entry.value.name}', () {
        final result = service.infer(entry.key);
        expect(result.category, entry.value);
        expect(result.confidence, InferConfidence.exact);
      });
    }
  });

  group('Compound match', () {
    test('maglietta rossa → vestiti/partial', () {
      final result = service.infer('maglietta rossa');
      expect(result.category, ItemCategory.vestiti);
      expect(result.confidence, InferConfidence.partial);
    });

    test('cavo usb nuovo → elettronica/partial', () {
      final result = service.infer('cavo usb nuovo');
      expect(result.category, ItemCategory.elettronica);
      expect(result.confidence, InferConfidence.partial);
    });

    test('il mio shampoo preferito → toiletries/partial', () {
      final result = service.infer('il mio shampoo preferito');
      expect(result.category, ItemCategory.toiletries);
      expect(result.confidence, InferConfidence.partial);
    });

    test('pantaloni eleganti → vestiti/partial', () {
      final result = service.infer('pantaloni eleganti');
      expect(result.category, ItemCategory.vestiti);
      expect(result.confidence, InferConfidence.partial);
    });
  });

  group('Substring/root match', () {
    test('spazzolino elettrico → toiletries/partial', () {
      final result = service.infer('spazzolino elettrico');
      expect(result.category, ItemCategory.toiletries);
    });

    test('caricabatterie portatile → elettronica/partial', () {
      final result = service.infer('caricabatterie portatile');
      expect(result.category, ItemCategory.elettronica);
    });

    test('maglioncino → vestiti/partial (root maglion)', () {
      final result = service.infer('maglioncino');
      expect(result.category, ItemCategory.vestiti);
      expect(result.confidence, InferConfidence.partial);
    });

    test('giacchetta → vestiti/partial (root giacc)', () {
      final result = service.infer('giacchetta');
      expect(result.category, ItemCategory.vestiti);
      expect(result.confidence, InferConfidence.partial);
    });
  });

  group('Fallback', () {
    test('unknown word → varie/fallback', () {
      final result = service.infer('quaderno');
      expect(result.category, ItemCategory.varie);
      expect(result.confidence, InferConfidence.fallback);
    });

    test('empty string → varie/fallback', () {
      final result = service.infer('');
      expect(result.category, ItemCategory.varie);
      expect(result.confidence, InferConfidence.fallback);
    });

    test('whitespace only → varie/fallback', () {
      final result = service.infer('   ');
      expect(result.category, ItemCategory.varie);
      expect(result.confidence, InferConfidence.fallback);
    });
  });

  group('Keyword data integrity', () {
    test('rootKeywords are sorted by root length descending', () {
      final rootKeywords = dictionary.rootKeywords;
      for (var i = 0; i < rootKeywords.length - 1; i++) {
        expect(
          rootKeywords[i].root.length,
          greaterThanOrEqualTo(rootKeywords[i + 1].root.length),
          reason:
              'Root "${rootKeywords[i].root}" (len ${rootKeywords[i].root.length}) '
              'should be >= "${rootKeywords[i + 1].root}" (len ${rootKeywords[i + 1].root.length})',
        );
      }
    });
  });
}
