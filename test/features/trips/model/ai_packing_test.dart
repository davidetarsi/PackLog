import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';

AiReason _reason() =>
    const AiReason(code: 'meteo', label: 'Meteo', sentence: 'Fa freddo.');

void main() {
  group('AiActivity', () {
    test('ha sedici attività nell\'ordine delle pillole', () {
      expect(AiActivity.values.length, 16);
      expect(AiActivity.values.first, AiActivity.city);
      expect(AiActivity.values.last, AiActivity.spa);
    });

    test('id stabili salvati nel viaggio', () {
      expect(AiActivity.city.id, 'city');
      expect(AiActivity.highMountain.id, 'high_mountain');
      expect(AiActivity.formalDinner.id, 'formal_dinner');
      expect(AiActivity.worship.id, 'worship');
    });

    test('diving manda immersioni e mare', () {
      expect(AiActivity.diving.generatorCodes, ['immersioni', 'mare']);
    });

    test('codici del generatore secondo la tabella della spec', () {
      expect(AiActivity.city.generatorCodes, ['visite in citta']);
      expect(AiActivity.walks.generatorCodes, ['escursioni leggere']);
      expect(AiActivity.trekking.generatorCodes, ['trekking']);
      expect(AiActivity.cammino.generatorCodes, ['cammino']);
      expect(AiActivity.highMountain.generatorCodes, ['escursioni in quota']);
      expect(AiActivity.sea.generatorCodes, ['mare']);
      expect(AiActivity.ski.generatorCodes, ['sci']);
      expect(AiActivity.camping.generatorCodes, ['campeggio']);
      expect(AiActivity.work.generatorCodes, ['riunioni di lavoro']);
      expect(AiActivity.formalDinner.generatorCodes, ['cena formale']);
      expect(AiActivity.wedding.generatorCodes, ['matrimonio']);
      expect(AiActivity.worship.generatorCodes, ['visite a siti religiosi']);
      expect(AiActivity.nightlife.generatorCodes, ['vita notturna']);
      expect(AiActivity.cycling.generatorCodes, ['bicicletta']);
      expect(AiActivity.spa.generatorCodes, ['terme']);
    });

    test('chiave di etichetta', () {
      expect(
        AiActivity.highMountain.labelKey,
        'trips.ai.activity.high_mountain',
      );
    });
  });

  group('AiStay', () {
    test('id, testo per il generatore e chiave di etichetta', () {
      expect(AiStay.hotel.id, 'hotel');
      expect(AiStay.hotel.generatorText, 'hotel');
      expect(AiStay.apartment.generatorText, 'appartamento');
      expect(AiStay.hostel.generatorText, 'ostello');
      expect(AiStay.camping.generatorText, 'campeggio');
      expect(AiStay.friends.generatorText, 'da amici o parenti');
      expect(AiStay.friends.labelKey, 'trips.ai.stay.friends');
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
      const answers = AiStopAnswers(activities: [AiActivity.sea]);
      expect(answers.isUntouched, isFalse);
      expect(answers.isIncomplete, isTrue);
    });

    test('attività e alloggio: completa', () {
      const answers = AiStopAnswers(
        activities: [AiActivity.sea],
        stay: AiStay.hotel,
      );
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
            activities: [AiActivity.city, AiActivity.diving],
            stay: AiStay.apartment,
            washer: true,
          ),
          'stop-b': AiStopAnswers(activities: [AiActivity.ski]),
        },
      );

      final json = setup.toJson();
      expect(AiPackingSetup.fromJson(json), setup);
      expect((json['stops'] as Map)['stop-a']['activities'], [
        'city',
        'diving',
      ]);
    });

    test('attività sconosciute si scartano', () {
      final answers = AiStopAnswers.fromJson({
        'activities': ['city', 'paracadute'],
        'stay': 'hotel',
        'washer': false,
      });
      expect(answers.activities, [AiActivity.city]);
    });

    test('alloggio sconosciuto diventa null', () {
      final answers = AiStopAnswers.fromJson({
        'activities': <String>[],
        'stay': 'yurta',
      });
      expect(answers.stay, isNull);
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
