import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/trip_weather_provider.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_weather.dart';

TripModel _viaggio({required DateTime departure, required DateTime returnAt}) {
  return TripModel(
    id: 'v1',
    name: 'Viaggio',
    departureDateTime: departure,
    returnDateTime: returnAt,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    isSaved: false,
    items: const [],
    legs: const [],
  );
}

/// Meteo finto: conta le letture e risponde "non riuscito", che la sezione
/// mostra sempre con il suo titolo.
class _FakeWeather extends TripWeatherNotifier {
  _FakeWeather(this.reads);
  final List<String> reads;

  @override
  Future<TripWeatherState> build(String tripId) async {
    reads.add(tripId);
    return const TripWeatherFailed();
  }
}

void main() {
  Future<List<String>> pump(WidgetTester tester, TripModel trip) async {
    final reads = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripWeatherNotifierProvider(
            trip.id,
          ).overrideWith(() => _FakeWeather(reads)),
        ],
        child: MaterialApp(
          home: Scaffold(body: PackWeatherSection(trip: trip)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return reads;
  }

  testWidgets('viaggio finito da un mese: niente meteo e nessuna richiesta', (
    tester,
  ) async {
    final now = DateTime.now();
    final reads = await pump(
      tester,
      _viaggio(
        departure: now.subtract(const Duration(days: 40)),
        returnAt: now.subtract(const Duration(days: 30)),
      ),
    );
    expect(find.byKey(const Key('pack_weather')), findsNothing);
    expect(reads, isEmpty);
  });

  testWidgets('viaggio finito un\'ora fa: già niente meteo', (tester) async {
    final now = DateTime.now();
    final reads = await pump(
      tester,
      _viaggio(
        departure: now.subtract(const Duration(days: 3)),
        returnAt: now.subtract(const Duration(hours: 1)),
      ),
    );
    expect(find.byKey(const Key('pack_weather')), findsNothing);
    expect(reads, isEmpty);
  });

  testWidgets('viaggio in corso: la sezione c\'è', (tester) async {
    final now = DateTime.now();
    final reads = await pump(
      tester,
      _viaggio(
        departure: now.subtract(const Duration(days: 1)),
        returnAt: now.add(const Duration(days: 2)),
      ),
    );
    expect(find.byKey(const Key('pack_weather')), findsOneWidget);
    expect(reads, ['v1']);
  });
}
