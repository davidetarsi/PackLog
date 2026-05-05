import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRepository {
  final SupabaseClient _client;

  SupabaseRepository(this._client);

  // === HOUSES ===

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
  }) {
    return _withTrace(
      sentryTrace,
      () => _client.from('houses').upsert(data),
    );
  }

  // === ITEMS ===

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
  }) {
    return _withTrace(
      sentryTrace,
      () => _client.from('items').upsert(data),
    );
  }

  // === TRIPS ===

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
  }) {
    return _withTrace(
      sentryTrace,
      () => _client.from('trips').upsert(data),
    );
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
