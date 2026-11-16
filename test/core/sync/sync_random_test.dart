import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sync_sim/sync_sim.dart';

/// Sequenze casuali di azioni su due telefoni, sempre le stesse a parità di
/// seme. Cercano gli incroci a cui nessuno ha pensato: alla fine valgono le
/// regole di [SyncSim.settleAndCheck]. Una sequenza che fallisce stampa le
/// sue azioni: va copiata in `sync_scenarios_test.dart` come scenario fisso.
///
/// Per una caccia più larga, o per rivedere un seme solo:
/// `flutter test test/core/sync/sync_random_test.dart
///   --dart-define=SYNC_SIM_SEEDS=600 --dart-define=SYNC_SIM_STEPS=60
///   --dart-define=SYNC_SIM_ONLY=164`
const _seeds = int.fromEnvironment('SYNC_SIM_SEEDS', defaultValue: 40);
const _steps = int.fromEnvironment('SYNC_SIM_STEPS', defaultValue: 35);
const _only = int.fromEnvironment('SYNC_SIM_ONLY');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (var seed = 1; seed <= _seeds; seed++) {
    if (_only != 0 && seed != _only) continue;
    test('sequenza casuale $seed', () async {
      final sim = SyncSim();
      addTearDown(sim.close);
      final log = <String>[];
      try {
        await _run(sim, Random(seed), log);
        sim.server.offline = false;
        for (final device in sim.devices) {
          device.monitoring.errors.clear();
          await device.retryNow();
        }
        await sim.settleAndCheck();
      } catch (_) {
        // ignore: avoid_print
        print('seme $seed:\n  ${log.join('\n  ')}');
        rethrow;
      }
    });
  }
}

Future<void> _run(SyncSim sim, Random random, List<String> log) async {
  // Modificare una cosa che l'altro telefono ha cancellato la fa tornare
  // (è come "Annulla"): scelta nota, vedi lo scenario fisso. Qui si evita.
  final deleted = <String>{};
  var counter = 0;
  String newId(String prefix) => '$prefix${++counter}';
  T? pick<T>(List<T> list) =>
      list.isEmpty ? null : list[random.nextInt(list.length)];

  for (var step = 0; step < _steps; step++) {
    final d = random.nextBool() ? sim.a : sim.b;
    final rows = await d.liveRows();
    List<String> ids(String table) => [
      for (final r in rows[table]!) r['id'] as String,
    ];
    final house = pick(ids('houses'));
    for (final table in const ['items', 'kits']) {
      for (final r in rows[table]!) {
        if (deleted.contains(r['house_id'])) deleted.add(r['id'] as String);
      }
    }
    final item = pick(rows['items']!);
    final trip = pick(rows['trips']!);
    final kit = pick(rows['kits']!);

    Future<void> run(String what, Future<void> Function() op) async {
      log.add('${d.name}: $what');
      await op();
    }

    Future<void> edit(String id, String what, Future<void> Function() op) =>
        deleted.contains(id) ? Future.value() : run(what, op);
    Future<void> delete(String id, String what, Future<void> Function() op) {
      deleted.add(id);
      return run(what, op);
    }

    switch (random.nextInt(24)) {
      case 0:
      case 1:
        final id = newId('h');
        await run('addHouse $id', () => d.addHouse(id));
      case 2:
        if (house == null) continue;
        final id = newId('s');
        await run('addSpace $id in $house', () => d.addSpace(id, house));
      case 3:
      case 4:
        if (house == null) continue;
        final id = newId('i');
        final space = pick([
          null,
          for (final s in rows['spaces']!)
            if (s['house_id'] == house) s['id'] as String,
        ]);
        await run(
          'addItem $id in $house spazio $space',
          () => d.addItem(id, house, spaceId: space),
        );
      case 5:
        final id = newId('l');
        final home = random.nextBool() ? house : null;
        await run(
          'addLuggage $id in $home',
          () => d.addLuggage(id, houseId: home),
        );
      case 6:
        final id = newId('t');
        final to = random.nextBool() ? house : null;
        await run(
          'addTrip $id verso $to',
          () => d.addTrip(id, destinationHouseId: to),
        );
      case 7:
        if (house == null) continue;
        await edit(
          house,
          'renameHouse $house',
          () => d.renameHouse(house, 'Casa $step'),
        );
      case 8:
        if (item == null) continue;
        final id = item['id'] as String;
        await edit(
          id,
          'renameItem $id',
          () => d.renameItem(id, 'Oggetto $step'),
        );
      case 9:
        if (item == null) continue;
        final id = item['id'] as String;
        final space = pick([
          null,
          for (final s in rows['spaces']!)
            if (s['house_id'] == item['house_id']) s['id'] as String,
        ]);
        await edit(
          id,
          'moveItem $id in $space',
          () => d.moveItemToSpace(id, space),
        );
      case 10:
        if (house == null) continue;
        await delete(house, 'deleteHouse $house', () => d.deleteHouse(house));
      case 11:
        final space = pick(ids('spaces'));
        if (space == null) continue;
        await delete(space, 'deleteSpace $space', () => d.deleteSpace(space));
      case 12:
        if (item == null) continue;
        final id = item['id'] as String;
        await delete(id, 'deleteItem $id', () => d.deleteItem(id));
      case 13:
        final luggage = pick(ids('luggages'));
        if (luggage == null) continue;
        await delete(
          luggage,
          'deleteLuggage $luggage',
          () => d.deleteLuggage(luggage),
        );
      case 14:
        if (trip == null) continue;
        final id = trip['id'] as String;
        await delete(id, 'deleteTrip $id', () => d.deleteTrip(id));
      case 15:
        if (house == null) continue;
        final id = newId('k');
        await run('addKit $id in $house', () => d.addKit(id, house));
      case 16:
        if (kit == null) continue;
        final inHouse = pick([
          for (final i in rows['items']!)
            if (i['house_id'] == kit['house_id']) i['id'] as String,
        ]);
        if (inHouse == null) continue;
        final id = kit['id'] as String;
        await edit(id, 'putInKit $id $inHouse', () => d.putInKit(id, inHouse));
      case 17:
        final row = pick(rows['kit_items']!);
        if (row == null) continue;
        final kitId = row['kit_id'] as String;
        final itemId = row['item_id'] as String;
        await edit(
          kitId,
          'removeFromKit $kitId $itemId',
          () => d.removeFromKit(kitId, itemId),
        );
      case 18:
        if (kit == null) continue;
        final id = kit['id'] as String;
        await delete(id, 'deleteKit $id', () => d.deleteKit(id));
      case 19:
        if (trip == null) continue;
        final tripId = trip['id'] as String;
        final id = newId('ti');
        await edit(
          tripId,
          'addTripItem $id a $tripId',
          () => d.addTripItem(tripId, id),
        );
      case 20:
        if (trip == null) continue;
        final entry = pick(
          (trip['items'] as List).cast<Map<String, dynamic>>(),
        );
        if (entry == null) continue;
        final tripId = trip['id'] as String;
        final id = entry['id'] as String;
        await edit(
          tripId,
          'checkTripItem $id di $tripId',
          () => d.checkTripItem(tripId, id, true),
        );
      case 21:
        final luggage = pick(ids('luggages'));
        if (trip == null || luggage == null) continue;
        final tripId = trip['id'] as String;
        if ((trip['luggage_ids'] as List).contains(luggage)) continue;
        await edit(
          tripId,
          'linkLuggage $luggage a $tripId',
          () => d.linkLuggage(tripId, luggage),
        );
      case 22:
        log.add(sim.server.offline ? 'rete: torna' : 'rete: cade');
        sim.server.offline = !sim.server.offline;
        if (!sim.server.offline) {
          for (final device in sim.devices) {
            device.monitoring.errors.clear();
            await device.retryNow();
          }
        }
      default:
        log.add('${d.name}: sync');
        await d.sync().catchError((_) {});
        if (sim.server.offline) d.monitoring.errors.clear();
    }
    // Tra un'azione e l'altra spesso si sincronizza, come nell'app.
    if (random.nextInt(3) == 0) {
      log.add('${d.name}: sync');
      await d.sync().catchError((_) {});
      if (sim.server.offline) d.monitoring.errors.clear();
    }
  }
}
