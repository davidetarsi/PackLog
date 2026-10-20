import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_postcard.dart';
import 'package:pack_log/features/trips/view/widgets/postcard/trip_itinerary_view.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/memory_asset_loader.dart';

final _trip = TripModel(
  id: 'trip-1',
  name: 'Lisbona',
  departureDateTime: DateTime(2026, 11, 1),
  returnDateTime: DateTime(2026, 11, 6),
  legs: [
    TripLeg(
      id: 'sintra',
      locationDisplayName: 'Sintra, Portogallo',
      from: DateTime(2026, 11, 3),
      to: DateTime(2026, 11, 6),
    ),
  ],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pump(
  WidgetTester tester, {
  ValueChanged<int>? onPlaceTap,
  int firstTappablePlace = 0,
}) async {
  final entries = buildItinerary(_trip, destination: 'Lisbona');
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
            body: SingleChildScrollView(
              child: TripItineraryView(
                entries: entries,
                onPlaceTap: onPlaceTap,
                firstTappablePlace: firstTappablePlace,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('TripItineraryView onPlaceTap', () {
    testWidgets('il tocco su una riga di luogo dà il suo indice tra i luoghi', (
      tester,
    ) async {
      final taps = <int>[];
      await _pump(tester, onPlaceTap: taps.add);

      await tester.tap(find.text('Sintra'));
      await tester.pump();
      await tester.tap(find.text('Lisbona'));
      await tester.pump();

      expect(taps, [1, 0]);
    });

    testWidgets('i luoghi prima di firstTappablePlace non reagiscono', (
      tester,
    ) async {
      final taps = <int>[];
      await _pump(tester, onPlaceTap: taps.add, firstTappablePlace: 1);

      await tester.tap(find.text('Lisbona'));
      await tester.pump();
      await tester.tap(find.text('Sintra'));
      await tester.pump();

      expect(taps, [1]);
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('andata e ritorno non sono toccabili', (tester) async {
      final taps = <int>[];
      await _pump(tester, onPlaceTap: taps.add);

      await tester.tap(find.text('Andata'));
      await tester.pump();
      await tester.tap(find.text('Ritorno'));
      await tester.pump();

      expect(taps, isEmpty);
    });

    testWidgets('senza onPlaceTap le righe non reagiscono al tocco', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(InkWell), findsNothing);
      expect(find.text('Sintra'), findsOneWidget);
    });
  });
}
