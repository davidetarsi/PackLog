import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';

AiReason _reason() =>
    const AiReason(code: 'meteo', label: 'Meteo', sentence: 'Fa freddo.');

void main() {
  group('attività e alloggi come id del catalogo', () {
    test('AiStopAnswers tiene gli id così come sono', () {
      const answers = AiStopAnswers(
        activities: ['diving', 'sea'],
        stay: 'hotel',
      );
      expect(answers.activities, ['diving', 'sea']);
      expect(answers.stay, 'hotel');
    });
  });

  group('AiStopAnswers', () {
    test('nessuna risposta è intatta', () {
      expect(const AiStopAnswers().isUntouched, isTrue);
      expect(const AiStopAnswers().isIncomplete, isTrue);
    });

    test('la sola lavatrice accesa non è intatta', () {
      expect(const AiStopAnswers(washer: true).isUntouched, isFalse);
    });

    test('attività senza alloggio è incompleta', () {
      const answers = AiStopAnswers(activities: ['sea']);
      expect(answers.isUntouched, isFalse);
      expect(answers.isIncomplete, isTrue);
    });

    test('attività e alloggio: completa', () {
      const answers = AiStopAnswers(activities: ['sea'], stay: 'hotel');
      expect(answers.isIncomplete, isFalse);
    });
  });

  group('JSON', () {
    test('AiPackingSetup va e torna con due tappe', () {
      const setup = AiPackingSetup(
        houseId: 'casa-1',
        luggageId: 'bag-1',
        stops: {
          'stop-a': AiStopAnswers(
            activities: ['city', 'diving'],
            stay: 'apartment',
            washer: true,
          ),
          'stop-b': AiStopAnswers(activities: ['ski']),
        },
      );

      final json = setup.toJson();
      expect(AiPackingSetup.fromJson(json), setup);
      expect((json['stops'] as Map)['stop-a']['activities'], [
        'city',
        'diving',
      ]);
    });

    test('attività e alloggio sconosciuti al catalogo si conservano', () {
      final answers = AiStopAnswers.fromJson({
        'activities': ['city', 'paracadute'],
        'stay': 'yurta',
        'washer': false,
      });
      expect(answers.activities, ['city', 'paracadute']);
      expect(answers.stay, 'yurta');
    });

    test('un viaggio salvato con la forma vecchia si legge com\'era', () {
      final answers = AiStopAnswers.fromJson({
        'activities': ['formal_dinner', 'cycling'],
        'stay': 'friends',
      });
      expect(answers.activities, ['formal_dinner', 'cycling']);
      expect(answers.stay, 'friends');
    });

    test('avviso con livello sconosciuto non compare nei warnings', () {
      final result = AiPackingResult.fromJson(
        _resultJson(
          warnings: [
            _warningJson(id: 'w1', level: 'critico'),
            _warningJson(id: 'w2', level: 'utile'),
          ],
        ),
      );
      expect(result.warnings.map((w) => w.id), ['w2']);
      expect(result.warnings.single.level, AiWarningLevel.useful);
    });

    test('AiPackingResult va e torna', () {
      final result = AiPackingResult(
        generatedAt: DateTime(2026, 10, 24, 10, 30),
        houseId: 'casa-1',
        proposal: [
          AiPackedItem(
            itemId: 'item-1',
            quantity: 2,
            inDeparture: true,
            reason: _reason(),
          ),
        ],
        warnings: [
          const AiWarning(
            id: 'w1',
            code: 'adattatore',
            level: AiWarningLevel.important,
            title: 'Adattatore',
            why: 'Prese diverse.',
            search: 'adattatore universale',
          ),
        ],
        reasons: const [
          AiReasonPoint(
            code: 'meteo',
            title: 'Meteo',
            sentences: ['Fa freddo.'],
            items: ['item-1'],
          ),
        ],
        dismissedWarnings: const ['w1'],
      );

      final decoded = AiPackingResult.fromJson(result.toJson());
      expect(decoded, result);
      expect(decoded.openWarnings, isEmpty);
    });

    test('openWarnings esclude gli avvisi chiusi', () {
      final result = AiPackingResult.fromJson(
        _resultJson(
          warnings: [
            _warningJson(id: 'w1', level: 'importante'),
            _warningJson(id: 'w2', level: 'utile'),
          ],
          dismissedWarnings: ['w1'],
        ),
      );
      expect(result.openWarnings.map((w) => w.id), ['w2']);
    });
  });

  group('posti', () {
    AiSlot slot(
      String id,
      String type, {
      AiSlotLevel level = AiSlotLevel.useful,
      int copies = 1,
      int? remaining,
      bool toBuy = false,
      bool checked = false,
      bool removed = false,
    }) => AiSlot(
      id: id,
      type: type,
      category: ItemCategory.vestiti,
      level: level,
      name: type,
      copies: copies,
      remaining: remaining ?? copies,
      addLabel: 'Aggiungi $type',
      toBuy: toBuy,
      checked: checked,
      removed: removed,
    );

    AiPackingResult result(List<AiSlot>? slots) => AiPackingResult(
      generatedAt: DateTime(2026, 11, 1, 9),
      houseId: 'casa-1',
      slots: slots,
    );

    test('isOpen vale finché resta almeno una copia', () {
      expect(slot('a', 'Scarf', copies: 2, remaining: 1).isOpen, isTrue);
      expect(slot('a', 'Scarf', copies: 2, remaining: 0).isOpen, isFalse);
    });

    test('un posto tolto non è aperto', () {
      expect(slot('a', 'Scarf', removed: true).isOpen, isFalse);
      expect(slot('a', 'Scarf', removed: true).inSuitcase, isFalse);
    });

    test('inSuitcase: una proposta da comprare no, un importante sì', () {
      expect(slot('a', 'Scarf', toBuy: true).inSuitcase, isFalse);
      expect(slot('a', 'Scarf').inSuitcase, isTrue);
      expect(
        slot(
          'a',
          'Scarf',
          level: AiSlotLevel.important,
          toBuy: true,
        ).inSuitcase,
        isTrue,
      );
    });

    test('senza posti: slots null, hasSlots falso, notes vuote', () {
      final r = result(null);
      expect(r.slots, isNull);
      expect(r.hasSlots, isFalse);
      expect(r.notes, isEmpty);
      expect(result(const []).hasSlots, isTrue);
    });

    test('toJson/fromJson di andata e ritorno con toBuy, checked e note', () {
      final r =
          result([
            slot('a', 'Scarf', level: AiSlotLevel.important, toBuy: true),
            slot('b', 'T-shirt', copies: 3, remaining: 2, checked: true),
          ]).copyWith(
            notes: const [AiTripNote(code: 'lavanderia', title: 'T', why: 'W')],
          );

      final json = r.toJson();
      final back = AiPackingResult.fromJson(json);

      expect(back, r);
      expect(back.slots![0].toBuy, isTrue);
      expect(back.slots![1].checked, isTrue);
      expect(back.slots![1].remaining, 2);
      expect(back.slots![0].level, AiSlotLevel.important);
      expect((json['slots'] as List).first['level'], 'importante');
    });

    test('JSON salvato senza slots (vecchio viaggio): slots null', () {
      final json = result(null).toJson()
        ..remove('slots')
        ..remove('notes');
      final back = AiPackingResult.fromJson(json);
      expect(back.slots, isNull);
      expect(back.notes, isEmpty);
    });

    test('withSlot cambia solo il posto indicato', () {
      final r = result([slot('a', 'Scarf'), slot('b', 'Hat')]);
      final next = r.withSlot('b', (s) => s.copyWith(remaining: 0));
      expect(next.slots![0], r.slots![0]);
      expect(next.slots![1].remaining, 0);
      expect(r.withSlot('zzz', (s) => s.copyWith(remaining: 0)), r);
    });

    test('withSlot su un risultato senza posti lo lascia com\'è', () {
      final r = result(null);
      expect(r.withSlot('a', (s) => s), r);
    });
  });

  group('carryToBuy', () {
    AiSlot slot(
      String id,
      String type, {
      int remaining = 1,
      bool toBuy = false,
    }) => AiSlot(
      id: id,
      type: type,
      category: ItemCategory.vestiti,
      level: AiSlotLevel.important,
      name: type,
      copies: 1,
      remaining: remaining,
      addLabel: 'x',
      toBuy: toBuy,
    );

    AiPackingResult result(List<AiSlot>? slots) => AiPackingResult(
      generatedAt: DateTime(2026, 11, 1, 9),
      houseId: 'casa-1',
      slots: slots,
    );

    test('Scarf toBuy prima e presente dopo: resta toBuy', () {
      final out = carryToBuy(
        result([slot('p1', 'Scarf', toBuy: true)]),
        result([slot('n1', 'Scarf'), slot('n2', 'Hat')]),
      );
      expect(out.slots![0].toBuy, isTrue);
      expect(out.slots![1].toBuy, isFalse);
    });

    test('Scarf non c\'è più: niente', () {
      final out = carryToBuy(
        result([slot('p1', 'Scarf', toBuy: true)]),
        result([slot('n1', 'Hat')]),
      );
      expect(out.slots!.single.toBuy, isFalse);
    });

    test('posto chiuso prima: niente', () {
      final out = carryToBuy(
        result([slot('p1', 'Scarf', remaining: 0, toBuy: true)]),
        result([slot('n1', 'Scarf')]),
      );
      expect(out.slots!.single.toBuy, isFalse);
    });

    test('più nuovi posti dello stesso tipo: solo il primo eredita', () {
      final out = carryToBuy(
        result([slot('p1', 'Scarf', toBuy: true)]),
        result([slot('n1', 'Scarf'), slot('n2', 'Scarf')]),
      );
      expect(out.slots!.map((s) => s.toBuy), [true, false]);
    });

    test('un posto nuovo chiuso non eredita', () {
      final out = carryToBuy(
        result([slot('p1', 'Scarf', toBuy: true)]),
        result([slot('n1', 'Scarf', remaining: 0), slot('n2', 'Scarf')]),
      );
      expect(out.slots!.map((s) => s.toBuy), [false, true]);
    });

    test('previous null o senza posti: next invariato', () {
      final next = result([slot('n1', 'Scarf')]);
      expect(carryToBuy(null, next), next);
      expect(carryToBuy(result(null), next), next);
    });

    test('next senza posti: invariato', () {
      final next = result(null);
      expect(carryToBuy(result([slot('p', 'Scarf', toBuy: true)]), next), next);
    });
  });
}

Map<String, dynamic> _resultJson({
  List<Map<String, dynamic>> warnings = const [],
  List<String> dismissedWarnings = const [],
}) => {
  'generatedAt': DateTime(2026, 10, 24, 10, 30).toIso8601String(),
  'houseId': 'casa-1',
  'proposal': <Map<String, dynamic>>[],
  'warnings': warnings,
  'reasons': <Map<String, dynamic>>[],
  'dismissedWarnings': dismissedWarnings,
};

Map<String, dynamic> _warningJson({
  required String id,
  required String level,
}) => {
  'id': id,
  'code': 'code-$id',
  'level': level,
  'title': 'Titolo',
  'why': 'Perché',
};
