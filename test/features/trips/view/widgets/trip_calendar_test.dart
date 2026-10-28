import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_date_range.dart';
import 'package:pack_log/features/trips/view/widgets/trip_calendar.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

import '../../../../helpers/memory_asset_loader.dart';

/// Altezza stimata di un mese, come la calcola [TripCalendar]: intestazione 28,
/// padding 16, riga dei giorni 18, spazio 4, righe da 40 con 4 tra l'una e
/// l'altra, padding in fondo 32.
double _monthHeight(DateTime month) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  final rows = ((month.weekday - 1 + days) / 7).ceil();
  return 28 + 16 + 18 + 4 + rows * 40 + (rows - 1) * 4 + 32;
}

void main() {
  testWidgets(
    'il calendario si apre sul mese della data scelta, con lo stesso offset',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      // Tre mesi dopo quello corrente: la finestra di default parte 12 mesi
      // indietro, quindi il mese target è a 15 passi dall'inizio.
      final target = DateTime(now.year, now.month + 3, 1);
      final start = DateTime(now.year, now.month - 12, 1);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
          path: 'assets/translations',
          assetLoader: MemoryAssetLoader(readAppTranslations()),
          fallbackLocale: const Locale('en', 'US'),
          startLocale: const Locale('it', 'IT'),
          saveLocale: false,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.light,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: Scaffold(
                body: TripCalendar(
                  selection: const TripDateRange(),
                  onDaySelected: (_) {},
                  initialMonth: target,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Padding superiore (16) più l'altezza dei mesi prima del target.
      var expected = 16.0;
      for (
        var m = start;
        m.isBefore(target);
        m = DateTime(m.year, m.month + 1, 1)
      ) {
        expected += _monthHeight(m);
      }

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.controller!.offset, expected);
    },
  );
}
