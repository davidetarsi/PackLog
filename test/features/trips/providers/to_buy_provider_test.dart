import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/to_buy_provider.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

AiSlot _slot(
  String id, {
  AiSlotLevel level = AiSlotLevel.useful,
  bool toBuy = true,
  int remaining = 1,
  bool removed = false,
}) => AiSlot(
  id: id,
  type: 'type-$id',
  category: ItemCategory.vestiti,
  level: level,
  name: 'Nome $id',
  copies: 1,
  remaining: remaining,
  addLabel: 'Aggiungi',
  toBuy: toBuy,
  removed: removed,
);

TripModel _trip(String id, {DateTime? departure, List<AiSlot>? slots}) =>
    TripModel(
      id: id,
      name: 'Viaggio $id',
      departureDateTime: departure,
      items: const [],
      luggages: const [],
      aiResult: slots == null
          ? null
          : AiPackingResult(
              generatedAt: DateTime(2026, 11),
              houseId: 'h1',
              slots: slots,
            ),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late MockTripRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockTripRepository();
    final sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);
    container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        coreAnalyticsServiceProvider.overrideWithValue(
          MockCoreAnalyticsService(),
        ),
        syncOrchestratorProvider.overrideWithValue(sync),
        itemRepositoryProvider.overrideWithValue(MockItemRepository()),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<List<ToBuyEntry>> entriesFor(List<TripModel> trips) async {
    when(() => repo.getAllTrips()).thenAnswer((_) async => trips);
    await container.read(tripNotifierProvider.future);
    return container.read(toBuyEntriesProvider);
  }

  test('prende solo i posti aperti segnati da comprare', () async {
    final entries = await entriesFor([
      _trip(
        't1',
        slots: [
          _slot('open'),
          _slot('closed', remaining: 0),
          _slot('not-marked', toBuy: false),
        ],
      ),
    ]);

    expect(entries.map((e) => e.slot.id), ['open']);
    expect(entries.single.trip.id, 't1');
  });

  test('un posto da comprare ma tolto non compare', () async {
    final entries = await entriesFor([
      _trip('t1', slots: [_slot('tolto', removed: true), _slot('resta')]),
    ]);

    expect(entries.map((e) => e.slot.id), ['resta']);
  });

  test('ignora i viaggi senza posti e quelli senza risultato', () async {
    final entries = await entriesFor([
      _trip('senza-risultato'),
      _trip('vecchio'),
    ]);

    expect(entries, isEmpty);
  });

  test('ordina per partenza più vicina, i senza data in fondo', () async {
    final entries = await entriesFor([
      _trip('senza-data', slots: [_slot('a')]),
      _trip('lontano', departure: DateTime(2027, 5), slots: [_slot('b')]),
      _trip('vicino', departure: DateTime(2026, 12), slots: [_slot('c')]),
    ]);

    expect(entries.map((e) => e.trip.id), ['vicino', 'lontano', 'senza-data']);
  });

  test('dentro un viaggio gli importanti vengono prima', () async {
    final entries = await entriesFor([
      _trip(
        't1',
        slots: [
          _slot('utile-1'),
          _slot('importante-1', level: AiSlotLevel.important),
          _slot('utile-2'),
          _slot('importante-2', level: AiSlotLevel.important),
        ],
      ),
    ]);

    expect(entries.map((e) => e.slot.id), [
      'importante-1',
      'importante-2',
      'utile-1',
      'utile-2',
    ]);
  });
}
