import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/weather_mapper.dart';

part 'open_meteo_service.g.dart';

/// Result type returned by [OpenMeteoService.fetchWeather].
typedef WeatherResult = ({int avgTemp, List<String> weatherTags});

/// Service that fetches weather data from the Open-Meteo API (no API key).
///
/// Strategy:
/// - **Forecast** (`api.open-meteo.com/v1/forecast`): used when the trip
///   departure is within the next 14 days (reliable short-range forecast).
/// - **Historical proxy** (`archive-api.open-meteo.com/v1/archive`): used
///   when the trip is more than 14 days away — the same calendar dates
///   from exactly one year ago are fetched as a seasonal estimate.
///
/// Inject a custom [http.Client] via the constructor for unit testing.
class OpenMeteoService {
  final http.Client _client;

  OpenMeteoService({http.Client? client}) : _client = client ?? http.Client();

  static const _forecastBase = 'api.open-meteo.com';
  static const _archiveBase = 'archive-api.open-meteo.com';
  static const _forecastThresholdDays = 14;

  /// Fetches average temperature and weather tags for the given trip window.
  ///
  /// [startDate] and [endDate] define the trip window. If [endDate] is the
  /// same as [startDate] a single-day request is made.
  ///
  /// Throws on HTTP errors or malformed responses; callers are expected to
  /// wrap this in a try/catch with a timeout.
  Future<WeatherResult> fetchWeather({
    required double lat,
    required double lon,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final daysUntilDeparture = startDate.difference(DateTime.now()).inDays;
    final bool useForecast = daysUntilDeparture < _forecastThresholdDays;

    final DateTime queryStart;
    final DateTime queryEnd;

    if (useForecast) {
      queryStart = startDate;
      queryEnd = endDate.isBefore(startDate) ? startDate : endDate;
    } else {
      // Historical proxy: same calendar window exactly one year ago.
      queryStart = startDate.subtract(const Duration(days: 365));
      queryEnd = endDate.isBefore(startDate)
          ? queryStart
          : endDate.subtract(const Duration(days: 365));
    }

    final uri = Uri.https(
      useForecast ? _forecastBase : _archiveBase,
      useForecast ? '/v1/forecast' : '/v1/archive',
      {
        'latitude': lat.toStringAsFixed(4),
        'longitude': lon.toStringAsFixed(4),
        'start_date': _formatDate(queryStart),
        'end_date': _formatDate(queryEnd),
        'daily': 'temperature_2m_max,temperature_2m_min,weather_code',
        'timezone': 'auto',
      },
    );

    debugPrint('[OpenMeteo] ${useForecast ? "forecast" : "historical"} → $uri');

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        '[OpenMeteo] HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseResponse(json);
  }

  // ── Parsing ──────────────────────────────────────────────────────────────

  WeatherResult _parseResponse(Map<String, dynamic> json) {
    final daily = json['daily'] as Map<String, dynamic>?;
    if (daily == null) {
      throw const FormatException('[OpenMeteo] Missing "daily" key in response');
    }

    final maxTemps = (daily['temperature_2m_max'] as List?)
        ?.whereType<num>()
        .map((v) => v.toDouble())
        .toList();
    final minTemps = (daily['temperature_2m_min'] as List?)
        ?.whereType<num>()
        .map((v) => v.toDouble())
        .toList();
    final weatherCodes = (daily['weather_code'] as List?)
        ?.whereType<num>()
        .map((v) => v.toInt())
        .toList();

    if (maxTemps == null ||
        minTemps == null ||
        weatherCodes == null ||
        maxTemps.isEmpty) {
      throw const FormatException('[OpenMeteo] Empty or missing daily arrays');
    }

    // Average of daily means ((max + min) / 2) across all days.
    double totalTemp = 0;
    for (int i = 0; i < maxTemps.length; i++) {
      final min = i < minTemps.length ? minTemps[i] : maxTemps[i];
      totalTemp += (maxTemps[i] + min) / 2;
    }
    final avgTemp = (totalTemp / maxTemps.length).round();

    // Most frequent weather code → tags.
    final dominantCode = _mostFrequent(weatherCodes);
    final tags = mapWmoCodeToTags(dominantCode);

    return (avgTemp: avgTemp, weatherTags: tags);
  }

  /// Returns the most frequent element in [values]; on tie, the first wins.
  int _mostFrequent(List<int> values) {
    final counts = <int, int>{};
    for (final v in values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    return counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Formats [DateTime] as `yyyy-MM-dd` without relying on the `intl` package.
  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// Riverpod provider — overridable in tests via `ProviderScope(overrides:...)`.
@riverpod
OpenMeteoService openMeteoService(Ref ref) => OpenMeteoService();
