import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/trips/model/trip_draft.dart';
import 'package:pack_log/features/trips/view/widgets/stop_sheet.dart';
import 'package:pack_log/features/trips/view/widgets/trip_calendar.dart';
import 'package:pack_log/shared/services/location_search_service.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_field_label.dart';
import 'package:pack_log/shared/widgets/ds_link_button.dart';
import 'package:pack_log/shared/widgets/ds_section_title.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/memory_asset_loader.dart';

class _MockLocationSearchService extends Mock
    implements LocationSearchService {}

/// Notifier delle case con una lista fissa: niente repository né sync.
class _FakeHouseNotifier extends HouseNotifier {
  _FakeHouseNotifier(this._houses);

  final List<HouseModel> _houses;

  @override
  Future<List<HouseModel>> build() async => _houses;
}

final _houses = [
  HouseModel(
    id: 'h1',
    name: 'Casa Milano',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  HouseModel(
    id: 'h2',
    name: 'Casa al mare',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
];

/// Raccoglie il valore restituito dal foglio, che si chiude con `pop`.
class _Result {
  StopSheetResult? value;
}

/// Un giorno del mese prossimo: i test non dipendono da che giorno è oggi.
DateTime _nextMonthDay(int day) {
  final now = DateTime.now();
  return DateTime(now.year, now.month + 1, day);
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

/// Monta un pulsante che apre il foglio tramite [open], con le case finte e
/// il servizio dei luoghi mockato, dietro un `MaterialApp` con le traduzioni
/// reali.
Future<void> _pumpHost(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open,
) async {
  final service = _MockLocationSearchService();
  when(
    () => service.search(any(), lang: any(named: 'lang')),
  ).thenAnswer((_) async => const []);

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
          houseNotifierProvider.overrideWith(() => _FakeHouseNotifier(_houses)),
          locationSearchServiceProvider.overrideWithValue(service),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.light,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: Scaffold(
              body: Center(
                child: Builder(
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
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

late AssetLoader _assetLoader;

Finder _saveButton() => find.byKey(const Key('stop_sheet_save'));

DsButton _saveWidget(WidgetTester tester) =>
    tester.widget<DsButton>(_saveButton());

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    _assetLoader = MemoryAssetLoader(readAppTranslations());
  });

  group('showStopSheet', () {
    testWidgets('"Quando?" è alto come il campo del posto', (tester) async {
      await _pumpHost(tester, (context) async {
        await showStopSheet(
          context,
          start: _nextMonthDay(7),
          previousName: 'Lisbona',
        );
      });

      final place = tester.getSize(
        find.descendant(
          of: find.byKey(const Key('stop_sheet_place')),
          matching: find.byType(TextField),
        ),
      );
      final when = tester.getSize(find.byKey(const Key('stop_sheet_dates')));

      expect(when.height, place.height);
    });

    testWidgets('senza posto né fine il bottone di salvataggio è spento', (
      tester,
    ) async {
      await _pumpHost(tester, (context) async {
        await showStopSheet(
          context,
          start: _nextMonthDay(7),
          previousName: 'Lisbona',
        );
      });

      expect(_saveWidget(tester).onPressed, isNull);
    });

    testWidgets('con il posto ma senza fine il bottone resta spento', (
      tester,
    ) async {
      await _pumpHost(tester, (context) async {
        await showStopSheet(
          context,
          start: _nextMonthDay(7),
          previousName: 'Lisbona',
        );
      });

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.byKey(const Key('place_search_house_h2')));
      await tester.pumpAndSettle();

      expect(_saveWidget(tester).onPressed, isNull);
    });

    testWidgets('cambiare il testo dopo aver scelto il posto lo annulla', (
      tester,
    ) async {
      // Il campo mostra un testo nuovo: il posto scelto non è più quello
      // che l'utente vede, quindi il bottone non deve salvarlo.
      final start = _nextMonthDay(7);
      final end = _nextMonthDay(9);
      final result = _Result();

      await _pumpHost(tester, (context) async {
        result.value = await showStopSheet(
          context,
          start: start,
          previousName: 'Lisbona',
        );
      });

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.byKey(const Key('place_search_house_h2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stop_sheet_dates')));
      await tester.pumpAndSettle();
      await _tapDay(tester, end);
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ro');
      await tester.pump();

      expect(_saveWidget(tester).onPressed, isNull);
    });

    testWidgets(
      'con posto e fine scelti restituisce StopSaved con quella fine',
      (tester) async {
        final start = _nextMonthDay(7);
        final end = _nextMonthDay(9);
        final result = _Result();

        await _pumpHost(tester, (context) async {
          result.value = await showStopSheet(
            context,
            start: start,
            previousName: 'Lisbona',
          );
        });

        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.tap(find.byKey(const Key('place_search_house_h2')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('stop_sheet_dates')));
        await tester.pumpAndSettle();
        await _tapDay(tester, end);
        await tester.tap(find.text('Conferma'));
        await tester.pumpAndSettle();

        expect(_saveWidget(tester).onPressed, isNotNull);
        await tester.tap(_saveButton());
        await tester.pumpAndSettle();

        final value = result.value;
        expect(value, isA<StopSaved>());
        final stop = (value! as StopSaved).stop;
        expect(stop.place.houseId, 'h2');
        expect(stop.end, end);
      },
    );

    testWidgets('in modifica "Elimina tappa" restituisce StopRemoved', (
      tester,
    ) async {
      final start = _nextMonthDay(7);
      final result = _Result();

      await _pumpHost(tester, (context) async {
        result.value = await showStopSheet(
          context,
          start: start,
          previousName: 'Lisbona',
          initial: DraftStop(
            place: DraftPlace.house(id: 'h1', name: 'Casa Milano'),
            end: _nextMonthDay(10),
          ),
        );
      });

      expect(find.byType(DsLinkButton), findsOneWidget);
      await tester.tap(find.byKey(const Key('stop_sheet_remove')));
      await tester.pumpAndSettle();

      expect(result.value, isA<StopRemoved>());
    });

    testWidgets(
      'in modifica, toccare il campo "Dove?" senza scrivere non spegne il salvataggio',
      (tester) async {
        // Il tocco mette solo il cursore: il controller notifica, ma il testo
        // è lo stesso e il posto iniziale deve restare valido.
        await _pumpHost(tester, (context) async {
          await showStopSheet(
            context,
            start: _nextMonthDay(7),
            previousName: 'Lisbona',
            initial: DraftStop(
              place: DraftPlace.house(id: 'h1', name: 'Casa Milano'),
              end: _nextMonthDay(10),
            ),
          );
        });

        expect(_saveWidget(tester).onPressed, isNotNull);
        await tester.tap(find.byType(TextField));
        await tester.pump();

        expect(_saveWidget(tester).onPressed, isNotNull);
      },
    );

    testWidgets(
      'in modifica il salvataggio parte dal posto e dalla fine iniziali',
      (tester) async {
        final end = _nextMonthDay(10);
        final result = _Result();

        await _pumpHost(tester, (context) async {
          result.value = await showStopSheet(
            context,
            start: _nextMonthDay(7),
            previousName: 'Lisbona',
            initial: DraftStop(
              place: DraftPlace.house(id: 'h1', name: 'Casa Milano'),
              end: end,
            ),
          );
        });

        expect(_saveWidget(tester).onPressed, isNotNull);
        await tester.tap(_saveButton());
        await tester.pumpAndSettle();

        final stop = (result.value! as StopSaved).stop;
        expect(stop.place.houseId, 'h1');
        expect(stop.end, end);
      },
    );
  });

  group('cornice del foglio', () {
    testWidgets('tappa: le sezioni sono etichette del foglio', (tester) async {
      await _pumpHost(tester, (context) async {
        await showStopSheet(
          context,
          start: _nextMonthDay(7),
          previousName: 'Lisbona',
        );
      });

      expect(find.byType(DsSectionTitle), findsNothing);
      expect(find.byType(DsFieldLabel), findsAtLeastNWidgets(2));
    });

    testWidgets('tappa con la tastiera aperta', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await _pumpHost(tester, (context) async {
        await showStopSheet(
          context,
          start: _nextMonthDay(7),
          previousName: 'Lisbona',
        );
      });

      await tester.tap(find.byKey(const Key('stop_sheet_place')));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_saveButton().hitTestable(), findsOneWidget);
    });
  });
}
