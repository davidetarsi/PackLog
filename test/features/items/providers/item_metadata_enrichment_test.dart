import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/items/model/clothing_details.dart';
import 'package:pack_log/features/items/model/item_metadata_merge.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_enrichment_provider.dart';
import 'package:pack_log/features/items/providers/item_metadata_service_provider.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/services/item_metadata_service.dart';

import '../support/fake_ai_metadata_write.dart';

class MockItemRepository extends Mock implements ItemRepository {}

class MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

/// item-metadata finto: registra i nomi chiesti e risponde [result]. Un nome
/// tenuto con [hold] risponde solo quando lo decide il test con [answer] o
/// [fail].
class FakeItemMetadataService extends ItemMetadataService {
  FakeItemMetadataService(this.result) : super(url: '', anonKey: '');

  final ItemMetadataResult? result;
  final names = <String>[];
  final _held = <String, Completer<ItemMetadataResult?>>{};

  void hold(String name) => _held[name] = Completer<ItemMetadataResult?>();

  void answer(String name, ItemMetadataResult? r) => _held[name]!.complete(r);

  void fail(String name, Object error) => _held[name]!.completeError(error);

  @override
  Future<ItemMetadataResult?> fromName(String name) async {
    names.add(name);
    final held = _held[name];
    if (held != null) return held.future;
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
  late Map<String, ItemModel> db;

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

  Future<void> save(ItemModel model) async {
    await container
        .read(itemNotifierProvider(_houseId).notifier)
        .updateItem(model);
    await pumpEventQueue();
  }

  /// Il repository finto tiene le righe in [db], come quello vero: un id
  /// eliminato non si legge più.
  void useDb() {
    db = {};
    when(
      () => repo.getItemsByHouseId(_houseId),
    ).thenAnswer((_) async => db.values.toList());
    when(() => repo.getItemById(any())).thenAnswer((i) async {
      final id = i.positionalArguments.first as String;
      return db[id] ?? (throw StateError('item $id eliminato'));
    });
    when(() => repo.addItem(any())).thenAnswer((i) async {
      final m = i.positionalArguments.first as ItemModel;
      db[m.id] = m;
    });
    when(() => repo.updateItem(any())).thenAnswer((i) async {
      final m = i.positionalArguments.first as ItemModel;
      db[m.id] = m;
    });
    when(() => repo.deleteItem(any())).thenAnswer((i) async {
      final id = i.positionalArguments.first as String;
      return db.remove(id) != null;
    });
  }

  setUpAll(() {
    registerFallbackValue(_item());
    registerAiMetadataFallback();
  });

  setUp(() {
    repo = MockItemRepository();
    stubAiMetadataWrite(repo);
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

  group('richiesta della scheda', () {
    setUp(useDb);

    test('l\'id è in richiesta finché la risposta valida non arriva', () async {
      build(scheda);
      service.hold('pile blu');
      await add(_item());

      expect(container.read(itemEnrichmentProvider), {'item-1'});

      service.answer('pile blu', scheda);
      await pumpEventQueue();

      expect(container.read(itemEnrichmentProvider), isEmpty);
      expect(db['item-1']!.aiMetadata, isNotNull);
    });

    test('con una risposta null l\'id esce dalla richiesta', () async {
      build(null);
      service.hold('pile blu');
      await add(_item());

      service.answer('pile blu', null);
      await pumpEventQueue();

      expect(container.read(itemEnrichmentProvider), isEmpty);
      expect(db['item-1']!.aiMetadata, isNull);
    });

    test('con un errore l\'id esce dalla richiesta e l\'oggetto resta '
        'modificabile', () async {
      build(null);
      service.hold('pile blu');
      await add(_item());

      service.fail('pile blu', Exception('rete assente'));
      await pumpEventQueue();

      expect(container.read(itemEnrichmentProvider), isEmpty);
      expect(db['item-1']!.name, 'pile blu');
      expect(db['item-1']!.aiMetadata, isNull);
    });

    test('la categoria segnata come scelta nei metadati non cambia', () async {
      build(scheda);
      await add(
        _item(aiMetadata: '{"userFields":["appCategory"],"aiPending":true}'),
      );

      final updated =
          verify(() => repo.updateItem(captureAny())).captured.single
              as ItemModel;
      expect(updated.category, ItemCategory.varie);
      expect(jsonDecode(updated.aiMetadata!)['userFields'], ['appCategory']);
    });

    test('oggetto con aiPending: dopo la risposta warmth è dell\'utente, gli '
        'altri campi dell\'AI, aiPending sparisce', () async {
      build(scheda);
      service.hold('pile blu');
      final pending = withUserDetails(
        details: const ClothingDetails(warmth: 4),
        touched: {ClothingField.warmth},
      );
      await add(_item(aiMetadata: pending));

      service.answer(
        'pile blu',
        const ItemMetadataResult(
          metadata: {
            ..._pile,
            'warmth': 2,
            'baseColor': 'blu',
            'activityTags': ['Hiking'],
          },
          category: ItemCategory.vestiti,
        ),
      );
      await pumpEventQueue();

      expect(jsonDecode(db['item-1']!.aiMetadata!), {
        ..._pile,
        'warmth': 4,
        'baseColor': 'blu',
        'activityTags': ['Hiking'],
        'userFields': ['warmth'],
      });
    });

    test('l\'utente salva gli usi mentre la richiesta è in corso: la risposta '
        'li conserva', () async {
      build(scheda);
      service.hold('pile blu');
      await add(_item(aiMetadata: jsonEncode({'aiPending': true})));

      await save(
        db['item-1']!.copyWith(
          aiMetadata: withUserDetails(
            current: db['item-1']!.aiMetadata,
            details: const ClothingDetails(uses: {'Beach'}),
            touched: {ClothingField.uses},
          ),
        ),
      );
      service.answer(
        'pile blu',
        const ItemMetadataResult(
          metadata: {
            ..._pile,
            'activityTags': ['Everyday', 'Sport'],
          },
        ),
      );
      await pumpEventQueue();

      final metadata = jsonDecode(db['item-1']!.aiMetadata!) as Map;
      expect(metadata['activityTags'], ['Beach']);
      expect(metadata['userFields'], ['activityTags']);
      expect(metadata.containsKey('aiPending'), isFalse);
    });

    test(
      'salvare senza rinominare non fa partire una nuova richiesta',
      () async {
        build(scheda);
        service.hold('pile blu');
        await add(_item());

        await save(db['item-1']!.copyWith(description: 'blu'));

        expect(service.names, ['pile blu']);
        expect(container.read(itemEnrichmentProvider), {'item-1'});
      },
    );

    test('rinomina prima della risposta: la risposta del nome vecchio non '
        'scrive, parte la richiesta per il nome nuovo', () async {
      build(scheda);
      service.hold('pile blu');
      service.hold('pile rosso');
      await add(_item());

      await save(_item(name: 'pile rosso'));

      expect(service.names, ['pile blu', 'pile rosso']);

      service.answer('pile blu', scheda);
      await pumpEventQueue();

      expect(db['item-1']!.name, 'pile rosso');
      expect(db['item-1']!.aiMetadata, isNull);
      expect(container.read(itemEnrichmentProvider), {'item-1'});

      service.answer('pile rosso', scheda);
      await pumpEventQueue();

      expect(jsonDecode(db['item-1']!.aiMetadata!), _pile);
      expect(container.read(itemEnrichmentProvider), isEmpty);
    });

    test(
      'la rinomina non cambia la categoria: l\'utente l\'ha già vista',
      () async {
        build(scheda);
        service.hold('pile rosso');
        await add(_item());
        await save(_item(name: 'pile rosso'));

        service.answer('pile rosso', scheda);
        await pumpEventQueue();

        expect(db['item-1']!.category, ItemCategory.varie);
      },
    );

    test('la scrittura in background che fallisce lascia l\'elenco com\'è '
        '(niente AsyncError) e chiude l\'attesa', () async {
      build(scheda);
      service.hold('pile blu');
      await add(_item());
      when(() => repo.updateItem(any())).thenThrow(Exception('db'));

      service.answer('pile blu', scheda);
      await pumpEventQueue();

      final state = container.read(itemNotifierProvider(_houseId));
      expect(state.hasError, isFalse);
      expect(state.value!.single.name, 'pile blu');
      expect(container.read(itemEnrichmentProvider), isEmpty);
    });

    test('rinominato con la scheda del nome vecchio già salvata (aiPending): '
        'la risposta del nome nuovo tiene le scelte dell\'utente e riempie il '
        'resto', () async {
      build(scheda);
      service.hold('pile rosso');
      final old = jsonEncode({
        ..._pile,
        'warmth': 4,
        'baseColor': 'verde',
        'userFields': ['warmth'],
        'aiPending': true,
      });
      await add(_item(aiMetadata: old), categoryChosen: true);
      // La scheda aperta salva col nome nuovo e aiPending.
      await save(_item(name: 'pile rosso', aiMetadata: old));

      expect(service.names, ['pile blu', 'pile rosso']);

      service.answer(
        'pile rosso',
        const ItemMetadataResult(
          metadata: {..._pile, 'warmth': 1, 'baseColor': 'rosso'},
        ),
      );
      await pumpEventQueue();

      expect(jsonDecode(db['item-1']!.aiMetadata!), {
        ..._pile,
        'warmth': 4,
        'baseColor': 'rosso',
        'userFields': ['warmth'],
      });
    });

    test('oggetto eliminato prima della risposta: nessuna scrittura, resta '
        'eliminato', () async {
      build(scheda);
      service.hold('pile blu');
      await add(_item());
      await container
          .read(itemNotifierProvider(_houseId).notifier)
          .deleteItem('item-1', _houseId);

      service.answer('pile blu', scheda);
      await pumpEventQueue();

      expect(db, isEmpty);
      verifyNever(() => repo.updateItem(any()));
      expect(container.read(itemEnrichmentProvider), isEmpty);
    });
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
