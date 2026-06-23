import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRepository {
  final SupabaseClient _client;

  /// Dimensione di pagina per i `fetchAll*`.
  ///
  /// PostgREST tronca di default a 1000 righe: senza paginazione un utente
  /// con più item perderebbe i record oltre la soglia al primo fullPull
  /// (silenziosamente). Iteriamo con `.range(from, to)` finché una pagina
  /// torna corta. Pubblico per consentire test con pageSize ridotto.
  static const int kPageSize = 1000;

  SupabaseRepository(this._client);

  /// Esegue il loop di paginazione fino a esaurire le righe.
  ///
  /// [fetchPage] riceve gli estremi [from] e [to] inclusivi e restituisce
  /// la pagina corrispondente. Quando una pagina ha meno di [pageSize]
  /// righe, il loop si ferma.
  @visibleForTesting
  static Future<List<Map<String, dynamic>>> paginatedFetch({
    required Future<List<Map<String, dynamic>>> Function(int from, int to)
    fetchPage,
    int pageSize = kPageSize,
  }) async {
    final all = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final to = from + pageSize - 1;
      final page = await fetchPage(from, to);
      all.addAll(page);
      if (page.length < pageSize) break;
      from += pageSize;
    }
    return all;
  }

  // === HOUSES ===

  /// Restituisce TUTTE le righe dell'utente (incluse quelle con
  /// `is_deleted = true`): i tombstone sono necessari al fullPull per
  /// propagare le cancellazioni agli altri device. Paginato per evitare
  /// la troncatura silenziosa di PostgREST a 1000 righe.
  Future<List<Map<String, dynamic>>> fetchAllHousesByUserId(String userId) {
    return _withTrace(
      null,
      () => paginatedFetch(
        fetchPage: (from, to) async => List<Map<String, dynamic>>.from(
          await _client
              .from('houses')
              .select()
              .eq('user_id', userId)
              .range(from, to),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> fetchHouseById(
    String id, {
    String? sentryTrace,
  }) {
    return _withTrace(
      sentryTrace,
      () => _client.from('houses').select().eq('id', id).maybeSingle(),
    );
  }

  /// Inserisce/aggiorna e ritorna il `updated_at` ufficiale del server.
  ///
  /// Il trigger Postgres `set_updated_at` (vedi
  /// `supabase/schema_updated_at_trigger.sql`) sovrascrive il campo
  /// `updated_at` di [data] con `NOW()` server-side. Il chiamante deve
  /// applicare il valore di ritorno al record locale per mantenere
  /// allineato il pivot LWW. Vedi `SyncService._syncRecord`.
  Future<DateTime> upsertHouse(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) async {
    final result = await _withTrace(
      sentryTrace,
      () => _client.from('houses').upsert(data).select('updated_at'),
    );
    return _parseServerUpdatedAt(result, entity: 'house');
  }

  // === ITEMS ===

  /// Restituisce TUTTE le righe dell'utente (incluse `is_deleted = true`):
  /// vedi [fetchAllHousesByUserId].
  Future<List<Map<String, dynamic>>> fetchAllItemsByUserId(String userId) {
    return _withTrace(
      null,
      () => paginatedFetch(
        fetchPage: (from, to) async => List<Map<String, dynamic>>.from(
          await _client
              .from('items')
              .select()
              .eq('user_id', userId)
              .range(from, to),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> fetchItemById(
    String id, {
    String? sentryTrace,
  }) {
    return _withTrace(
      sentryTrace,
      () => _client.from('items').select().eq('id', id).maybeSingle(),
    );
  }

  Future<DateTime> upsertItem(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) async {
    final result = await _withTrace(
      sentryTrace,
      () => _client.from('items').upsert(data).select('updated_at'),
    );
    return _parseServerUpdatedAt(result, entity: 'item');
  }

  // === SPACES ===

  /// Restituisce TUTTE le righe dell'utente (incluse `is_deleted = true`):
  /// vedi [fetchAllHousesByUserId]. Paginato.
  Future<List<Map<String, dynamic>>> fetchAllSpacesByUserId(String userId) {
    return _withTrace(
      null,
      () => paginatedFetch(
        fetchPage: (from, to) async => List<Map<String, dynamic>>.from(
          await _client
              .from('spaces')
              .select()
              .eq('user_id', userId)
              .range(from, to),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> fetchSpaceById(
    String id, {
    String? sentryTrace,
  }) {
    return _withTrace(
      sentryTrace,
      () => _client.from('spaces').select().eq('id', id).maybeSingle(),
    );
  }

  Future<DateTime> upsertSpace(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) async {
    final result = await _withTrace(
      sentryTrace,
      () => _client.from('spaces').upsert(data).select('updated_at'),
    );
    return _parseServerUpdatedAt(result, entity: 'space');
  }

  // === LUGGAGES ===

  /// Restituisce TUTTE le righe dell'utente (incluse `is_deleted = true`):
  /// vedi [fetchAllHousesByUserId]. Paginato.
  Future<List<Map<String, dynamic>>> fetchAllLuggagesByUserId(String userId) {
    return _withTrace(
      null,
      () => paginatedFetch(
        fetchPage: (from, to) async => List<Map<String, dynamic>>.from(
          await _client
              .from('luggages')
              .select()
              .eq('user_id', userId)
              .range(from, to),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> fetchLuggageById(
    String id, {
    String? sentryTrace,
  }) {
    return _withTrace(
      sentryTrace,
      () => _client.from('luggages').select().eq('id', id).maybeSingle(),
    );
  }

  Future<DateTime> upsertLuggage(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) async {
    final result = await _withTrace(
      sentryTrace,
      () => _client.from('luggages').upsert(data).select('updated_at'),
    );
    return _parseServerUpdatedAt(result, entity: 'luggage');
  }

  // === TRIPS ===

  /// Restituisce TUTTE le righe dell'utente (incluse `is_deleted = true`):
  /// vedi [fetchAllHousesByUserId].
  Future<List<Map<String, dynamic>>> fetchAllTripsByUserId(String userId) {
    return _withTrace(
      null,
      () => paginatedFetch(
        fetchPage: (from, to) async => List<Map<String, dynamic>>.from(
          await _client
              .from('trips')
              .select()
              .eq('user_id', userId)
              .range(from, to),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> fetchTripById(
    String id, {
    String? sentryTrace,
  }) {
    return _withTrace(
      sentryTrace,
      () => _client.from('trips').select().eq('id', id).maybeSingle(),
    );
  }

  Future<DateTime> upsertTrip(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) async {
    final result = await _withTrace(
      sentryTrace,
      () => _client.from('trips').upsert(data).select('updated_at'),
    );
    return _parseServerUpdatedAt(result, entity: 'trip');
  }

  // === HELPERS ===

  /// Estrae `updated_at` ufficiale del server dal risultato di un upsert.
  ///
  /// PostgREST con `.upsert(...).select('updated_at')` ritorna una lista
  /// (un elemento per riga inserita/aggiornata). Per i nostri upsert
  /// single-row la lista ha sempre 1 elemento; in caso anomalo (lista
  /// vuota, formato inatteso) lanciamo `StateError` per far fallire fast
  /// l'operazione e permettere all'orchestrator di gestirla via retry.
  DateTime _parseServerUpdatedAt(dynamic raw, {required String entity}) {
    if (raw is! List || raw.isEmpty) {
      throw StateError(
        'upsert $entity: expected non-empty list with updated_at, got: $raw',
      );
    }
    final first = raw.first as Map<String, dynamic>;
    final value = first['updated_at'];
    if (value is! String) {
      throw StateError(
        'upsert $entity: missing or non-string updated_at in $first',
      );
    }
    return DateTime.parse(value).toUtc();
  }

  /// Injects sentry-trace header into the REST client for the duration of [fn].
  ///
  /// Safe because sync runs single-threaded behind a mutex — no concurrent
  /// queries will see the injected header.
  Future<T> _withTrace<T>(String? sentryTrace, Future<T> Function() fn) async {
    if (sentryTrace != null) {
      _client.rest.headers['sentry-trace'] = sentryTrace;
    }
    try {
      return await fn();
    } finally {
      _client.rest.headers.remove('sentry-trace');
    }
  }
}
