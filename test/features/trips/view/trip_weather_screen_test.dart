import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/trip_weather_provider.dart';
import 'package:pack_log/features/trips/view/trip_weather_screen.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_asset_loader.dart';

class _Ready extends TripWeatherNotifier {
  _Ready(this.stop);
  final StopWeather stop;

  @override
  Future<TripWeatherState> build(String tripId) async => TripWeatherReady(
    TripWeather(signature: 's', fetchedAt: DateTime.now(), stops: [stop]),
  );
}

StopWeather _stima({List<HistoricalDayWeather>? days, int? years = 5}) =>
    StopWeather(
      name: 'Lisbona',
      from: DateTime(2027, 7, 1),
      to: DateTime(2027, 7, 3),
      source: WeatherSource.climate,
      years: years,
      tempMin: 15,
      tempMax: 24,
      historicalDays:
          days ??
          [
            HistoricalDayWeather(
              date: DateTime(2027, 7, 1),
              tempMax: 24.4,
              tempMin: 15.2,
              windMaxKmh: 21,
              rainYears: 2,
              dataYears: 5,
            ),
            HistoricalDayWeather(
              date: DateTime(2027, 7, 2),
              tempMax: 25,
              tempMin: 16,
              rainYears: 1,
              dataYears: 4,
            ),
            HistoricalDayWeather(date: DateTime(2027, 7, 3)),
          ],
    );

void main() {
  const it = Locale('it', 'IT');
  const en = Locale('en', 'US');

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pump(WidgetTester tester, StopWeather stop, Locale locale) {
    return tester
        .pumpWidget(
          ProviderScope(
            overrides: [
              tripWeatherNotifierProvider(
                't1',
              ).overrideWith(() => _Ready(stop)),
            ],
            child: EasyLocalization(
              supportedLocales: const [it, en],
              path: 'assets/translations',
              assetLoader: MemoryAssetLoader(readAppTranslations()),
              fallbackLocale: en,
              startLocale: locale,
              saveLocale: false,
              child: Builder(
                builder: (context) => MaterialApp(
                  theme: AppTheme.light,
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: const TripWeatherScreen(tripId: 't1', stopIndex: 0),
                ),
              ),
            ),
          ),
        )
        .then((_) => tester.pumpAndSettle());
  }

  testWidgets('stima in italiano: etichetta, medie e pioggia anni su N', (
    tester,
  ) async {
    await pump(tester, _stima(), it);
    expect(find.text('Media degli ultimi 5 anni'), findsOneWidget);
    expect(find.text('15° / 24°'), findsOneWidget);
    expect(find.text('16° / 25°'), findsOneWidget);
    expect(
      find.text('Pioggia 2 anni su 5 · vento fino a 21 km/h'),
      findsOneWidget,
    );
    expect(find.text('Pioggia 1 anno su 4'), findsOneWidget);
    // niente icona del tempo, e il giorno senza dati non scrive la pioggia
    expect(find.byType(Icon), findsNothing);
    expect(find.textContaining('Pioggia'), findsNWidgets(2));
  });

  testWidgets('stima in inglese: plurali', (tester) async {
    await pump(tester, _stima(), en);
    expect(find.text('Average of the last 5 years'), findsOneWidget);
    expect(find.textContaining('Rain 2 years out of 5'), findsOneWidget);
    expect(find.text('Rain 1 year out of 4'), findsOneWidget);
  });

  testWidgets('senza anni nella tappa usa quelli dei giorni', (tester) async {
    await pump(tester, _stima(years: null), it);
    expect(find.text('Media degli ultimi 5 anni'), findsOneWidget);
  });

  testWidgets('senza giorni ne storici ne di previsione: dettaglio mancante', (
    tester,
  ) async {
    await pump(tester, _stima(days: const []), it);
    expect(
      find.text('Il dettaglio di questa tappa non è disponibile.'),
      findsOneWidget,
    );
  });
}
