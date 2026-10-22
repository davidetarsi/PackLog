import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../model/model.dart';
import 'location_ranking.dart';

part 'location_search_service.g.dart';

/// Il proxy ha risposto 429: il chiamante lo distingue dagli altri errori per
/// mostrare un messaggio specifico.
class GeocodeRateLimitException implements Exception {
  const GeocodeRateLimitException();
}

/// Ricerca di città, regioni e paesi tramite il proxy `geocode-proxy`.
class LocationSearchService {
  /// Suggerimenti per [query] nella lingua [lang] (es. `it`, `en`).
  ///
  /// Lista vuota senza sessione o in caso di errore. Solleva
  /// [GeocodeRateLimitException] solo quando il proxy risponde 429.
  Future<List<LocationSuggestionModel>> search(
    String query, {
    required String lang,
  }) async {
    final uri = Uri.parse('${AppConfig.supabaseUrl}/functions/v1/geocode-proxy')
        .replace(
          queryParameters: {
            'text': query,
            'lang': lang.substring(0, 2),
            'limit': '15',
            'bias': 'countrycode:none',
          },
        );

    // Il proxy esegue `getUser(token)` per il rate-limit per-utente: serve
    // il JWT dell'utente loggato, non l'anon key. L'auth gate del router
    // garantisce che chiunque possa raggiungere questo widget sia loggato;
    // in caso edge di sessione scaduta tra il check e qui, ritorniamo
    // suggestion vuoti senza errori — l'utente proverà a digitare ancora.
    final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
    if (jwt == null) return [];

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $jwt',
          'apikey': AppConfig.supabaseAnonKey,
        },
      );

      if (response.statusCode == 429) {
        throw const GeocodeRateLimitException();
      }

      if (response.statusCode != 200) {
        throw Exception('Errore HTTP Geoapify: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final geoapifyResponse = GeoapifyResponseModel.fromJson(json);

      final suggestions = geoapifyResponse.features
          .map(
            (feature) => LocationSuggestionModel.fromGeoapifyFeature(feature),
          )
          .where((s) => s.displayName.isNotEmpty)
          // ARCHITECTURE CHOICE: Filtro applicativo per garantire solo macro-aree.
          // Scartiamo tutto ciò che finisce nel bucket 'other' (strade, ristoranti, etc.)
          .where((s) => s.locationType != LocationType.other)
          .toList();

      final seen = <String>{};
      final uniqueSuggestions = <LocationSuggestionModel>[];

      for (final suggestion in suggestions) {
        if (seen.add(suggestion.deduplicationKey)) {
          uniqueSuggestions.add(suggestion);
        }
      }

      return rankLocationSuggestions(query, uniqueSuggestions).take(5).toList();
    } on GeocodeRateLimitException {
      rethrow;
    } catch (e) {
      // In produzione, loggare l'errore su Crashlytics/Sentry, non stamparlo solo in console
      debugPrint('[LocationSearchService] Errore API: $e');
      return [];
    }
  }
}

@Riverpod(keepAlive: true)
LocationSearchService locationSearchService(Ref ref) => LocationSearchService();
