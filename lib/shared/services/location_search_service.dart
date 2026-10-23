import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/houses/model/house_model.dart';
import '../../features/houses/providers/house_provider.dart';
import '../config/app_config.dart';
import '../model/model.dart';
import 'location_ranking.dart';

part 'location_search_service.g.dart';

/// Roma è il riferimento quando nessuna casa ha coordinate utilizzabili.
const defaultLocationSearchBias = 'proximity:12.4964,41.9028';

/// Preferisce la casa principale, poi la prima casa localizzata nell'ordine
/// della lista. Non usa la posizione del dispositivo né filtra i risultati.
String locationSearchBias(Iterable<HouseModel> houses) {
  String? firstLocalized;
  for (final house in houses) {
    final lat = house.location?.lat;
    final lon = house.location?.lon;
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      continue;
    }
    final bias = 'proximity:$lon,$lat';
    if (house.isPrimary) return bias;
    firstLocalized ??= bias;
  }
  return firstLocalized ?? defaultLocationSearchBias;
}

/// Il proxy ha risposto 429: il chiamante lo distingue dagli altri errori per
/// mostrare un messaggio specifico.
class GeocodeRateLimitException implements Exception {
  const GeocodeRateLimitException();
}

/// Ricerca non completata: non equivale a una risposta senza risultati.
class GeocodeSearchException implements Exception {
  const GeocodeSearchException();
}

/// Ricerca di città, regioni e paesi tramite il proxy `geocode-proxy`.
class LocationSearchService {
  const LocationSearchService({this.bias = defaultLocationSearchBias});

  final String bias;

  /// Suggerimenti per [query] nella lingua [lang] (es. `it`, `en`).
  ///
  /// Lista vuota solo se la ricerca non trova luoghi. Gli errori sono
  /// [GeocodeSearchException] o [GeocodeRateLimitException].
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
            'bias': bias,
          },
        );

    final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
    if (jwt == null) throw const GeocodeSearchException();

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $jwt',
              'apikey': AppConfig.supabaseAnonKey,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 429) {
        throw const GeocodeRateLimitException();
      }

      if (response.statusCode != 200) {
        throw const GeocodeSearchException();
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
    } catch (_) {
      throw const GeocodeSearchException();
    }
  }
}

@Riverpod(keepAlive: true)
LocationSearchService locationSearchService(Ref ref) {
  final bias = ref
      .watch(houseNotifierProvider)
      .when(
        data: locationSearchBias,
        loading: () => defaultLocationSearchBias,
        error: (_, _) => defaultLocationSearchBias,
      );
  return LocationSearchService(bias: bias);
}
