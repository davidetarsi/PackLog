import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _fullJson() => {
  'name': 'Jeans slim',
  'category': 'Lower Body',
  'subCategory': 'Jeans',
  'baseColor': 'Blu navy',
  'pattern': 'Solid',
  'coverage': 'Full-length',
  'fit': 'Skinny',
  'warmth': 3,
  'formality': 'Smart Casual',
  'activityTags': ['Everyday', 'Office'],
};

ClothingAnalysisResult _fullResult() => ClothingAnalysisResult(
  name: 'Jeans slim',
  category: 'Lower Body',
  subCategory: 'Jeans',
  baseColor: 'Blu navy',
  pattern: 'Solid',
  coverage: 'Full-length',
  fit: 'Skinny',
  warmth: 3,
  formality: 'Smart Casual',
  activityTags: const ['Everyday', 'Office'],
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── fromJson ────────────────────────────────────────────────────────────────

  group('fromJson()', () {
    test('parses all fields correctly from a complete map', () {
      final r = ClothingAnalysisResult.fromJson(_fullJson());
      expect(r.name, 'Jeans slim');
      expect(r.category, 'Lower Body');
      expect(r.subCategory, 'Jeans');
      expect(r.baseColor, 'Blu navy');
      expect(r.pattern, 'Solid');
      expect(r.coverage, 'Full-length');
      expect(r.fit, 'Skinny');
      expect(r.warmth, 3);
      expect(r.formality, 'Smart Casual');
      expect(r.activityTags, ['Everyday', 'Office']);
    });

    test('applies defaults for missing or null keys', () {
      final r = ClothingAnalysisResult.fromJson({});
      expect(r.name, 'Sconosciuto');
      expect(r.category, '');
      expect(r.subCategory, '');
      expect(r.baseColor, '');
      expect(r.pattern, '');
      expect(r.coverage, '');
      expect(r.fit, 'N/A');
      expect(r.warmth, 3);
      expect(r.formality, 'Casual');
      expect(r.activityTags, isEmpty);
    });

    test('activityTags filters out non-String entries', () {
      final r = ClothingAnalysisResult.fromJson({
        ...(_fullJson()),
        'activityTags': ['Everyday', 42, null, 'Beach'],
      });
      expect(r.activityTags, ['Everyday', 'Beach']);
    });
  });

  // ── toJson ───────────────────────────────────────────────────────────────────

  group('toJson()', () {
    test('serialises all fields', () {
      final json = _fullResult().toJson();
      expect(json['name'], 'Jeans slim');
      expect(json['category'], 'Lower Body');
      expect(json['subCategory'], 'Jeans');
      expect(json['baseColor'], 'Blu navy');
      expect(json['pattern'], 'Solid');
      expect(json['coverage'], 'Full-length');
      expect(json['fit'], 'Skinny');
      expect(json['warmth'], 3);
      expect(json['formality'], 'Smart Casual');
      expect(json['activityTags'], ['Everyday', 'Office']);
    });

    test('fromJson→toJson round-trip preserves all data', () {
      final original = _fullResult();
      final restored = ClothingAnalysisResult.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  // ── Equality and hashCode ─────────────────────────────────────────────────────

  group('== and hashCode', () {
    test('two instances with identical values are equal', () {
      expect(_fullResult(), _fullResult());
    });

    test('same instance is equal to itself', () {
      final r = _fullResult();
      expect(r, r);
    });

    test('different name → not equal', () {
      final a = _fullResult();
      final b = a.copyWith(name: 'Altro');
      expect(a, isNot(b));
    });

    test('different warmth → not equal', () {
      final a = _fullResult();
      final b = a.copyWith(warmth: 5);
      expect(a, isNot(b));
    });

    test('different activityTags → not equal', () {
      final a = _fullResult();
      final b = a.copyWith(activityTags: const ['Beach']);
      expect(a, isNot(b));
    });

    test('different subCategory → not equal', () {
      final a = _fullResult();
      final b = a.copyWith(subCategory: 'Trousers');
      expect(a, isNot(b));
    });

    test('equal values produce the same hashCode', () {
      expect(_fullResult().hashCode, _fullResult().hashCode);
    });
  });

  // ── copyWith ──────────────────────────────────────────────────────────────────

  group('copyWith()', () {
    test('changes only the specified field', () {
      final original = _fullResult();
      final copy = original.copyWith(name: 'Nuova Camicia');
      expect(copy.name, 'Nuova Camicia');
      expect(copy.category, original.category);
      expect(copy.subCategory, original.subCategory);
      expect(copy.baseColor, original.baseColor);
      expect(copy.activityTags, original.activityTags);
    });

    test('copyWith(subCategory:) changes only subCategory', () {
      final original = _fullResult();
      final copy = original.copyWith(subCategory: 'Trousers');
      expect(copy.subCategory, 'Trousers');
      expect(copy.name, original.name);
      expect(copy.category, original.category);
    });

    test('original is unaffected after copyWith', () {
      final original = _fullResult();
      original.copyWith(name: 'X');
      expect(original.name, 'Jeans slim');
    });
  });

  // ── calculatedVersatility ─────────────────────────────────────────────────────

  group('calculatedVersatility', () {
    // baseline: 3 + 1 (Casual) + 1 (Nero) = 5
    test('returns 5 for ideal versatile item', () {
      const r = ClothingAnalysisResult(
        name: 'T-Shirt',
        category: 'Upper Body',
        baseColor: 'Nero',
        pattern: 'Solid',
        coverage: 'Short-sleeve',
        fit: 'Regular',
        warmth: 3,
        formality: 'Casual',
        activityTags: ['Everyday'],
      );
      expect(r.calculatedVersatility, 5);
    });

    // 3 - 1 (Shoes) - 1 (warmth 5) - 1 (Oversize) - 1 (Formal) - 1 (Graphic) = -2 → 1
    test('clamps to minimum 1 for highly specific item', () {
      const r = ClothingAnalysisResult(
        name: 'Stivali',
        category: 'Shoes',
        baseColor: 'Rosso',
        pattern: 'Graphic',
        coverage: 'Full-length',
        fit: 'Oversize',
        warmth: 5,
        formality: 'Formal',
        activityTags: [],
      );
      expect(r.calculatedVersatility, 1);
    });

    // 3 - 1 (Accessory)
    test('Accessory category reduces score by 1', () {
      const r = ClothingAnalysisResult(
        name: 'Cintura',
        category: 'Accessory',
        baseColor: 'Grigio',
        pattern: 'Solid',
        coverage: 'N/A',
        fit: 'N/A',
        warmth: 3,
        formality: 'Casual',
        activityTags: [],
      );
      // 3 - 1 (Accessory) + 1 (Casual) + 1 (Grigio) = 4
      expect(r.calculatedVersatility, 4);
    });

    // warmth <= 1 penalty
    test('warmth of 1 reduces score by 1', () {
      const r = ClothingAnalysisResult(
        name: 'Canottiera',
        category: 'Upper Body',
        baseColor: 'Nero',
        pattern: 'Solid',
        coverage: 'Sleeveless',
        fit: 'Regular',
        warmth: 1,
        formality: 'Casual',
        activityTags: [],
      );
      // 3 - 1 (warmth 1) + 1 (Casual) + 1 (Nero) = 4
      expect(r.calculatedVersatility, 4);
    });

    // Smart Casual gives +1 same as Casual
    test('Smart Casual formality adds 1 to score', () {
      const r = ClothingAnalysisResult(
        name: 'Chino',
        category: 'Lower Body',
        baseColor: 'Verde',
        pattern: 'Solid',
        coverage: 'Full-length',
        fit: 'Regular',
        warmth: 3,
        formality: 'Smart Casual',
        activityTags: [],
      );
      // 3 + 1 (Smart Casual) = 4
      expect(r.calculatedVersatility, 4);
    });

    // Loungewear gives -1
    test('Loungewear formality reduces score by 1', () {
      const r = ClothingAnalysisResult(
        name: 'Pigiama',
        category: 'Lower Body',
        baseColor: 'Verde',
        pattern: 'Striped',
        coverage: 'Full-length',
        fit: 'Regular',
        warmth: 3,
        formality: 'Loungewear',
        activityTags: [],
      );
      // 3 - 1 (Loungewear) - 1 (Striped) = 1
      expect(r.calculatedVersatility, 1);
    });

    // All four neutral colours add 1
    test('neutral baseColor (Bianco, Grigio, Blu navy) each add 1', () {
      for (final color in ['Bianco', 'Grigio', 'Blu navy']) {
        final r = ClothingAnalysisResult(
          name: 'Test',
          category: 'Upper Body',
          baseColor: color,
          pattern: 'Solid',
          coverage: 'Short-sleeve',
          fit: 'Regular',
          warmth: 3,
          formality: 'Casual',
          activityTags: const [],
        );
        // 3 + 1 (Casual) + 1 (neutral) = 5
        expect(r.calculatedVersatility, 5, reason: 'color: $color');
      }
    });

    // non-Solid pattern reduces score
    test('non-Solid pattern reduces score by 1', () {
      const r = ClothingAnalysisResult(
        name: 'Camicia',
        category: 'Upper Body',
        baseColor: 'Verde',
        pattern: 'Plaid',
        coverage: 'Long-sleeve',
        fit: 'Regular',
        warmth: 3,
        formality: 'Casual',
        activityTags: [],
      );
      // 3 + 1 (Casual) - 1 (Plaid) = 3
      expect(r.calculatedVersatility, 3);
    });
  });
}
