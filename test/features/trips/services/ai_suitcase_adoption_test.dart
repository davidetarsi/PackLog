import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/services/ai_suitcase_adoption.dart';

final _now = DateTime(2026, 11, 8);

ItemModel _house(String id, {int? quantity}) => ItemModel(
  id: id,
  houseId: 'h1',
  name: 'Capo $id',
  category: ItemCategory.vestiti,
  quantity: quantity,
  createdAt: _now,
  updatedAt: _now,
);

AiPackedItem _packed(String id, int quantity) => AiPackedItem(
  itemId: id,
  quantity: quantity,
  reason: const AiReason(code: 'c', label: 'l', sentence: 's'),
);

AiSlot _slot(String id, {bool toBuy = false}) => AiSlot(
  id: id,
  type: 'giacca',
  category: ItemCategory.vestiti,
  level: AiSlotLevel.useful,
  name: 'Giacca',
  copies: 1,
  remaining: 1,
  addLabel: 'Aggiungi',
  toBuy: toBuy,
);

AiPackingResult _result({
  List<AiPackedItem> proposal = const [],
  List<AiSlot>? slots,
  List<String> kitLearnCounted = const [],
  Map<String, String> kitAnswers = const {},
}) => AiPackingResult(
  generatedAt: _now,
  houseId: 'h1',
  proposal: proposal,
  slots: slots,
  kitLearnCounted: kitLearnCounted,
  kitAnswers: kitAnswers,
);

LuggageModel _luggage(String id) => LuggageModel(
  id: id,
  name: 'Bagaglio $id',
  sizeType: LuggageSize.values.first,
  createdAt: _now,
  updatedAt: _now,
);

TripModel _trip({AiPackingResult? aiResult}) => TripModel(
  id: 't1',
  name: 'Viaggio',
  items: [
    TripItem(
      id: 'old',
      name: 'Vecchio',
      category: ItemCategory.vestiti,
      quantity: 1,
    ),
  ],
  luggages: [_luggage('old-l')],
  aiResult: aiResult,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  const setup = AiPackingSetup(houseId: 'h1', luggageId: 'l1');

  test('adopts_proposal_items_and_luggage', () {
    final adopted = adoptedTrip(
      trip: _trip(),
      proposal: _result(proposal: [_packed('a', 2), _packed('gone', 1)]),
      setup: setup,
      luggage: _luggage('l1'),
      houseItems: [_house('a', quantity: 5)],
    );
    expect([for (final i in adopted.items) i.id], ['a']);
    expect(adopted.items.single.quantity, 2);
    expect(adopted.items.single.originHouseId, 'h1');
    expect([for (final l in adopted.luggages) l.id], ['l1']);
    expect(adopted.aiSetup, setup);
    expect(adopted.aiResult, isNotNull);
    expect(adopted.updatedAt.isAfter(_now), isTrue);
  });

  test('keeps_trip_items_when_house_items_missing', () {
    final trip = _trip();
    final adopted = adoptedTrip(
      trip: trip,
      proposal: _result(proposal: [_packed('a', 1)]),
      setup: setup,
      luggage: _luggage('l1'),
      houseItems: null,
    );
    expect(adopted.items, trip.items);
    expect(adopted.luggages, trip.luggages);
    expect(adopted.aiResult, isNotNull);
    expect(adopted.aiSetup, setup);
  });

  test('carries_to_buy_and_kit_counted_from_previous_result', () {
    final previous = _result(
      slots: [_slot('need:v1:giacca', toBuy: true)],
      kitLearnCounted: ['kit-1'],
      kitAnswers: {'kit-1': 'added'},
    );
    final adopted = adoptedTrip(
      trip: _trip(aiResult: previous),
      proposal: _result(
        slots: [_slot('need:v1:giacca')],
        kitLearnCounted: ['kit-2'],
        kitAnswers: {'kit-3': 'dismissed'},
      ),
      setup: setup,
      houseItems: const [],
    );
    final result = adopted.aiResult!;
    expect(result.slots!.single.toBuy, isTrue);
    expect(result.kitLearnCounted, containsAll(['kit-1', 'kit-2']));
    expect(result.kitAnswers, isEmpty);
  });

  test('adopted_trip_stores_shape', () {
    final trip = _trip(
      aiResult: _result().copyWith(changeNoticeDismissed: true),
    ).copyWith(transports: ['treno']);
    final adopted = adoptedTrip(
      trip: trip,
      proposal: _result(),
      setup: setup,
      houseItems: const [],
    );
    expect(adopted.aiResult!.tripShape, AiTripShape.of(trip));
    expect(adopted.aiResult!.tripShape!.transports, ['treno']);
    expect(adopted.aiResult!.changeNoticeDismissed, isFalse);
  });
}
