import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/pack_trip_job.dart';
import 'package:pack_log/features/trips/model/pack_wait_facts.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../helpers/memory_asset_loader.dart';

StopWeather _stop({double? min, double? max, double? rain}) => StopWeather(
  name: 'X',
  from: DateTime(2026, 11, 10),
  to: DateTime(2026, 11, 12),
  source: WeatherSource.climate,
  tempMin: min,
  tempMax: max,
  rainDays: rain,
);

TripWeather _weather(List<StopWeather> stops) =>
    TripWeather(signature: 's', fetchedAt: DateTime(2026, 11, 1), stops: stops);

PackTripJob _job(Map<String, dynamic> trip, {int nights = 4}) =>
    PackTripJob(body: {'trip': trip}, houseId: 'h', title: 'T', nights: nights);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> loc(WidgetTester tester, String code) async {
    caricaCatalogoDelRepo(lingua: code);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        assetLoader: MemoryAssetLoader(readAppTranslations()),
        fallbackLocale: const Locale('en', 'US'),
        startLocale: code == 'it'
            ? const Locale('it', 'IT')
            : const Locale('en', 'US'),
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: const SizedBox(),
          ),
        ),
      ),
    );
  }

  group('meteo', () {
    testWidgets('con pioggia: minime, massime e giorni arrotondati', (
      tester,
    ) async {
      await loc(tester, 'it');
      final facts = packWaitFacts(
        job: _job({}),
        weather: _weather([_stop(min: 3.4, max: 11.6, rain: 4.5)]),
        itemCount: 10,
      );
      expect(facts.weather, '3–12°, 5 giorni di pioggia');
    });

    testWidgets('più tappe: minimo, massimo e somma della pioggia', (
      tester,
    ) async {
      await loc(tester, 'it');
      final facts = packWaitFacts(
        job: _job({}),
        weather: _weather([
          _stop(min: 5, max: 10, rain: 1),
          _stop(min: 2, max: 14, rain: 1),
        ]),
        itemCount: 10,
      );
      expect(facts.weather, '2–14°, 2 giorni di pioggia');
    });

    testWidgets('un giorno di pioggia al singolare', (tester) async {
      await loc(tester, 'it');
      final facts = packWaitFacts(
        job: _job({}),
        weather: _weather([_stop(min: 5, max: 10, rain: 1)]),
        itemCount: 10,
      );
      expect(facts.weather, '5–10°, 1 giorno di pioggia');
    });

    testWidgets('senza pioggia: solo le temperature', (tester) async {
      await loc(tester, 'it');
      final facts = packWaitFacts(
        job: _job({}),
        weather: _weather([_stop(min: 18, max: 27, rain: 0)]),
        itemCount: 10,
      );
      expect(facts.weather, '18–27°');
    });

    testWidgets('senza meteo o senza temperature: nessuna riga', (
      tester,
    ) async {
      await loc(tester, 'it');
      expect(
        packWaitFacts(job: _job({}), weather: null, itemCount: 1).weather,
        isNull,
      );
      expect(
        packWaitFacts(
          job: _job({}),
          weather: _weather([_stop(rain: 2)]),
          itemCount: 1,
        ).weather,
        isNull,
      );
    });

    testWidgets('in inglese', (tester) async {
      await loc(tester, 'en');
      final facts = packWaitFacts(
        job: _job({}),
        weather: _weather([_stop(min: 3, max: 11, rain: 2)]),
        itemCount: 1,
      );
      expect(facts.weather, '3–11°, 2 rainy days');
    });
  });

  group('armadio', () {
    testWidgets('pieno, vuoto e sconosciuto', (tester) async {
      await loc(tester, 'it');
      expect(
        packWaitFacts(job: _job({}), weather: null, itemCount: 42).wardrobe,
        '42 capi guardati',
      );
      expect(
        packWaitFacts(job: _job({}), weather: null, itemCount: 1).wardrobe,
        '1 capo guardato',
      );
      expect(
        packWaitFacts(job: _job({}), weather: null, itemCount: 0).wardrobe,
        'Armadio vuoto: preparo le proposte',
      );
      expect(
        packWaitFacts(job: _job({}), weather: null, itemCount: null).wardrobe,
        isNull,
      );
    });
  });

  group('cosa manca', () {
    testWidgets('senza attività: solo le notti', (tester) async {
      await loc(tester, 'it');
      final facts = packWaitFacts(
        job: _job({'attivita': <String>[]}),
        weather: null,
        itemCount: 1,
      );
      expect(facts.check, '4 notti');
    });

    testWidgets('una attività', (tester) async {
      await loc(tester, 'it');
      final facts = packWaitFacts(
        job: _job({
          'attivita': ['trekking'],
        }),
        weather: null,
        itemCount: 1,
      );
      expect(facts.check, 'Trekking, 4 notti');
    });

    testWidgets('tre attività: le prime due e "altro"', (tester) async {
      await loc(tester, 'it');
      final facts = packWaitFacts(
        job: _job({
          'attivita': ['city', 'trekking', 'walks'],
        }),
        weather: null,
        itemCount: 1,
      );
      expect(facts.check, 'Città e musei e Trekking e altro, 4 notti');
    });

    testWidgets('due attività e più tappe, senza doppioni', (tester) async {
      await loc(tester, 'it');
      final facts = packWaitFacts(
        job: _job({
          'tappe': [
            {
              'attivita': ['city'],
            },
            {
              'attivita': ['city', 'trekking'],
            },
          ],
        }),
        weather: null,
        itemCount: 1,
      );
      expect(facts.check, 'Città e musei e Trekking, 4 notti');
    });

    testWidgets('senza notti né attività: nessuna riga', (tester) async {
      await loc(tester, 'it');
      final facts = packWaitFacts(
        job: _job({}, nights: 0),
        weather: null,
        itemCount: 1,
      );
      expect(facts.check, isNull);
    });
  });
}
