import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_date_range.dart';
import 'package:pack_log/features/trips/view/widgets/trip_calendar.dart';
import 'package:pack_log/features/trips/view/widgets/trip_dates_sheet.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/memory_asset_loader.dart';

late AssetLoader _assetLoader;

/// Raccoglie il valore restituito dal foglio, che si chiude con `pop`.
class _Result<T> {
  T? value;
}

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

/// Monta un pulsante che apre il foglio tramite [open], dietro un
/// `MaterialApp` con le traduzioni reali.
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

/// Il bottone di conferma del foglio: l'unico `DsButton` presente.
DsButton _confirmButton(WidgetTester tester) =>
    tester.widget<DsButton>(find.byType(DsButton));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    _assetLoader = MemoryAssetLoader(readAppTranslations());
  });

  group('showTripRangeSheet', () {
    testWidgets('restituisce le due date toccate', (tester) async {
      final result = _Result<TripDateRange>();
      final departure = _daysFromToday(7);
      final ret = _daysFromToday(10);

      await _pumpHost(tester, (context) async {
        result.value = await showTripRangeSheet(context);
      });

      await _tapDay(tester, departure);
      await _tapDay(tester, ret);
      await tester.tap(find.text('Conferma date'));
      await tester.pumpAndSettle();

      expect(result.value, isNotNull);
      expect(result.value!.departureDate, departure);
      expect(result.value!.returnDate, ret);
    });

    testWidgets('la conferma resta spenta finché manca il ritorno', (
      tester,
    ) async {
      await _pumpHost(tester, (context) async {
        await showTripRangeSheet(context);
      });

      await _tapDay(tester, _daysFromToday(7));

      expect(_confirmButton(tester).onPressed, isNull);
    });

    testWidgets('riceve le date iniziali e le mostra come selezione', (
      tester,
    ) async {
      final result = _Result<TripDateRange>();
      final departure = _daysFromToday(7);
      final ret = _daysFromToday(9);

      await _pumpHost(tester, (context) async {
        result.value = await showTripRangeSheet(
          context,
          initialDeparture: departure,
          initialReturn: ret,
        );
      });

      expect(_confirmButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Conferma date'));
      await tester.pumpAndSettle();

      expect(result.value!.departureDate, departure);
      expect(result.value!.returnDate, ret);
    });
  });

  group('showTripEndSheet', () {
    testWidgets('un giorno fino alla partenza compresa non cambia niente', (
      tester,
    ) async {
      final start = _daysFromToday(7);

      await _pumpHost(tester, (context) async {
        await showTripEndSheet(context, start: start);
      });

      await _tapDay(tester, _daysFromToday(3));
      await _tapDay(tester, start);

      expect(_confirmButton(tester).onPressed, isNull);
    });

    testWidgets('toccare un giorno dopo la partenza e confermare restituisce '
        'quella data', (tester) async {
      final result = _Result<DateTime>();
      final start = _daysFromToday(7);
      final end = _daysFromToday(12);

      await _pumpHost(tester, (context) async {
        result.value = await showTripEndSheet(context, start: start);
      });

      await _tapDay(tester, _daysFromToday(3));
      await _tapDay(tester, end);
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();

      expect(result.value, end);
    });

    testWidgets('un tocco prima della partenza non ripristina la selezione', (
      tester,
    ) async {
      final result = _Result<DateTime>();
      final start = _daysFromToday(7);
      final end = _daysFromToday(9);

      await _pumpHost(tester, (context) async {
        result.value = await showTripEndSheet(context, start: start);
      });

      await _tapDay(tester, end);
      // Nel foglio di intervallo questo tocco riscriverebbe la partenza: qui
      // deve essere ignorato e la fine scelta deve restare.
      await _tapDay(tester, _daysFromToday(3));
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();

      expect(result.value, end);
    });
  });
}
