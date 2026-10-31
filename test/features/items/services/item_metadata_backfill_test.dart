import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/services/item_metadata_backfill.dart';
import 'package:pack_log/features/items/services/item_metadata_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockItemRepository extends Mock implements ItemRepository {}

/// item-metadata finto: risponde finché ha risposte, poi null (limite/rete).
class FakeItemMetadataService extends ItemMetadataService {
  FakeItemMetadataService({this.answers = 1000}) : super(url: '', anonKey: '');

  int answers;
  final names = <String>[];

  @override
  Future<ItemMetadataResult?> fromName(String name) async {
    names.add(name);
    if (answers-- <= 0) return null;
    return ItemMetadataResult(
      metadata: {'name': name},
      category: ItemCategory.vestiti,
    );
  }
}

ItemModel _item(int n, {String? aiMetadata, String house = 'h1'}) => ItemModel(
  id: 'item-$n',
  houseId: house,
  name: 'capo $n',
  category: ItemCategory.varie,
  aiMetadata: aiMetadata,
  createdAt: DateTime(2026, 1, n),
  updatedAt: DateTime(2026, 1, n),
);

void main() {
  late MockItemRepository repo;
  late Map<String, ItemModel> db;
  var now = DateTime(2026, 10, 21, 10);

  ItemMetadataBackfill backfill(FakeItemMetadataService service) =>
      ItemMetadataBackfill(
        repository: repo,
        service: service,
        prefs: SharedPreferences.getInstance(),
        now: () => now,
      );

  setUpAll(() => registerFallbackValue(_item(0)));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 21, 10);
    repo = MockItemRepository();
    db = {};
    when(() => repo.getAllItems()).thenAnswer((_) async => db.values.toList());
    when(
      () => repo.getItemById(any()),
    ).thenAnswer((i) async => db[i.positionalArguments.first as String]!);
    when(() => repo.updateItem(any())).thenAnswer((i) async {
      final m = i.positionalArguments.first as ItemModel;
      db[m.id] = m;
    });
  });

  test('completa gli oggetti senza scheda, dal più vecchio, senza cambiare la '
      'categoria', () async {
    db = {
      'item-2': _item(2, house: 'h2'),
      'item-1': _item(1),
      'item-3': _item(3, aiMetadata: '{}'),
    };
    final service = FakeItemMetadataService();

    final houses = await backfill(service).run();

    expect(service.names, ['capo 1', 'capo 2']);
    expect(houses, {'h1', 'h2'});
    expect(jsonDecode(db['item-1']!.aiMetadata!), {'name': 'capo 1'});
    expect(db['item-1']!.category, ItemCategory.varie);
  });

  test('si ferma alla prima risposta mancata', () async {
    db = {for (var n = 1; n <= 5; n++) 'item-$n': _item(n)};
    final service = FakeItemMetadataService(answers: 2);

    await backfill(service).run();

    expect(service.names, ['capo 1', 'capo 2', 'capo 3']);
    expect(db.values.where((i) => i.aiMetadata != null), hasLength(2));
  });

  test(
    'al massimo il limite giornaliero, poi il giorno dopo riparte',
    () async {
      db = {for (var n = 1; n <= 40; n++) 'item-$n': _item(n)};
      final service = FakeItemMetadataService();
      final b = backfill(service);

      await b.run();
      expect(service.names, hasLength(kItemMetadataBackfillDailyLimit));

      now = now.add(const Duration(hours: 2));
      await b.run();
      expect(service.names, hasLength(kItemMetadataBackfillDailyLimit));

      now = now.add(const Duration(days: 1));
      await b.run();
      expect(service.names, hasLength(40));
    },
  );

  test('non riparte prima dell\'intervallo', () async {
    db = {'item-1': _item(1)};
    final service = FakeItemMetadataService(answers: 0);
    final b = backfill(service);

    await b.run();
    now = now.add(const Duration(minutes: 10));
    await b.run();

    expect(service.names, ['capo 1']);
  });

  test('rinominato nel frattempo: la scheda non si scrive', () async {
    db = {'item-1': _item(1)};
    when(
      () => repo.getItemById('item-1'),
    ).thenAnswer((_) async => _item(1).copyWith(name: 'altro'));

    final houses = await backfill(FakeItemMetadataService()).run();

    expect(houses, isEmpty);
    verifyNever(() => repo.updateItem(any()));
  });

  test('completa anche gli oggetti con aiPending, tenendo le scelte '
      'dell\'utente; non tocca quelli con la scheda completa', () async {
    db = {
      'item-1': _item(
        1,
        aiMetadata: jsonEncode({
          'warmth': 4,
          'userFields': ['warmth'],
          'aiPending': true,
        }),
      ),
      'item-2': _item(2, aiMetadata: '{"baseColor":"blu"}'),
    };
    final service = FakeItemMetadataService();

    await backfill(service).run();

    expect(service.names, ['capo 1']);
    expect(jsonDecode(db['item-1']!.aiMetadata!), {
      'name': 'capo 1',
      'warmth': 4,
      'userFields': ['warmth'],
    });
    expect(db['item-2']!.aiMetadata, '{"baseColor":"blu"}');
  });

  test('completato nel frattempo: la risposta non riscrive la scheda',
      () async {
    db = {
      'item-1': _item(1, aiMetadata: jsonEncode({'aiPending': true})),
    };
    when(() => repo.getItemById('item-1')).thenAnswer(
      (_) async => _item(1, aiMetadata: '{"baseColor":"blu"}'),
    );

    final houses = await backfill(FakeItemMetadataService()).run();

    expect(houses, isEmpty);
    verifyNever(() => repo.updateItem(any()));
  });
}
