import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/config/app_config.dart';
import '../model/trip_weather.dart';

part 'trip_weather_service.g.dart';

/// La funzione ha risposto 429: il tetto giornaliero dell'utente è finito.
class TripWeatherCapException implements Exception {
  const TripWeatherCapException();
}

/// Meteo non arrivato: rete, sessione o errore della funzione.
class TripWeatherException implements Exception {
  const TripWeatherException(this.message);

  final String message;

  @override
  String toString() => 'TripWeatherException: $message';
}

/// Il meteo di un viaggio dalla funzione `trip-weather`.
class TripWeatherService {
  /// Chiede il meteo di [request]. Solleva [TripWeatherCapException] con il
  /// tetto finito, [TripWeatherException] per tutto il resto.
  Future<TripWeather> fetch(TripWeatherRequest request) async {
    // La funzione conta le chiamate per utente: serve il JWT della sessione.
    final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
    if (jwt == null) throw const TripWeatherException('nessuna sessione');

    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('${AppConfig.supabaseUrl}/functions/v1/trip-weather'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'apikey': AppConfig.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );
    } catch (e) {
      throw TripWeatherException('rete: $e');
    }

    if (response.statusCode == 429) throw const TripWeatherCapException();
    if (response.statusCode != 200) {
      debugPrint(
        '[TripWeatherService] HTTP ${response.statusCode}: ${response.body}',
      );
      throw TripWeatherException('HTTP ${response.statusCode}');
    }

    try {
      return TripWeather.fromResponse(
        jsonDecode(response.body) as Map<String, dynamic>,
        request: request,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      throw TripWeatherException('risposta non valida: $e');
    }
  }
}

/// L'ultimo meteo di ogni viaggio, in [SharedPreferences].
///
/// Il tetto giornaliero della funzione conta anche le risposte che il server
/// ha in cache: per non consumarlo, l'app tiene la sua copia e non richiama
/// finché è fresca (vedi [TripWeather.isFresh]).
class TripWeatherCache {
  static const _prefix = 'trip_weather.v1.';

  Future<TripWeather?> read(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$tripId');
      if (raw == null) return null;
      return TripWeather.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // Una copia illeggibile vale come nessuna copia.
      debugPrint('[TripWeatherCache] lettura fallita: $e');
      return null;
    }
  }

  Future<void> write(String tripId, TripWeather weather) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$tripId', jsonEncode(weather.toJson()));
    } catch (e) {
      debugPrint('[TripWeatherCache] scrittura fallita: $e');
    }
  }
}

@Riverpod(keepAlive: true)
TripWeatherService tripWeatherService(Ref ref) => TripWeatherService();

@Riverpod(keepAlive: true)
TripWeatherCache tripWeatherCache(Ref ref) => TripWeatherCache();
