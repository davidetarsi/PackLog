import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/clothing_details.dart';
import 'package:pack_log/features/items/model/item_metadata_merge.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _json(String raw) =>
    Map<String, dynamic>.from(jsonDecode(raw) as Map);

/// Un capo completo, come lo salva la scansione.
Map<String, dynamic> _scheda() => {
  'name': 'Maglione',
  'category': 'Upper Body',
  'subCategory': 'Sweater',
  'baseColor': 'Blu',
  'pattern': 'Solid',
  'coverage': 'Long-sleeve',
  'fit': 'Regular',
  'warmth': 4,
  'formality': 'Casual',
  'activityTags': ['Everyday'],
  'waterResistance': 1,
  'bulk': 3,
};

void main() {
  group('withUserDetails', () {
    test('senza metadati: scrive solo il campo toccato, con aiPending', () {
      final json = _json(
        withUserDetails(
          current: null,
          details: ClothingDetails.empty.copyWith(warmth: 4),
          touched: {ClothingField.warmth},
        ),
      );
      expect(json, {
        'warmth': 4,
        'userFields': ['warmth'],
        'aiPending': true,
      });
    });

    test('tipo toccato: scrive anche la categoria', () {
      final json = _json(
        withUserDetails(
          current: null,
          details: ClothingDetails.empty.copyWith(subCategory: 'Sweater'),
          touched: {ClothingField.type},
        ),
      );
      expect(json['subCategory'], 'Sweater');
      expect(json['category'], 'Upper Body');
      expect(json['userFields'], ['subCategory']);
      expect(json['aiPending'], true);
    });

    test('tipo senza categoria nota (Other): la categoria non si scrive', () {
      final json = _json(
        withUserDetails(
          current: null,
          details: ClothingDetails.empty.copyWith(subCategory: 'Other'),
          touched: {ClothingField.type},
        ),
      );
      expect(json['subCategory'], 'Other');
      expect(json.containsKey('category'), isFalse);
    });

    test('colore toccato e svuotato: scrive N/A', () {
      final json = _json(
        withUserDetails(
          current: null,
          details: ClothingDetails.empty,
          touched: {ClothingField.color},
        ),
      );
      expect(json['baseColor'], 'N/A');
      expect(json['userFields'], ['baseColor']);
    });

    test('campo toccato senza valore: viene tolto dalla mappa', () {
      final json = _json(
        withUserDetails(
          current: jsonEncode({'warmth': 4, 'formality': 'Casual'}),
          details: ClothingDetails.empty.copyWith(formality: 'Casual'),
          touched: {ClothingField.warmth},
        ),
      );
      expect(json.containsKey('warmth'), isFalse);
      expect(json['formality'], 'Casual');
      expect(json['userFields'], ['warmth']);
      expect(json.containsKey('aiPending'), isFalse);
    });

    test('su metadati completi cambia solo i campi toccati', () {
      final details = ClothingDetails.fromMetadata(
        _scheda(),
      ).copyWith(uses: {'Hiking'});
      final json = _json(
        withUserDetails(
          current: jsonEncode(_scheda()),
          details: details,
          touched: {ClothingField.uses},
        ),
      );
      expect(json, {
        ..._scheda(),
        'activityTags': ['Hiking'],
        'userFields': ['activityTags'],
      });
      expect(json.containsKey('aiPending'), isFalse);
    });

    test(
      'userFields senza doppioni e conserva aiPending di un current leggibile',
      () {
        final json = _json(
          withUserDetails(
            current: jsonEncode({
              'warmth': 4,
              'userFields': ['warmth'],
              'aiPending': true,
            }),
            details: ClothingDetails.empty.copyWith(warmth: 2),
            touched: {ClothingField.warmth},
          ),
        );
        expect(json['warmth'], 2);
        expect(json['userFields'], ['warmth']);
        expect(json['aiPending'], true);
      },
    );
  });

  group('withUserCategory', () {
    test('senza metadati: solo la categoria scelta, con aiPending', () {
      expect(_json(withUserCategory(null)), {
        'userFields': ['appCategory'],
        'aiPending': true,
      });
    });

    test('su una scheda completa: aggiunge la scelta e tiene il resto', () {
      final out = _json(
        withUserCategory(
          jsonEncode({
            ..._scheda(),
            'userFields': ['warmth'],
          }),
        ),
      );
      expect(out['userFields'], ['warmth', 'appCategory']);
      expect(out['warmth'], 4);
      expect(out.containsKey('aiPending'), isFalse);
    });

    test('la scelta resta dopo la risposta dell\'AI', () {
      final merged = _json(
        mergeAiMetadata(current: withUserCategory(null), ai: _scheda()),
      );
      expect(merged['userFields'], ['appCategory']);
      expect(merged.containsKey('aiPending'), isFalse);
      expect(merged['warmth'], 4);
    });
  });

  group('mergeAiMetadata', () {
    test('senza current: il risultato dell\'AI, identico', () {
      final ai = _scheda();
      expect(mergeAiMetadata(current: null, ai: ai), jsonEncode(ai));
    });

    test('con current non leggibile vince l\'AI', () {
      final ai = _scheda();
      expect(mergeAiMetadata(current: '{non json', ai: ai), jsonEncode(ai));
    });

    test('un campo dell\'utente resta, gli altri si riempiono', () {
      final json = _json(
        mergeAiMetadata(
          current: jsonEncode({
            'warmth': 4,
            'userFields': ['warmth'],
            'aiPending': true,
          }),
          ai: {
            'warmth': 2,
            'formality': 'Casual',
            'subCategory': 'Hoodie',
            'category': 'Upper Body',
            'bulk': 2,
          },
        ),
      );
      expect(json, {
        'warmth': 4,
        'formality': 'Casual',
        'subCategory': 'Hoodie',
        'category': 'Upper Body',
        'bulk': 2,
        'userFields': ['warmth'],
      });
    });

    test('tipo scelto dall\'utente: restano tipo e categoria del current', () {
      final json = _json(
        mergeAiMetadata(
          current: jsonEncode({
            'subCategory': 'Sweater',
            'category': 'Upper Body',
            'userFields': ['subCategory'],
          }),
          ai: {'subCategory': 'Coat', 'category': 'Outerwear'},
        ),
      );
      expect(json['subCategory'], 'Sweater');
      expect(json['category'], 'Upper Body');
    });

    test('colore svuotato dall\'utente resta N/A', () {
      final json = _json(
        mergeAiMetadata(
          current: jsonEncode({
            'baseColor': 'N/A',
            'userFields': ['baseColor'],
          }),
          ai: {'baseColor': 'Nero'},
        ),
      );
      expect(json['baseColor'], 'N/A');
    });

    test('campo tolto dall\'utente resta tolto', () {
      final json = _json(
        mergeAiMetadata(
          current: jsonEncode({
            'formality': 'Casual',
            'userFields': ['warmth'],
            'aiPending': true,
          }),
          ai: {'warmth': 2, 'formality': 'Business'},
        ),
      );
      expect(json.containsKey('warmth'), isFalse);
      expect(json['formality'], 'Business');
      expect(json['userFields'], ['warmth']);
    });

    test('chiavi del current che l\'AI non ha restano, aiPending sparisce', () {
      final json = _json(
        mergeAiMetadata(
          current: jsonEncode({'notes': 'x', 'aiPending': true}),
          ai: {'warmth': 2},
        ),
      );
      expect(json, {'warmth': 2, 'notes': 'x'});
    });

    test('userFields senza doppioni, nell\'ordine di inserimento', () {
      final json = _json(
        mergeAiMetadata(
          current: jsonEncode({
            'warmth': 4,
            'formality': 'Casual',
            'userFields': ['formality', 'warmth', 'formality'],
            'aiPending': true,
          }),
          ai: {'warmth': 2, 'formality': 'Business'},
        ),
      );
      expect(json['userFields'], ['formality', 'warmth']);
    });
  });

  group('needsAiMetadata', () {
    test('mancano, vuoti o non leggibili: serve l\'AI', () {
      expect(needsAiMetadata(null), isTrue);
      expect(needsAiMetadata(''), isTrue);
      expect(needsAiMetadata('{non json'), isTrue);
    });

    test('aiPending: serve l\'AI', () {
      expect(
        needsAiMetadata(jsonEncode({'warmth': 4, 'aiPending': true})),
        isTrue,
      );
    });

    test('metadati completi: non serve', () {
      expect(needsAiMetadata(jsonEncode(_scheda())), isFalse);
    });
  });

  group('userFieldsOf', () {
    test('null o non leggibile: vuoto', () {
      expect(userFieldsOf(null), isEmpty);
      expect(userFieldsOf('{non json'), isEmpty);
    });

    test('senza userFields: vuoto', () {
      expect(userFieldsOf(jsonEncode({'warmth': 4})), isEmpty);
    });

    test('ignora i valori che non sono stringhe', () {
      expect(
        userFieldsOf(
          jsonEncode({
            'userFields': ['warmth', 3, 'formality', null],
          }),
        ),
        {'warmth', 'formality'},
      );
    });
  });
}
