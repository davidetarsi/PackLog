import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/services/pack_trip_service.dart';
import 'package:pack_log/features/trips/services/suitcase_analytics.dart';

TripModel _trip() => TripModel(
  id: 't1',
  name: 'Lisbona',
  transports: const ['plane'],
  aiSetup: const AiPackingSetup(
    houseId: 'h1',
    luggageId: 'l1',
    stops: {
      'a': AiStopAnswers(
        activities: ['hiking', 'beach'],
        stay: 'apartment',
        washer: false,
      ),
      'b': AiStopAnswers(activities: ['beach'], washer: true),
    },
  ),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

StopWeather _stop({double? tempMin, double? tempMax, double? rainDays}) =>
    StopWeather(
      name: 'tappa',
      from: DateTime(2026, 11, 10),
      to: DateTime(2026, 11, 12),
      source: WeatherSource.forecast,
      tempMin: tempMin,
      tempMax: tempMax,
      rainDays: rainDays,
    );

const _reason = AiReason(code: 'base', label: 'Base', sentence: 'Serve.');

TripItem _packed(String id, int quantity) => TripItem(
  id: id,
  name: 'capo $id',
  category: ItemCategory.vestiti,
  quantity: quantity,
);

/// Proposta A×2, B×1, C (dal kit); valigia A×3, C×1, D×1; un posto con una
/// copia riempita su due.
TripModel _suitcase({AiPackingResult? result}) => _trip().copyWith(
  items: [_packed('A', 3), _packed('C', 1), _packed('D', 1)],
  aiResult:
      result ??
      AiPackingResult(
        generatedAt: DateTime(2026, 11, 8),
        houseId: 'h1',
        proposal: const [
          AiPackedItem(itemId: 'A', quantity: 2, reason: _reason),
          AiPackedItem(itemId: 'B', quantity: 1, reason: _reason),
        ],
        kitAdded: const [AiKitAdded(kitId: 'k1', itemId: 'C')],
        slots: const [
          AiSlot(
            id: 's1',
            type: 'calze',
            category: ItemCategory.vestiti,
            level: AiSlotLevel.useful,
            name: 'Calze',
            copies: 2,
            remaining: 1,
            addLabel: 'Aggiungi',
          ),
          AiSlot(
            id: 's2',
            type: 'ombrello',
            category: ItemCategory.varie,
            level: AiSlotLevel.useful,
            name: 'Ombrello',
            copies: 1,
            remaining: 0,
            addLabel: 'Aggiungi',
            removed: true,
          ),
        ],
      ),
);

void main() {
  group('suitcaseDiff', () {
    const types = {'A': 'T-Shirt', 'B': 'Sweater', 'D': 'Shorts'};

    test('quanto la valigia si allontana dalla proposta', () {
      final diff = suitcaseDiff(_suitcase(), types)!;
      expect(diff.proposed, 3);
      expect(diff.kept, 2);
      expect(diff.removed, 1);
      expect(diff.added, 1);
      expect(diff.slotCopiesFilled, 1);
      expect(diff.quantityChanged, 1);
      expect(diff.removedTypes, ['Sweater']);
      expect(diff.addedTypes, ['Shorts']);
      expect(diff.quantityUpTypes, ['T-Shirt']);
      expect(diff.quantityDownTypes, isEmpty);
    });

    test(
      'la valigia salvata come la regola di adozione: nessuna differenza',
      () {
        final trip = _trip().copyWith(
          items: [_packed('A', 2), _packed('B', 1)],
          aiResult: AiPackingResult(
            generatedAt: DateTime(2026, 11, 8),
            houseId: 'h1',
            proposal: const [
              AiPackedItem(itemId: 'A', quantity: 1, reason: _reason),
              AiPackedItem(itemId: 'B', quantity: 3, reason: _reason),
              AiPackedItem(itemId: 'X', quantity: 1, reason: _reason),
            ],
            kitAdded: const [AiKitAdded(kitId: 'k1', itemId: 'A', copies: 2)],
          ),
        );
        // B in casa ha un pezzo solo; X non c'è più.
        final diff = suitcaseDiff(
          trip,
          const {},
          available: const {'A': 3, 'B': 1},
        )!;
        expect(diff.proposed, 2);
        expect(diff.quantityChanged, 0);
        expect(diff.removed, 0);
      },
    );

    test('viaggio senza proposta AI: null', () {
      expect(suitcaseDiff(_trip(), types), isNull);
    });

    test('capi della casa non ancora caricati: tipi dalla categoria', () {
      final diff = suitcaseDiff(_suitcase(), const {})!;
      expect(diff.removed, 1);
      // Un capo tolto non è più in valigia: senza armadio il tipo non c'è.
      expect(diff.removedTypes, ['unknown']);
      expect(diff.addedTypes, ['vestiti']);
    });

    test('proprietà piatte con i nomi del catalogo', () {
      final props = suitcaseDiffProperties(suitcaseDiff(_suitcase(), types)!);
      expect(props, {
        'proposed': 3,
        'kept': 2,
        'removed': 1,
        'added': 1,
        'added_from_slots': 1,
        'quantity_changed': 1,
        'removed_types': ['Sweater'],
        'added_types': ['Shorts'],
        'quantity_up_types': ['T-Shirt'],
        'quantity_down_types': <String>[],
      });
    });

    test('stesse differenze: sameSuitcaseDiff vero anche con liste nuove', () {
      expect(
        sameSuitcaseDiff(
          suitcaseDiff(_suitcase(), types)!,
          suitcaseDiff(_suitcase(), types)!,
        ),
        isTrue,
      );
    });
  });

  group('subCategoryByIdOf', () {
    ItemModel item(String id, String? metadata) => ItemModel(
      id: id,
      houseId: 'h1',
      name: 'capo',
      category: ItemCategory.vestiti,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      aiMetadata: metadata,
    );

    test('solo sottocategorie vere da ai_metadata', () {
      expect(
        subCategoryByIdOf([
          item('a', jsonEncode({'subCategory': 'Shorts'})),
          item('b', jsonEncode({'subCategory': 'N/A'})),
          item('c', jsonEncode({'subCategory': ''})),
          item('d', null),
          item('e', 'non json'),
        ]),
        {'a': 'Shorts'},
      );
    });
  });

  group('tempBand', () {
    test('soglie 5, 15, 21, 26', () {
      expect(tempBand(4.9), 'lt5');
      expect(tempBand(5), '5_15');
      expect(tempBand(20.9), '15_21');
      expect(tempBand(21), '21_26');
      expect(tempBand(26), 'gte26');
    });
  });

  group('tripContext', () {
    final weather = TripWeather(
      signature: 's',
      fetchedAt: DateTime(2026, 11, 8),
      stops: [
        _stop(tempMin: 12, tempMax: 23, rainDays: 2),
        _stop(tempMin: 8, tempMax: 19),
      ],
    );
    final luggage = LuggageModel(
      id: 'l1',
      name: 'Zaino',
      sizeType: LuggageSize.cabinBaggage,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('risposte del foglio, bagaglio, mezzi e meteo', () {
      final context = tripContext(_trip(), luggage: luggage, weather: weather);
      expect(context, {
        'activities': ['beach', 'hiking'],
        'stays': ['apartment'],
        'washer': true,
        'luggage_size': 'cabinBaggage',
        'transports': ['plane'],
        'temp_max_band': '21_26',
        'temp_min_band': '5_15',
        'rain_days': 2,
        'weather_source': 'forecast',
      });
    });

    test('senza meteo niente chiavi di clima, il resto sì', () {
      final context = tripContext(_trip());
      expect(context.keys.where((k) => k.startsWith('temp_')), isEmpty);
      expect(context.containsKey('rain_days'), isFalse);
      expect(context.containsKey('weather_source'), isFalse);
      expect(context.containsKey('luggage_size'), isFalse);
      expect(context['activities'], ['beach', 'hiking']);
    });

    test('meteo senza temperature: niente fasce', () {
      final context = tripContext(
        _trip(),
        weather: TripWeather(
          signature: 's',
          fetchedAt: DateTime(2026, 11, 8),
          stops: [_stop()],
        ),
      );
      expect(context.keys.where((k) => k.startsWith('temp_')), isEmpty);
      expect(context.containsKey('rain_days'), isFalse);
    });

    test('viaggio senza foglio: liste vuote, lavatrice falsa', () {
      final trip = _trip().copyWith(aiSetup: null);
      final context = tripContext(trip);
      expect(context['activities'], isEmpty);
      expect(context['stays'], isEmpty);
      expect(context['washer'], isFalse);
    });
  });

  group('daysToDeparture', () {
    test('giorni di calendario, null senza partenza, negativo nel passato', () {
      final now = DateTime(2026, 11, 8, 23);
      expect(daysToDeparture(DateTime(2026, 11, 18, 8), now), 10);
      expect(daysToDeparture(DateTime(2026, 11, 8, 6), now), 0);
      expect(daysToDeparture(DateTime(2026, 11, 6), now), -2);
      expect(daysToDeparture(null, now), isNull);
    });
  });

  group('packOutcomeOf', () {
    test('un esito per ogni modo di finire', () {
      expect(packOutcomeOf(null), 'ok');
      expect(packOutcomeOf(const PackTripCreditsException()), 'credits');
      expect(
        packOutcomeOf(const PackTripEmptyWardrobeException()),
        'empty_wardrobe',
      );
      expect(
        packOutcomeOf(const PackTripWardrobeTooLargeException()),
        'wardrobe_too_large',
      );
      expect(packOutcomeOf(const PackTripNetworkException('rete')), 'network');
      expect(packOutcomeOf(const PackTripException('x')), 'error');
      expect(
        packOutcomeOf(const PackTripInvalidResponseException('x')),
        'error',
      );
      expect(packOutcomeOf(StateError('x')), 'error');
    });
  });

  group('wardrobeStats', () {
    ItemModel item(String id, String? category) => ItemModel(
      id: id,
      houseId: 'h1',
      name: 'capo',
      category: ItemCategory.vestiti,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      aiMetadata: category == null ? null : jsonEncode({'category': category}),
    );

    test('capi, schede e famiglie; chiavi sempre presenti', () {
      final stats = wardrobeStats([
        item('a', 'Upper Body'),
        item('b', 'Shoes'),
        item('c', null),
      ]);
      expect(stats, {
        'wardrobe_items': 3,
        'wardrobe_with_metadata': 2,
        'wardrobe_upper': 1,
        'wardrobe_lower': 0,
        'wardrobe_full_body': 0,
        'wardrobe_outerwear': 0,
        'wardrobe_shoes': 1,
        'wardrobe_accessory': 0,
        'wardrobe_essentials': 0,
        'wardrobe_other': 1,
      });
    });
  });

  group('setupChangedFields', () {
    const before = AiPackingSetup(
      luggageId: 'l1',
      stops: {
        'a': AiStopAnswers(activities: ['beach', 'hiking'], stay: 'hotel'),
      },
    );

    test('solo la lavatrice cambiata, attività in altro ordine', () {
      const after = AiPackingSetup(
        luggageId: 'l1',
        stops: {
          'a': AiStopAnswers(
            activities: ['hiking', 'beach'],
            stay: 'hotel',
            washer: true,
          ),
        },
      );
      expect(setupChangedFields(before, after), ['washer']);
    });

    test('bagaglio e alloggio cambiati', () {
      const after = AiPackingSetup(
        luggageId: 'l2',
        stops: {
          'a': AiStopAnswers(activities: ['beach', 'hiking'], stay: 'camping'),
        },
      );
      expect(setupChangedFields(before, after), ['luggage', 'stays']);
    });

    test('prima volta: nessun campo', () {
      expect(setupChangedFields(null, before), isEmpty);
    });
  });
}
