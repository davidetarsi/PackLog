import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/trips/services/open_meteo_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;
  late OpenMeteoService service;

  setUp(() {
    mockClient = MockHttpClient();
    service = OpenMeteoService(client: mockClient);
    registerFallbackValue(Uri());
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  http.Response _mockResponse(Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), 200);

  Map<String, dynamic> _buildDailyPayload({
    required List<double> maxTemps,
    required List<double> minTemps,
    required List<int> weatherCodes,
  }) {
    return {
      'daily': {
        'temperature_2m_max': maxTemps,
        'temperature_2m_min': minTemps,
        'weather_code': weatherCodes,
      },
    };
  }

  // ── Tests ─────────────────────────────────────────────────────────────────

  group('OpenMeteoService - fetchWeather', () {
    group('Forecast path (trip < 14 days away)', () {
      test('calls forecast endpoint and parses avgTemp + tags correctly', () async {
        // Trip departs tomorrow → forecast path
        final startDate = DateTime.now().add(const Duration(days: 1));
        final endDate = startDate.add(const Duration(days: 3));

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => _mockResponse(
            _buildDailyPayload(
              maxTemps: [20.0, 22.0, 18.0],
              minTemps: [10.0, 12.0, 8.0],
              weatherCodes: [0, 0, 1], // clear sky → Sunny
            ),
          ),
        );

        final result = await service.fetchWeather(
          lat: 48.8566,
          lon: 2.3522,
          startDate: startDate,
          endDate: endDate,
        );

        // avgTemp = mean of [(20+10)/2, (22+12)/2, (18+8)/2] = [15, 17, 13] → 15
        expect(result.avgTemp, equals(15));
        expect(result.weatherTags, equals(['Sunny']));

        // Verify forecast endpoint was used
        final captured = verify(() => mockClient.get(captureAny())).captured;
        final uri = captured.first as Uri;
        expect(uri.host, equals('api.open-meteo.com'));
      });

      test('maps rainy weather codes to [Rain] tag', () async {
        final startDate = DateTime.now().add(const Duration(days: 2));
        final endDate = startDate.add(const Duration(days: 1));

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => _mockResponse(
            _buildDailyPayload(
              maxTemps: [15.0, 14.0],
              minTemps: [8.0, 7.0],
              weatherCodes: [61, 63], // rain
            ),
          ),
        );

        final result = await service.fetchWeather(
          lat: 51.5,
          lon: -0.1,
          startDate: startDate,
          endDate: endDate,
        );

        expect(result.weatherTags, equals(['Rain']));
      });

      test('maps snow codes to [Snow, Cold] tags', () async {
        final startDate = DateTime.now().add(const Duration(days: 1));
        final endDate = startDate;

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => _mockResponse(
            _buildDailyPayload(
              maxTemps: [-2.0],
              minTemps: [-8.0],
              weatherCodes: [73],
            ),
          ),
        );

        final result = await service.fetchWeather(
          lat: 47.0,
          lon: 11.0,
          startDate: startDate,
          endDate: endDate,
        );

        expect(result.weatherTags, containsAll(['Snow', 'Cold']));
      });
    });

    group('Historical proxy path (trip > 14 days away)', () {
      test('calls archive endpoint for trips more than 14 days away', () async {
        final startDate = DateTime.now().add(const Duration(days: 30));
        final endDate = startDate.add(const Duration(days: 7));

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => _mockResponse(
            _buildDailyPayload(
              maxTemps: [28.0, 30.0, 27.0],
              minTemps: [20.0, 22.0, 19.0],
              weatherCodes: [0, 1, 0],
            ),
          ),
        );

        final result = await service.fetchWeather(
          lat: 41.9,
          lon: 12.5,
          startDate: startDate,
          endDate: endDate,
        );

        final captured = verify(() => mockClient.get(captureAny())).captured;
        final uri = captured.first as Uri;
        expect(uri.host, equals('archive-api.open-meteo.com'));
        // avgTemp = [(28+20)/2, (30+22)/2, (27+19)/2] = [24, 26, 23] → 24
        expect(result.avgTemp, equals(24));
      });
    });

    group('avgTemp computation', () {
      test('single day: correctly computes (max + min) / 2', () async {
        final startDate = DateTime.now().add(const Duration(days: 1));

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => _mockResponse(
            _buildDailyPayload(
              maxTemps: [30.0],
              minTemps: [20.0],
              weatherCodes: [0],
            ),
          ),
        );

        final result = await service.fetchWeather(
          lat: 0,
          lon: 0,
          startDate: startDate,
          endDate: startDate,
        );

        expect(result.avgTemp, equals(25)); // (30+20)/2
      });

      test('uses most frequent weather code for tags', () async {
        final startDate = DateTime.now().add(const Duration(days: 1));
        final endDate = startDate.add(const Duration(days: 4));

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => _mockResponse(
            _buildDailyPayload(
              maxTemps: [10.0, 12.0, 11.0, 13.0, 9.0],
              minTemps: [2.0, 3.0, 2.0, 4.0, 1.0],
              // 3× code 61 (rain), 2× code 0 (sunny) → rain wins
              weatherCodes: [0, 61, 61, 0, 61],
            ),
          ),
        );

        final result = await service.fetchWeather(
          lat: 0,
          lon: 0,
          startDate: startDate,
          endDate: endDate,
        );

        expect(result.weatherTags, equals(['Rain']));
      });
    });

    group('Error handling', () {
      test('throws on non-200 HTTP status', () async {
        final startDate = DateTime.now().add(const Duration(days: 1));

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response('Internal Server Error', 500),
        );

        expect(
          () => service.fetchWeather(
            lat: 0,
            lon: 0,
            startDate: startDate,
            endDate: startDate,
          ),
          throwsException,
        );
      });

      test('throws FormatException when "daily" key is missing', () async {
        final startDate = DateTime.now().add(const Duration(days: 1));

        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(jsonEncode({'latitude': 0.0}), 200),
        );

        expect(
          () => service.fetchWeather(
            lat: 0,
            lon: 0,
            startDate: startDate,
            endDate: startDate,
          ),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
