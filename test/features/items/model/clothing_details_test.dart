import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';
import 'package:pack_log/features/items/model/clothing_details.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

ClothingAnalysisResult _maglione() => ClothingAnalysisResult(
  name: 'Maglione',
  category: 'Upper Body',
  subCategory: 'Sweater',
  baseColor: 'Blu',
  pattern: 'Solid',
  coverage: 'Long-sleeve',
  fit: 'Regular',
  warmth: 4,
  formality: 'Casual',
  activityTags: const ['Everyday', 'Hiking'],
  extras: const {'waterResistance': 1, 'bulk': 3, 'notClothingKind': false},
);

void main() {
  group('ClothingDetails.of', () {
    test('legge i dettagli dal risultato', () {
      final d = ClothingDetails.of(_maglione());
      expect(d.subCategory, 'Sweater');
      expect(d.color, 'Blu');
      expect(d.warmth, 4);
      expect(d.waterResistance, 1);
      expect(d.formality, 'Casual');
      expect(d.uses, {'Everyday', 'Hiking'});
    });

    test('color è null se baseColor è vuoto o N/A', () {
      expect(
        ClothingDetails.of(_maglione().copyWith(baseColor: '')).color,
        isNull,
      );
      expect(
        ClothingDetails.of(_maglione().copyWith(baseColor: '   ')).color,
        isNull,
      );
      expect(
        ClothingDetails.of(_maglione().copyWith(baseColor: 'N/A')).color,
        isNull,
      );
      expect(
        ClothingDetails.of(_maglione().copyWith(baseColor: 'n/a')).color,
        isNull,
      );
    });
  });

  group('ClothingDetails.applyTo', () {
    test('conserva chiavi sconosciute ed extras, aggiunge waterResistance', () {
      final before = _maglione();
      final d = ClothingDetails.of(before).copyWith(waterResistance: 2);
      final after = d.applyTo(before);
      expect(after.extras['bulk'], 3);
      expect(after.extras['notClothingKind'], false);
      expect(after.extras['waterResistance'], 2);
      expect(after.waterResistance, 2);
      expect(after.coverage, before.coverage);
      expect(after.fit, before.fit);
      expect(after.pattern, before.pattern);
      expect(after.name, before.name);
    });

    test('cambio di tipo aggiorna anche category', () {
      final before = _maglione();
      final d = ClothingDetails.of(
        before,
      ).copyWith(subCategory: 'Hiking Boots');
      final after = d.applyTo(before);
      expect(after.subCategory, 'Hiking Boots');
      expect(after.category, 'Shoes');
    });

    test('sottocategoria sconosciuta o Other non cambia category', () {
      final before = _maglione();
      final other = ClothingDetails.of(
        before,
      ).copyWith(subCategory: 'Other').applyTo(before);
      expect(other.category, 'Upper Body');
      final unknown = ClothingDetails.of(
        before,
      ).copyWith(subCategory: 'Inventato').applyTo(before);
      expect(unknown.category, 'Upper Body');
    });

    test('color null diventa N/A', () {
      final before = _maglione();
      final after = ClothingDetails.of(
        before,
      ).copyWith(clearColor: true).applyTo(before);
      expect(after.baseColor, 'N/A');
    });

    test('activityTags in ordine canonico, solo quelli in uses', () {
      final before = _maglione();
      final after = ClothingDetails.of(
        before,
      ).copyWith(uses: {'Hiking', 'Beach', 'Everyday'}).applyTo(before);
      expect(after.activityTags, ['Everyday', 'Beach', 'Hiking']);
    });

    test('doubts restano quelli di r', () {
      final before = _maglione().withDoubts(const ['warmth']);
      final after = ClothingDetails.of(before).applyTo(before);
      expect(after.doubts, ['warmth']);
      expect(after.toJson().containsKey('doubts'), isFalse);
    });
  });

  group('changedFields', () {
    test('nessuna modifica: lista vuota', () {
      final d = ClothingDetails.of(_maglione());
      expect(d.changedFields(d), isEmpty);
    });

    test('elenca i campi cambiati nell\'ordine canonico', () {
      final before = ClothingDetails.of(_maglione());
      final after = before.copyWith(
        formality: 'Business',
        warmth: 2,
        subCategory: 'Shirt',
        uses: {'Office'},
        waterResistance: 0,
      );
      expect(after.changedFields(before), [
        'subCategory',
        'warmth',
        'waterResistance',
        'formality',
        'activityTags',
      ]);
    });

    test('il colore confronta senza spazi e maiuscole', () {
      final before = ClothingDetails.of(_maglione());
      final same = before.copyWith(color: '  blu ');
      expect(same.changedFields(before), isEmpty);
      final diff = before.copyWith(color: 'Nero');
      expect(diff.changedFields(before), ['baseColor']);
    });

    test(
      'uses come insiemi: stesso contenuto, altro ordine, nessuna modifica',
      () {
        final before = ClothingDetails.of(_maglione());
        final after = before.copyWith(uses: {'Hiking', 'Everyday'});
        expect(after.changedFields(before), isEmpty);
      },
    );

    test('null contro null non è una modifica del colore', () {
      final before = ClothingDetails.of(_maglione()).copyWith(clearColor: true);
      final after = before.copyWith(clearColor: true);
      expect(after.changedFields(before), isEmpty);
    });
  });

  group('equality', () {
    test('valori uguali sono uguali con stesso hashCode', () {
      final a = ClothingDetails.of(_maglione());
      final b = ClothingDetails.of(_maglione());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(warmth: 1)));
    });
  });

  group('clothingFromMetadata', () {
    String metadata(Map<String, dynamic> m) => jsonEncode(m);

    test('null o vuoto: null', () {
      expect(clothingFromMetadata(null), isNull);
      expect(clothingFromMetadata(''), isNull);
    });

    test('JSON non leggibile o non mappa: null', () {
      expect(clothingFromMetadata('{non json'), isNull);
      expect(clothingFromMetadata('[1,2]'), isNull);
      expect(clothingFromMetadata('"stringa"'), isNull);
    });

    test('Not Clothing: null', () {
      expect(
        clothingFromMetadata(metadata({'category': 'Not Clothing'})),
        isNull,
      );
    });

    test('un capo: ClothingAnalysisResult con extras', () {
      final r = clothingFromMetadata(
        metadata({
          'name': 'Maglione',
          'category': 'Upper Body',
          'subCategory': 'Sweater',
          'baseColor': 'Blu',
          'warmth': 4,
          'waterResistance': 1,
          'bulk': 3,
        }),
      );
      expect(r, isNotNull);
      expect(r!.subCategory, 'Sweater');
      expect(r.waterResistance, 1);
      expect(r.extras['bulk'], 3);
    });
  });
}
