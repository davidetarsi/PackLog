import 'package:pack_log/core/sync/supabase_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Orologio condiviso dalla simulazione: ogni evento avanza di due secondi,
/// così l'ordine degli eventi è lo stesso a ogni esecuzione.
class SimClock {
  SimClock()
    : _now = DateTime.fromMillisecondsSinceEpoch(
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) * 1000,
        isUtc: true,
      ).subtract(const Duration(days: 1));

  DateTime _now;

  DateTime tick() => _now = _now.add(const Duration(seconds: 2));
}

/// Il server della sincronizzazione, in memoria e con stato.
///
/// Si comporta come Supabase per quello che serve alla sync: tiene le righe
/// (anche quelle cancellate, come tombstone), mette lui `updated_at` al
/// microsecondo, rifiuta le chiavi esterne che non esistono e risolve le righe
/// dei kit sulla coppia (kit, oggetto).
class FakeSyncServer implements SupabaseRepository {
  FakeSyncServer(this.clock);

  final SimClock clock;

  /// Senza rete ogni chiamata fallisce.
  bool offline = false;

  /// Scritture ancora accettate prima che la rete cada (null = nessun limite).
  int? writesBeforeFailure;

  final Map<String, Map<String, Map<String, dynamic>>> _tables = {
    for (final t in tableNames) t: {},
  };

  static const tableNames = [
    'houses',
    'spaces',
    'luggages',
    'items',
    'kits',
    'kit_items',
    'trips',
  ];

  /// Colonna → tabella a cui punta, come nello schema del server.
  static const _foreignKeys = {
    'spaces': {'house_id': 'houses'},
    'luggages': {'house_id': 'houses'},
    'items': {'house_id': 'houses', 'space_id': 'spaces'},
    'kits': {'house_id': 'houses'},
    'kit_items': {'kit_id': 'kits', 'item_id': 'items'},
    'trips': {'destination_house_id': 'houses'},
  };

  /// Le righe di una tabella, copiate (cancellate comprese).
  List<Map<String, dynamic>> rows(String table) => [
    for (final r in _tables[table]!.values) Map<String, dynamic>.of(r),
  ];

  void _checkNetwork() {
    if (offline) throw Exception('rete assente');
  }

  Future<List<Map<String, dynamic>>> _all(String table) async {
    _checkNetwork();
    return rows(table);
  }

  Future<Map<String, dynamic>?> _one(String table, String id) async {
    _checkNetwork();
    final row = _tables[table]![id];
    return row == null ? null : Map<String, dynamic>.of(row);
  }

  Future<DateTime> _write(String table, Map<String, dynamic> data) async {
    _checkNetwork();
    final left = writesBeforeFailure;
    if (left != null) {
      if (left == 0) throw Exception('rete caduta a metà invio');
      writesBeforeFailure = left - 1;
    }
    for (final fk in (_foreignKeys[table] ?? const {}).entries) {
      final target = data[fk.key];
      if (target != null && !_tables[fk.value]!.containsKey(target)) {
        throw PostgrestException(
          message: '$table.${fk.key} punta a una riga che non esiste',
          code: '23503',
        );
      }
    }
    final stamp = clock.tick().add(const Duration(microseconds: 176507));
    final id = data['id'] as String;
    if (table == 'kit_items') {
      // UNIQUE (kit_id, item_id): la riga della coppia prende il nuovo id.
      _tables[table]!.removeWhere(
        (_, r) =>
            r['kit_id'] == data['kit_id'] && r['item_id'] == data['item_id'],
      );
    }
    _tables[table]![id] = {
      ...?_tables[table]![id],
      ...data,
      'updated_at': stamp.toIso8601String(),
    };
    return stamp;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllHousesByUserId(String userId) =>
      _all('houses');
  @override
  Future<List<Map<String, dynamic>>> fetchAllSpacesByUserId(String userId) =>
      _all('spaces');
  @override
  Future<List<Map<String, dynamic>>> fetchAllLuggagesByUserId(String userId) =>
      _all('luggages');
  @override
  Future<List<Map<String, dynamic>>> fetchAllItemsByUserId(String userId) =>
      _all('items');
  @override
  Future<List<Map<String, dynamic>>> fetchAllKitsByUserId(String userId) =>
      _all('kits');
  @override
  Future<List<Map<String, dynamic>>> fetchAllKitItemsByUserId(String userId) =>
      _all('kit_items');
  @override
  Future<List<Map<String, dynamic>>> fetchAllTripsByUserId(String userId) =>
      _all('trips');

  @override
  Future<Map<String, dynamic>?> fetchHouseById(
    String id, {
    String? sentryTrace,
  }) => _one('houses', id);
  @override
  Future<Map<String, dynamic>?> fetchSpaceById(
    String id, {
    String? sentryTrace,
  }) => _one('spaces', id);
  @override
  Future<Map<String, dynamic>?> fetchLuggageById(
    String id, {
    String? sentryTrace,
  }) => _one('luggages', id);
  @override
  Future<Map<String, dynamic>?> fetchItemById(
    String id, {
    String? sentryTrace,
  }) => _one('items', id);
  @override
  Future<Map<String, dynamic>?> fetchKitById(
    String id, {
    String? sentryTrace,
  }) => _one('kits', id);
  @override
  Future<Map<String, dynamic>?> fetchKitItemById(
    String id, {
    String? sentryTrace,
  }) => _one('kit_items', id);
  @override
  Future<Map<String, dynamic>?> fetchTripById(
    String id, {
    String? sentryTrace,
  }) => _one('trips', id);

  @override
  Future<DateTime> upsertHouse(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) => _write('houses', data);
  @override
  Future<DateTime> upsertSpace(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) => _write('spaces', data);
  @override
  Future<DateTime> upsertLuggage(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) => _write('luggages', data);
  @override
  Future<DateTime> upsertItem(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) => _write('items', data);
  @override
  Future<DateTime> upsertKit(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) => _write('kits', data);
  @override
  Future<DateTime> upsertKitItem(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) => _write('kit_items', data);
  @override
  Future<DateTime> upsertTrip(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) => _write('trips', data);

  @override
  Future<void> insertSuitcaseEdits(List<Map<String, dynamic>> rows) async {
    _checkNetwork();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
