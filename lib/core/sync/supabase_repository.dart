import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRepository {
  final SupabaseClient _client;

  SupabaseRepository(this._client);

  // === HOUSES ===

  Future<List<Map<String, dynamic>>> fetchAllHousesByUserId(String userId) {
    return _withTrace(
      null,
      () async => List<Map<String, dynamic>>.from(
        await _client
            .from('houses')
            .select()
            .eq('user_id', userId)
            .eq('is_deleted', false),
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

  Future<void> upsertHouse(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) async {
    final result = await _withTrace(
      sentryTrace,
      () => _client.from('houses').upsert(data).select(),
    );
    debugPrint('[SupabaseRepo] upsertHouse result: $result');
  }

  // === ITEMS ===

  Future<List<Map<String, dynamic>>> fetchAllItemsByUserId(String userId) {
    return _withTrace(
      null,
      () async => List<Map<String, dynamic>>.from(
        await _client
            .from('items')
            .select()
            .eq('user_id', userId)
            .eq('is_deleted', false),
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

  Future<void> upsertItem(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) async {
    final result = await _withTrace(
      sentryTrace,
      () => _client.from('items').upsert(data).select(),
    );
    debugPrint('[SupabaseRepo] upsertItem result: $result');
  }

  // === TRIPS ===

  Future<List<Map<String, dynamic>>> fetchAllTripsByUserId(String userId) {
    return _withTrace(
      null,
      () async => List<Map<String, dynamic>>.from(
        await _client
            .from('trips')
            .select()
            .eq('user_id', userId)
            .eq('is_deleted', false),
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

  Future<void> upsertTrip(
    Map<String, dynamic> data, {
    String? sentryTrace,
  }) async {
    final result = await _withTrace(
      sentryTrace,
      () => _client.from('trips').upsert(data).select(),
    );
    debugPrint('[SupabaseRepo] upsertTrip result: $result');
  }

  // === HELPERS ===

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
