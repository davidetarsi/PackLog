import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_metadata_service_provider.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/services/item_metadata_service.dart';

class MockItemRepository extends Mock implements ItemRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

/// item-metadata finto: registra i nomi chiesti e risponde [result].
class FakeItemMetadataService extends ItemMetadataService {
  FakeItemMetadataService(this.result) : super(url: '', anonKey: '');

  final ItemMetadataResult? result;
  final names = <String>[];

  @override
  Future<ItemMetadataResult?> fromName(String name) async {
    names.add(name);
    return result;
  }
}

const _houseId = 'house-1';
const _pile = {'name': 'pile blu', 'category': 'Upper Body', 'bulk': 2};

ItemModel _item({String name = 'pile blu', String? aiMetadata}) => ItemModel(
  id: 'item-1',
  houseId: _houseId,
  name: name,
  category: ItemCategory.varie,
  aiMetadata: aiMetadata,
  createdAt: DateTime(2026, 10, 21),
  updatedAt: DateTime(2026, 10, 21),
);

void main() {
  late MockItemRepository repo;
  late FakeItemMetadataService service;
  late ProviderContainer container;

  void build(ItemMetadataResult? result) {
    service = FakeItemMetadataService(result);
    final analytics = MockCoreAnalyticsService();
    when(
      () => analytics.trackItemAdded(
        itemId: any(named: 'itemId'),
        houseId: any(named: 'houseId'),
        category: any(named: 'category'),
        totalItems: any(named: 'totalItems'),
      ),
    ).thenReturn(null);
    final sync = MockSyncOrchestrator();
    when(() => sync.requestSync()).thenReturn(null);
    container = ProviderContainer(
      overrides: [
        itemRepositoryProvider.overrideWithValue(repo),
        coreAnalyticsServiceProvider.overrideWithValue(analytics),
        syncOrchestratorProvider.overrideWithValue(sync),
        itemMetadataServiceProvider.overrideWithValue(service),
      ],
    );
  }

  /// Aggiunge [added] e aspetta che la scheda dal nome (asincrona) finisca.
  Future<void> add(ItemModel added, {bool categoryChosen = false}) async {
    await container.read(itemNotifierProvider(_houseId).future);
    await container
        .read(itemNotifierProvider(_houseId).notifier)
        .addItem(added, categoryChosen: categoryChosen);
    await pumpEventQueue();
  }

  setUpAll(() => registerFallbackValue(_item()));

  setUp(() {
    repo = MockItemRepository();
    when(() => repo.getItemsByHouseId(_houseId)).thenAnswer((_) async => []);
    when(() => repo.addItem(any())).thenAnswer((_) async {});
    when(() => repo.updateItem(any())).thenAnswer((_) async {});
    when(() => repo.getItemById('item-1')).thenAnswer((_) async => _item());
  });

  tearDown(() => container.dispose());

  const scheda = ItemMetadataResult(
    metadata: _pile,
    category: ItemCategory.vestiti,
  );

  test('un oggetto scritto a mano riceve la scheda e la categoria', () async {
    build(scheda);
    await add(_item());

    expect(service.names, ['pile blu']);
    final updated =
        verify(() => repo.updateItem(captureAny())).captured.single
            as ItemModel;
    expect(jsonDecode(updated.aiMetadata!), _pile);
    expect(updated.category, ItemCategory.vestiti);
  });

  test('la categoria scelta dall\'utente non cambia', () async {
    build(scheda);
    await add(_item(), categoryChosen: true);

    final updated =
        verify(() => repo.updateItem(captureAny())).captured.single
            as ItemModel;
    expect(updated.aiMetadata, isNotNull);
    expect(updated.category, ItemCategory.varie);
  });

  test(
    'un oggetto dallo scan (con la scheda) non chiama la funzione',
    () async {
      build(scheda);
      await add(_item(aiMetadata: '{}'));

      expect(service.names, isEmpty);
      verifyNever(() => repo.updateItem(any()));
    },
  );

  test('rinominato nel frattempo: la scheda non si scrive', () async {
    build(scheda);
    when(
      () => repo.getItemById('item-1'),
    ).thenAnswer((_) async => _item(name: 'pile rosso'));
    await add(_item());

    verifyNever(() => repo.updateItem(any()));
  });

  test('senza risposta (rete, limite) l\'oggetto resta com\'è', () async {
    build(null);
    await add(_item());

    expect(service.names, ['pile blu']);
    verifyNever(() => repo.updateItem(any()));
  });

  group('ItemMetadataService.parse', () {
    test('il primo capo, con la categoria dell\'app', () {
      final r = ItemMetadataService.parse(
        jsonEncode({
          'items': [
            {'metadata': _pile, 'app_category': 'toiletries', 'dubbi': []},
          ],
          'note_tecniche': [],
        }),
      );
      expect(r!.metadata, _pile);
      expect(r.category, ItemCategory.toiletries);
    });

    test('una risposta senza capi o senza forma vale null', () {
      expect(ItemMetadataService.parse(jsonEncode({'items': []})), isNull);
      expect(ItemMetadataService.parse(jsonEncode([1])), isNull);
    });
  });
}
