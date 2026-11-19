import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/core/sync/sync_serializers.dart';
import 'package:pack_log/core/sync/sync_service.dart';
import 'package:pack_log/core/sync/tombstone_config_service.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../test_database_setup.dart';
import 'fake_sync_server.dart';

/// Monitoring che tiene da parte errori e breadcrumb invece di mandarli.
class RecordingMonitoring implements AppMonitoringService {
  final errors = <String>[];
  final breadcrumbs = <String>[];

  @override
  void captureException(
    Object exception, {
    StackTrace? stackTrace,
    SentryLevel level = SentryLevel.error,
    Map<String, String>? tags,
  }) => errors.add('${tags ?? const {}} $exception');

  @override
  void logBreadcrumb(
    String message, {
    String category = 'sync',
    Map<String, dynamic>? data,
  }) => breadcrumbs.add(message);

  @override
  String generateTraceId() => 'trace';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Retention implements TombstoneConfigService {
  @override
  Future<int> getRetentionDays() async => 15;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Un telefono: il database vero in memoria e il `SyncService` vero.
class SimDevice {
  SimDevice(this.name, FakeSyncServer server)
    : _clock = server.clock,
      db = createTestDatabase() {
    service = SyncService(
      housesDao: db.housesDao,
      itemsDao: db.itemsDao,
      spacesDao: db.spacesDao,
      luggagesDao: db.luggagesDao,
      kitsDao: db.kitsDao,
      kitItemsDao: db.kitItemsDao,
      tripsDao: db.tripsDao,
      suitcaseEditsDao: db.suitcaseEditsDao,
      remote: server,
      monitoring: monitoring,
      tombstoneConfig: _Retention(),
    );
  }

  final String name;
  final SimClock _clock;
  final AppDatabase db;
  final monitoring = RecordingMonitoring();
  late final SyncService service;

  /// Un'azione dell'utente. I DAO usano l'ora vera: qui le righe toccate
  /// prendono l'ora della simulazione, così l'ordine degli eventi è certo.
  Future<void> act(Future<void> Function(AppDatabase db) op) async {
    final realStart = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await op(db);
    final stamp = _clock.tick().millisecondsSinceEpoch ~/ 1000;
    for (final table in FakeSyncServer.tableNames) {
      for (final column in const ['updated_at', 'created_at']) {
        await db.customStatement(
          'UPDATE $table SET $column = ? WHERE $column >= ?',
          [stamp, realStart],
        );
      }
    }
  }

  /// Quello che fa l'app tornando in primo piano con la rete: invia la coda,
  /// poi scarica tutto.
  Future<void> sync() async {
    await service.processQueue();
    await service.fullPull('user');
  }

  /// Come al ritorno della rete: i record in attesa si riprovano subito.
  Future<void> retryNow() async {
    await db.housesDao.resetSyncRetries();
    await db.spacesDao.resetSyncRetries();
    await db.luggagesDao.resetSyncRetries();
    await db.itemsDao.resetSyncRetries();
    await db.kitsDao.resetSyncRetries();
    await db.kitItemsDao.resetSyncRetries();
    await db.tripsDao.resetSyncRetries();
  }

  // --- azioni brevi per gli scenari ---

  Future<void> addHouse(String id) => act(
    (db) => db.housesDao.insertHouse(
      HousesCompanion.insert(
        id: id,
        name: 'Casa $id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ),
  );

  Future<void> addSpace(String id, String houseId) => act(
    (db) => db.spacesDao.insertSpace(
      SpacesCompanion.insert(
        id: id,
        houseId: houseId,
        name: 'Spazio $id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ),
  );

  Future<void> addItem(String id, String houseId, {String? spaceId}) => act(
    (db) => db.itemsDao.insertItem(
      ItemsCompanion.insert(
        id: id,
        houseId: houseId,
        spaceId: Value(spaceId),
        name: 'Oggetto $id',
        category: ItemCategory.varie,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ),
  );

  Future<void> addLuggage(String id, {String? houseId}) => act(
    (db) => db.luggagesDao.insertLuggage(
      LuggagesCompanion.insert(
        id: id,
        houseId: Value(houseId),
        name: 'Bagaglio $id',
        sizeType: LuggageSize.smallBackpack,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ),
  );

  Future<void> addTrip(String id, {String? destinationHouseId}) => act(
    (db) => db.tripsDao.insertTrip(
      TripsCompanion.insert(
        id: id,
        name: 'Viaggio $id',
        destinationHouseId: Value(destinationHouseId),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ),
  );

  Future<void> renameHouse(String id, String name) => act(
    (db) => db.housesDao.updateHouse(
      HousesCompanion(
        id: Value(id),
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    ),
  );

  Future<void> renameItem(String id, String name) => act(
    (db) => db.itemsDao.updateItem(
      ItemsCompanion(
        id: Value(id),
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    ),
  );

  Future<void> moveItemToSpace(String id, String? spaceId) => act(
    (db) => db.itemsDao.updateItem(
      ItemsCompanion(
        id: Value(id),
        spaceId: Value(spaceId),
        updatedAt: Value(DateTime.now()),
      ),
    ),
  );

  Future<void> renameTrip(String id, String name) => act(
    (db) => db.tripsDao.updateTrip(
      TripsCompanion(
        id: Value(id),
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    ),
  );

  Future<void> deleteHouse(String id) =>
      act((db) => db.housesDao.deleteHouse(id));
  Future<void> deleteSpace(String id) =>
      act((db) => db.spacesDao.deleteSpace(id));
  Future<void> deleteItem(String id) => act((db) => db.itemsDao.deleteItem(id));
  Future<void> deleteLuggage(String id) =>
      act((db) => db.luggagesDao.deleteLuggage(id));
  Future<void> deleteTrip(String id) => act((db) => db.tripsDao.deleteTrip(id));

  Future<void> addKit(String id, String houseId) => act(
    (db) => db.kitsDao.upsertKit(
      KitsCompanion.insert(
        id: id,
        houseId: houseId,
        name: 'Kit $id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ),
  );

  /// L'id della riga è del telefono che la crea: sulla stessa coppia due
  /// telefoni partono con id diversi, come nell'app.
  Future<void> putInKit(String kitId, String itemId) => act(
    (db) => db.kitsDao.upsertKitItem(
      KitItemsCompanion.insert(
        id: '$name-$kitId-$itemId',
        kitId: kitId,
        itemId: itemId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ),
  );

  Future<void> removeFromKit(String kitId, String itemId) =>
      act((db) => db.kitsDao.softDeleteKitItem(kitId, itemId));

  Future<void> deleteKit(String id) =>
      act((db) => db.kitsDao.softDeleteKit(id));

  Future<void> addTripItem(String tripId, String id) => act((db) async {
    await db.tripsDao.insertTripItemsIgnoringDuplicates([
      TripItemEntriesCompanion.insert(
        id: id,
        tripId: tripId,
        name: 'In valigia $id',
        category: ItemCategory.varie,
      ),
    ]);
    await db.tripsDao.updateTrip(
      TripsCompanion(id: Value(tripId), updatedAt: Value(DateTime.now())),
    );
  });

  Future<void> checkTripItem(String tripId, String id, bool checked) =>
      act((db) => db.tripsDao.setTripItemChecked(id, tripId, checked));

  Future<void> linkLuggage(String tripId, String luggageId) => act((db) async {
    await db.luggagesDao.linkLuggageToTrip(tripId, luggageId);
    await db.tripsDao.updateTrip(
      TripsCompanion(id: Value(tripId), updatedAt: Value(DateTime.now())),
    );
  });

  // --- lettura dello stato ---

  /// Le righe vive del telefono nel formato del server, per tabella.
  Future<Map<String, List<Map<String, dynamic>>>> liveRows() async {
    final trips = <Map<String, dynamic>>[];
    for (final trip in await db.tripsDao.getAllTrips()) {
      trips.add(
        SyncSerializers.tripToJson(
          trip,
          items: await db.tripsDao.getTripItemsByTripId(trip.id),
          luggageIds: [
            for (final l in await db.luggagesDao.getLuggagesByTrip(trip.id))
              l.id,
          ],
        ),
      );
    }
    return {
      'houses': [
        for (final r in await db.housesDao.getAllHouses())
          SyncSerializers.houseToJson(r),
      ],
      'spaces': [
        for (final r in await db.spacesDao.getAllSpaces())
          SyncSerializers.spaceToJson(r),
      ],
      'luggages': [
        for (final r in await db.luggagesDao.getAllLuggages())
          SyncSerializers.luggageToJson(r),
      ],
      'items': [
        for (final r in await db.itemsDao.getAllItems())
          SyncSerializers.itemToJson(r),
      ],
      'kits': [
        for (final r in await (db.select(
          db.kits,
        )..where((k) => k.isDeleted.equals(false))).get())
          SyncSerializers.kitToJson(r),
      ],
      'kit_items': [
        for (final r in await (db.select(
          db.kitItems,
        )..where((k) => k.isDeleted.equals(false))).get())
          SyncSerializers.kitItemToJson(r),
      ],
      'trips': trips,
    };
  }

  Future<List<String>> foreignKeyViolations() async => [
    for (final row in await db.customSelect('PRAGMA foreign_key_check').get())
      row.data.toString(),
  ];

  Future<void> close() => closeTestDatabase(db);
}

/// Due telefoni dello stesso utente e il server in mezzo.
class SyncSim {
  SyncSim() {
    final clock = SimClock();
    server = FakeSyncServer(clock);
    a = SimDevice('A', server);
    b = SimDevice('B', server);
  }

  late final FakeSyncServer server;
  late final SimDevice a;
  late final SimDevice b;

  List<SimDevice> get devices => [a, b];

  Future<void> close() async {
    await a.close();
    await b.close();
  }

  /// Giri di sync finché le modifiche di ognuno sono arrivate all'altro.
  Future<void> settle({int rounds = 3}) async {
    for (var i = 0; i < rounds; i++) {
      await a.sync();
      await b.sync();
    }
  }

  /// Le regole che devono valere dopo qualsiasi sequenza:
  /// 1. nessun errore di sync; 2. nessun riferimento rotto in locale;
  /// 3. telefoni e server con le stesse righe vive;
  /// 4. un altro pull non scrive niente.
  Future<void> settleAndCheck() async {
    await settle();
    final expected = _canonical(
      _withoutDeadReferences({
        for (final table in _comparedTables)
          table: [
            for (final r in server.rows(table))
              if (r['is_deleted'] != true) r,
          ],
      }),
    );
    for (final device in devices) {
      expect(
        device.monitoring.errors,
        isEmpty,
        reason: 'telefono ${device.name}: errori di sync',
      );
      expect(
        await device.foreignKeyViolations(),
        isEmpty,
        reason: 'telefono ${device.name}: riferimenti rotti',
      );
      expect(
        _canonical(_withoutDeadReferences(await device.liveRows())),
        expected,
        reason: 'telefono ${device.name}: stato diverso dal server',
      );
      device.monitoring.breadcrumbs.clear();
      await device.service.fullPull('user');
      expect(
        device.monitoring.breadcrumbs.where((m) => m.startsWith('fullPull:')),
        [startsWith('fullPull: 0 inseriti, 0 aggiornati')],
        reason: 'telefono ${device.name}: il pull riscrive righe invariate',
      );
    }
  }

  static const _comparedTables = [
    'houses',
    'spaces',
    'luggages',
    'items',
    'kits',
    'kit_items',
    'trips',
  ];

  /// L'app nasconde in lettura i riferimenti a righe cancellate, senza
  /// riscriverli: la riga di kit di un oggetto cancellato (torna con
  /// "Annulla") e il bagaglio cancellato nella lista di un viaggio.
  static Map<String, List<Map<String, dynamic>>> _withoutDeadReferences(
    Map<String, List<Map<String, dynamic>>> tables,
  ) {
    Set<Object?> ids(String table) => {for (final r in tables[table]!) r['id']};
    final items = ids('items');
    final kits = ids('kits');
    final luggages = ids('luggages');
    return {
      ...tables,
      'kit_items': [
        for (final r in tables['kit_items']!)
          if (items.contains(r['item_id']) && kits.contains(r['kit_id'])) r,
      ],
      'trips': [
        for (final r in tables['trips']!)
          {
            ...r,
            'luggage_ids': [
              for (final id in r['luggage_ids'] as List)
                if (luggages.contains(id)) id,
            ],
          },
      ],
    };
  }

  /// Riga → testo confrontabile: senza utente, date al secondo, liste in
  /// ordine.
  static Map<String, Map<String, String>> _canonical(
    Map<String, List<Map<String, dynamic>>> tables,
  ) => {
    for (final entry in tables.entries)
      entry.key: {
        for (final row in entry.value) row['id'] as String: _rowText(row),
      },
  };

  static String _rowText(Map<String, dynamic> row) {
    final copy = Map<String, dynamic>.of(row)..remove('user_id');
    for (final key in const ['updated_at', 'created_at']) {
      final value = copy[key];
      if (value is String) {
        copy[key] = DateTime.parse(value).millisecondsSinceEpoch ~/ 1000;
      }
    }
    final items = copy['items'];
    if (items is List) {
      copy['items'] = [...items]
        ..sort((x, y) => (x['id'] as String).compareTo(y['id'] as String));
    }
    final luggageIds = copy['luggage_ids'];
    if (luggageIds is List) copy['luggage_ids'] = [...luggageIds]..sort();
    final keys = copy.keys.toList()..sort();
    return jsonEncode({for (final k in keys) k: copy[k]});
  }
}
