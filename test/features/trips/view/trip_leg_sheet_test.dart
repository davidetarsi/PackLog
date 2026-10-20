import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/view/widgets/trip_calendar.dart';
import 'package:pack_log/features/trips/view/widgets/trip_leg_sheet.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/services/location_search_service.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_asset_loader.dart';

/// Servizio dei luoghi senza rete: la ricerca non trova nulla. Il foglio
/// costruisce `LocationAutocompleteField`, che lo legge dal provider.
class _FakeLocationSearchService extends LocationSearchService {
  @override
  Future<List<LocationSuggestionModel>> search(
    String query, {
    required String lang,
  }) async => const [];
}

late AssetLoader _assetLoader;

DateTime _daysFromToday(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days);
}

Finder _dayFinder(DateTime day) => find.byKey(
  ValueKey('trip_calendar_day_${DateFormat('yyyy-MM-dd').format(day)}'),
);

/// Scorre il calendario fino al giorno e lo tocca.
Future<void> _tapDay(WidgetTester tester, DateTime day) async {
  final finder = _dayFinder(day);
  await tester.scrollUntilVisible(
    finder,
    50,
    scrollable: find.descendant(
      of: find.byType(TripCalendar),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Monta un pulsante che apre il foglio tramite [open], con le traduzioni
/// reali e il servizio dei luoghi finto.
Future<void> _pumpHost(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open,
) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
      path: 'assets/translations',
      assetLoader: _assetLoader,
      fallbackLocale: const Locale('en', 'US'),
      startLocale: const Locale('it', 'IT'),
      saveLocale: false,
      child: ProviderScope(
        overrides: [
          locationSearchServiceProvider.overrideWithValue(
            _FakeLocationSearchService(),
          ),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.light,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => open(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    _assetLoader = MemoryAssetLoader(readAppTranslations());
  });

  // Niente asserzioni su testo: si cerca per Key.
  // `enterText` vuole un campo di testo, non il widget composito che lo
  // contiene: la Key sta sul LocationAutocompleteField, il TextField è dentro.
  Finder locationField() => find.descendant(
    of: find.byKey(const Key('trip_leg_sheet_location')),
    matching: find.byType(TextField),
  );

  group('showTripLegSheet', () {
    testWidgets('senza luogo il salvataggio non produce una tappa', (
      tester,
    ) async {
      // Una tappa senza luogo non è un promemoria di niente. Il bottone
      // resta attivo (scelta di design), ma il tap a vuoto deve avvisare
      // l'utente invece di non fare assolutamente nulla.
      TripLeg? captured;
      await _pumpHost(tester, (context) async {
        captured = await showTripLegSheet(context);
      });

      await tester.tap(find.byKey(const Key('trip_leg_sheet_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trip_leg_sheet_location')), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(captured, isNull);
    });

    testWidgets('con un luogo restituisce la tappa alla chiusura', (
      tester,
    ) async {
      TripLeg? captured;
      await _pumpHost(tester, (context) async {
        captured = await showTripLegSheet(context);
      });

      await tester.enterText(locationField(), 'Firenze');
      await tester.tap(find.byKey(const Key('trip_leg_sheet_save')));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.locationDisplayName, 'Firenze');
      expect(captured!.id, isNotEmpty);
    });

    testWidgets('in modifica conserva l identità della tappa', (tester) async {
      // L'id deve restare lo stesso, altrimenti modificare una tappa equivale
      // a cancellarla e ricrearla, e la riga salta di posto nella lista.
      TripLeg? captured;
      final initial = TripLeg(
        id: 'leg-esistente',
        locationDisplayName: 'Siena',
      );
      await _pumpHost(tester, (context) async {
        captured = await showTripLegSheet(context, initial: initial);
      });

      await tester.enterText(locationField(), 'Siena centro');
      await tester.tap(find.byKey(const Key('trip_leg_sheet_save')));
      await tester.pumpAndSettle();

      expect(captured!.id, 'leg-esistente');
      expect(captured!.locationDisplayName, 'Siena centro');
    });

    testWidgets('apre senza esplodere una tappa con solo la data di ritorno', (
      tester,
    ) async {
      // Il picker non produce mai questa combinazione, ma il valore arriva
      // anche dal sync di un altro device: un blob con solo `to` non è più
      // impossibile una volta che le tappe viaggiano fra i dispositivi.
      final initial = TripLeg(
        id: 'leg-parziale',
        locationDisplayName: 'Bologna',
        to: DateTime(2026, 9, 14),
      );
      await _pumpHost(tester, (context) async {
        await showTripLegSheet(context, initial: initial);
      });

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('trip_leg_sheet_location')), findsOneWidget);
    });

    testWidgets(
      'modificando solo le date conserva coordinate, paese e casa della tappa',
      (tester) async {
        // Senza questo, il salvataggio ricostruiva la tappa da nome e date e
        // perdeva i campi aggiunti dopo: il luogo restava senza coordinate.
        TripLeg? captured;
        final initial = TripLeg(
          id: 'leg-con-luogo',
          locationDisplayName: 'Siena',
          from: _daysFromToday(7),
          to: _daysFromToday(9),
          lat: 43.318,
          lon: 11.330,
          country: 'Italia',
          houseId: 'casa-siena',
        );
        await _pumpHost(tester, (context) async {
          captured = await showTripLegSheet(context, initial: initial);
        });

        await tester.tap(find.byKey(const Key('trip_leg_sheet_dates')));
        await tester.pumpAndSettle();
        // Il range completo al primo tocco riparte da una nuova partenza.
        await _tapDay(tester, _daysFromToday(12));
        await _tapDay(tester, _daysFromToday(14));
        await tester.tap(find.text('Conferma date'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('trip_leg_sheet_save')));
        await tester.pumpAndSettle();

        expect(captured, isNotNull);
        expect(captured!.id, 'leg-con-luogo');
        expect(captured!.from, _daysFromToday(12));
        expect(captured!.to, _daysFromToday(14));
        expect(captured!.lat, 43.318);
        expect(captured!.lon, 11.330);
        expect(captured!.country, 'Italia');
        expect(captured!.houseId, 'casa-siena');
      },
    );

    testWidgets(
      'cambiando il nome a mano senza scegliere un luogo azzera le coordinate',
      (tester) async {
        // Le coordinate descrivono il luogo di prima: un nome nuovo, scritto
        // senza sceglierlo dalla ricerca, non può portarsele dietro.
        TripLeg? captured;
        final initial = TripLeg(
          id: 'leg-rinominata',
          locationDisplayName: 'Siena',
          lat: 43.318,
          lon: 11.330,
          country: 'Italia',
          houseId: 'casa-siena',
        );
        await _pumpHost(tester, (context) async {
          captured = await showTripLegSheet(context, initial: initial);
        });

        await tester.enterText(locationField(), 'Lucca');
        await tester.tap(find.byKey(const Key('trip_leg_sheet_save')));
        await tester.pumpAndSettle();

        expect(captured!.id, 'leg-rinominata');
        expect(captured!.locationDisplayName, 'Lucca');
        expect(captured!.lat, isNull);
        expect(captured!.lon, isNull);
        expect(captured!.country, isNull);
        expect(captured!.houseId, isNull);
      },
    );
  });
}
