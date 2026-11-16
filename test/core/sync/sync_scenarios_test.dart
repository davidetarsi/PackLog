import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sync_sim/sync_sim.dart';

/// Scenari di sincronizzazione con due telefoni e un server con stato.
/// Ogni scenario finisce con le stesse regole: vedi [SyncSim.settleAndCheck].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SyncSim sim;

  setUp(() => sim = SyncSim());
  tearDown(() => sim.close());

  /// Una casa con uno spazio, due oggetti, un bagaglio e un viaggio che ci
  /// arriva, già su tutti e due i telefoni.
  Future<void> seed() async {
    await sim.a.addHouse('h1');
    await sim.a.addSpace('s1', 'h1');
    await sim.a.addItem('i1', 'h1', spaceId: 's1');
    await sim.a.addItem('i2', 'h1');
    await sim.a.addLuggage('l1', houseId: 'h1');
    await sim.a.addTrip('t1', destinationHouseId: 'h1');
    await sim.settle();
  }

  test('quello che crea un telefono arriva all altro', () async {
    await seed();
    await sim.settleAndCheck();
    expect((await sim.b.liveRows())['items'], hasLength(2));
  });

  test('casa di arrivo cancellata: il viaggio resta, senza casa', () async {
    await seed();
    await sim.a.deleteHouse('h1');
    await sim.settleAndCheck();
    final trip = (await sim.b.liveRows())['trips']!.single;
    expect(trip['destination_house_id'], isNull);
  });

  test('A cancella la casa mentre B ci aggiunge un oggetto', () async {
    await seed();
    await sim.a.deleteHouse('h1');
    await sim.b.addItem('i3', 'h1');
    await sim.settleAndCheck();
    // Vince la cancellazione: l'oggetto va via con la casa.
    expect((await sim.b.liveRows())['items'], isEmpty);
  });

  test('A cancella lo spazio mentre B ci sposta un oggetto', () async {
    await seed();
    await sim.a.deleteSpace('s1');
    await sim.b.moveItemToSpace('i2', 's1');
    await sim.settleAndCheck();
    // L'oggetto resta, nel mucchio generale della casa.
    final items = (await sim.a.liveRows())['items']!;
    expect(items.map((r) => r['space_id']), [null, null]);
  });

  test('A cancella la casa mentre B crea un viaggio che ci arriva', () async {
    await seed();
    await sim.a.deleteHouse('h1');
    await sim.b.addTrip('t2', destinationHouseId: 'h1');
    await sim.settleAndCheck();
  });

  test('A cancella la casa mentre B ci aggiunge uno spazio', () async {
    await seed();
    await sim.a.deleteHouse('h1');
    await sim.b.addSpace('s2', 'h1');
    await sim.settleAndCheck();
  });

  test(
    'stesso oggetto rinominato da tutti e due: i telefoni concordano',
    () async {
      await seed();
      await sim.a.renameItem('i1', 'Da A');
      await sim.b.renameItem('i1', 'Da B');
      await sim.settleAndCheck();
      // La regola di oggi: conta l'ora in cui il server riceve la modifica, non
      // quella in cui è stata fatta. A sincronizza per primo dopo la modifica
      // di B, quindi quella di B (più recente) viene scartata.
      final item = (await sim.b.liveRows())['items']!.firstWhere(
        (r) => r['id'] == 'i1',
      );
      expect(item['name'], 'Da A');
    },
  );

  test('un oggetto cancellato non torna se l altro lo modifica dopo', () async {
    await seed();
    await sim.a.deleteItem('i1');
    await sim.b.renameItem('i1', 'Ancora qui');
    await sim.settleAndCheck();
    expect((await sim.b.liveRows())['items']!.map((r) => r['id']), ['i2']);
  });

  test('modifiche fatte offline arrivano al ritorno della rete', () async {
    await seed();
    sim.server.offline = true;
    await sim.b.renameItem('i2', 'Offline');
    await sim.b.addItem('i3', 'h1');
    await sim.b.sync().catchError((_) {});
    sim.server.offline = false;
    sim.b.monitoring.errors.clear();
    await sim.b.retryNow();
    await sim.settleAndCheck();
    expect((await sim.a.liveRows())['items'], hasLength(3));
  });

  test('invio interrotto a metà: al giro dopo si completa', () async {
    await sim.a.addHouse('h1');
    await sim.a.addSpace('s1', 'h1');
    await sim.a.addItem('i1', 'h1', spaceId: 's1');
    await sim.a.addTrip('t1', destinationHouseId: 'h1');
    sim.server.writesBeforeFailure = 2;
    await sim.a.sync().catchError((_) {});
    sim.server.writesBeforeFailure = null;
    sim.a.monitoring.errors.clear();
    await sim.a.retryNow();
    await sim.settleAndCheck();
    expect((await sim.b.liveRows())['trips'], hasLength(1));
  });

  test('un viaggio cancellato sparisce anche dall altro telefono', () async {
    await seed();
    await sim.b.deleteTrip('t1');
    await sim.settleAndCheck();
    expect((await sim.a.liveRows())['trips'], isEmpty);
  });

  test('bagaglio cancellato mentre l altro rinomina la casa', () async {
    await seed();
    await sim.a.deleteLuggage('l1');
    await sim.b.renameHouse('h1', 'Casa nuova');
    await sim.settleAndCheck();
    expect((await sim.b.liveRows())['luggages'], isEmpty);
  });
}
