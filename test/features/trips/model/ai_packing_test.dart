import 'package:flutter_test/flutter_test.dart';
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
