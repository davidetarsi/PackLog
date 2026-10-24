import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/providers/luggage_provider.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/providers/trip_weather_provider.dart';
import 'package:pack_log/features/trips/view/widgets/ai/ai_choice_pill.dart';
import 'package:pack_log/features/trips/view/widgets/ai/ai_packing_sheet.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';

import '../../../helpers/memory_asset_loader.dart';

class _Houses extends HouseNotifier {
  _Houses(this.houses);
  final List<HouseModel> houses;

  @override
  Future<List<HouseModel>> build() async => houses;
}

class _Luggages extends LuggageNotifier {
  _Luggages(this.luggages);
  final List<LuggageModel> luggages;

  @override
  Future<List<LuggageModel>> build() async => luggages;
}

class _Weather extends TripWeatherNotifier {
  @override
  Future<TripWeatherState> build(String tripId) async =>
      const TripWeatherNotAvailable(WeatherUnavailable.past);
}

final _milano = HouseModel(
  id: 'h1',
  name: 'Casa Milano',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _zaino = LuggageModel(
  id: 'l1',
  name: 'Zaino blu',
  sizeType: LuggageSize.smallBackpack,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TripModel _trip({List<LuggageModel> luggages = const []}) => TripModel(
  id: 'trip-1',
  name: 'Islanda',
  luggages: luggages,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Un piano con le tappe [stops] (chiave, nome, giorni) in fila dal 3 nov.
TripWeatherRequest _plan(List<(String, String, int)> stops) {
  var from = DateTime(2026, 11, 3);
  return TripWeatherRequest([
    for (final (key, name, days) in stops)
      () {
        final stop = WeatherStopRequest(
          stopKey: key,
          name: name,
          country: 'Paese',
          lat: 64,
          lon: -21,
          from: from,
          days: days,
        );
        from = from.add(Duration(days: days));
        return stop;
      }(),
  ]);
}

final _oneStop = _plan([('main', 'Reykjavik', 5)]);
final _twoStops = _plan([('main', 'Islanda', 4), ('olanda', 'Olanda', 4)]);

class _Result {
  bool called = false;
  AiPackingSetup? setup;
}

Future<void> _pump(
  WidgetTester tester, {
  required TripWeatherRequest plan,
  required _Result result,
  List<HouseModel> houses = const [],
  List<LuggageModel> luggages = const [],
  List<LuggageModel> tripLuggages = const [],
}) async {
  tester.view.physicalSize = const Size(390, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        houseNotifierProvider.overrideWith(() => _Houses(houses)),
        luggageNotifierProvider.overrideWith(() => _Luggages(luggages)),
        tripWeatherNotifierProvider('trip-1').overrideWith(_Weather.new),
      ],
      child: EasyLocalization(
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
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () async {
                      final setup = await showAiPackingSheet(
                        context,
                        trip: _trip(luggages: tripLuggages),
                        plan: plan,
                      );
                      result
                        ..called = true
                        ..setup = setup;
                    },
                    child: const Text('apri'),
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
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label).first;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

TextStyle _textStyle(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!;

/// Nessun testo, icona, sfondo o interruttore del foglio è arancio. Con
/// [skipDsButton] si escludono i discendenti del bottone in fondo.
void _expectNoPrimaryOutside(
  WidgetTester tester,
  Color primary, {
  bool skipDsButton = false,
}) {
  bool insideButton(Element element) {
    if (!skipDsButton) return false;
    var found = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is DsButton) found = true;
      return !found;
    });
    return found;
  }

  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    if (insideButton(find.byWidget(text).evaluate().single)) continue;
    expect(text.style?.color, isNot(primary), reason: 'testo "${text.data}"');
  }
  for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
    if (insideButton(find.byWidget(icon).evaluate().single)) continue;
    expect(icon.color, isNot(primary), reason: 'icona arancio');
  }
  for (final box in tester.widgetList<Container>(find.byType(Container))) {
    final decoration = box.decoration;
    if (decoration is! BoxDecoration) continue;
    if (insideButton(find.byWidget(box).evaluate().single)) continue;
    expect(decoration.color, isNot(primary), reason: 'sfondo arancio');
    expect(decoration.border?.top.color, isNot(primary), reason: 'bordo');
  }
  for (final switchWidget in tester.widgetList<Switch>(find.byType(Switch))) {
    expect(switchWidget.activeTrackColor, isNot(primary));
    expect(switchWidget.activeThumbColor, isNot(primary));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('foglio Valigia con AI', () {
    testWidgets('con una tappa sola niente stepper', (tester) async {
      final result = _Result();
      await _pump(
        tester,
        plan: _oneStop,
        result: result,
        houses: [_milano],
        luggages: [_zaino],
        tripLuggages: [_zaino],
      );

      expect(find.textContaining('Tappa 1 di'), findsNothing);
      expect(find.text('Cosa farai?'), findsOneWidget);
      expect(find.text('Avanti: Reykjavik'), findsNothing);
    });

    testWidgets('con una tappa, Immersioni e snorkeling dà diving', (
      tester,
    ) async {
      final result = _Result();
      await _pump(
        tester,
        plan: _oneStop,
        result: result,
        houses: [_milano],
        luggages: [_zaino],
        tripLuggages: [_zaino],
      );

      await _tap(tester, 'Immersioni e snorkeling');
      await _tap(tester, 'Prepara la valigia');
      await tester.pumpAndSettle();

      expect(result.called, isTrue);
      expect(result.setup!.houseId, 'h1');
      expect(result.setup!.luggageId, 'l1');
      expect(result.setup!.stops['main']!.activities, [AiActivity.diving]);
    });

    testWidgets('senza bagagli sul viaggio non si preseleziona niente', (
      tester,
    ) async {
      final result = _Result();
      await _pump(
        tester,
        plan: _oneStop,
        result: result,
        houses: [_milano],
        luggages: [_zaino],
      );

      await _tap(tester, 'Prepara la valigia');
      await tester.pumpAndSettle();

      expect(result.setup!.luggageId, isNull);
      expect(result.setup!.houseId, 'h1');
    });

    testWidgets('con due tappe la seconda parte vuota', (tester) async {
      final result = _Result();
      await _pump(
        tester,
        plan: _twoStops,
        result: result,
        houses: [_milano],
        luggages: [_zaino],
      );

      expect(find.text('Tappa 1 di 2 · Islanda'), findsOneWidget);
      await _tap(tester, 'Città e musei');
      await _tap(tester, 'Hotel');
      await _tap(tester, 'Avanti: Olanda');

      expect(find.text('Tappa 2 di 2 · Olanda'), findsOneWidget);
      expect(find.text('Uguale a Islanda'), findsOneWidget);
    });

    testWidgets('Uguale a copia le risposte e scompare', (tester) async {
      final result = _Result();
      await _pump(
        tester,
        plan: _twoStops,
        result: result,
        houses: [_milano],
        luggages: [_zaino],
      );

      await _tap(tester, 'Città e musei');
      await _tap(tester, 'Hotel');
      await _tap(tester, 'Avanti: Olanda');
      await _tap(tester, 'Uguale a Islanda');

      expect(find.text('Uguale a Islanda'), findsNothing);
      await _tap(tester, 'Prepara la valigia');
      await tester.pumpAndSettle();

      expect(result.called, isTrue);
      expect(result.setup!.stops['olanda']!.activities, [AiActivity.city]);
      expect(result.setup!.stops['olanda']!.stay, AiStay.hotel);
    });

    testWidgets('primo tocco con tappa vuota avvisa, il secondo chiude', (
      tester,
    ) async {
      final result = _Result();
      await _pump(
        tester,
        plan: _twoStops,
        result: result,
        houses: [_milano],
        luggages: [_zaino],
      );

      await _tap(tester, 'Città e musei');
      await _tap(tester, 'Hotel');
      await _tap(tester, 'Avanti: Olanda');
      await _tap(tester, 'Prepara la valigia');

      expect(result.called, isFalse);
      expect(find.textContaining('è ancora da compilare'), findsOneWidget);
      expect(find.text('La compilo io'), findsOneWidget);

      await _tap(tester, 'Prepara la valigia');
      await tester.pumpAndSettle();

      expect(result.called, isTrue);
      expect(result.setup!.stops['main']!.activities, [AiActivity.city]);
      expect(result.setup!.stops['olanda']!.isUntouched, isTrue);
    });

    testWidgets('La compilo io porta alla tappa vuota', (tester) async {
      final result = _Result();
      await _pump(
        tester,
        plan: _twoStops,
        result: result,
        houses: [_milano],
        luggages: [_zaino],
      );

      await _tap(tester, 'Città e musei');
      await _tap(tester, 'Hotel');
      await _tap(tester, 'Avanti: Olanda');
      await _tap(tester, 'Indietro');
      expect(find.text('Tappa 1 di 2 · Islanda'), findsOneWidget);
      await _tap(tester, 'Avanti: Olanda');
      await _tap(tester, 'Prepara la valigia');
      await _tap(tester, 'La compilo io');

      expect(find.text('Tappa 2 di 2 · Olanda'), findsOneWidget);
      expect(find.textContaining('è ancora da compilare'), findsNothing);
      expect(result.called, isFalse);
    });

    testWidgets(
      'Indietro tiene le pillole della tappa 1; la tappa 2 vuota avvisa e '
      'offre Uguale a',
      (tester) async {
        final result = _Result();
        await _pump(
          tester,
          plan: _twoStops,
          result: result,
          houses: [_milano],
          luggages: [_zaino],
        );

        await _tap(tester, 'Città e musei');
        await _tap(tester, 'Hotel');
        await _tap(tester, 'Avanti: Olanda');
        await _tap(tester, 'Indietro');

        expect(find.text('Tappa 1 di 2 · Islanda'), findsOneWidget);
        expect(
          tester
              .widget<AiChoicePill>(
                find.widgetWithText(AiChoicePill, 'Città e musei'),
              )
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<AiChoicePill>(find.widgetWithText(AiChoicePill, 'Hotel'))
              .selected,
          isTrue,
        );

        await _tap(tester, 'Avanti: Olanda');
        await _tap(tester, 'Prepara la valigia');

        expect(result.called, isFalse);
        expect(
          find.textContaining('Olanda è ancora da compilare'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('ai_incomplete_warning')),
            matching: find.text('Uguale a Islanda'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('senza case niente bottone', (tester) async {
      final result = _Result();
      await _pump(tester, plan: _oneStop, result: result, luggages: [_zaino]);

      expect(find.textContaining('Aggiungi una casa'), findsOneWidget);
      expect(find.text('Prepara la valigia'), findsNothing);
      expect(find.byType(DsButton), findsNothing);
    });

    testWidgets('il solo arancio è Prepara la valigia', (tester) async {
      final result = _Result();
      await _pump(
        tester,
        plan: _twoStops,
        result: result,
        houses: [_milano],
        luggages: [_zaino],
        tripLuggages: [_zaino],
      );
      final primary = Theme.of(
        tester.element(find.byType(Scaffold)),
      ).colorScheme.primary;

      // Primo passo: Avanti non è arancio, e nessun DsButton è nel foglio.
      expect(find.byType(DsButton), findsNothing);
      expect(find.text('Avanti: Olanda'), findsOneWidget);
      _expectNoPrimaryOutside(tester, primary);
      expect(_textStyle(tester, 'Avanti: Olanda').color, isNot(primary));

      // Ultimo passo: l'unico DsButton è "Prepara la valigia", arancio.
      await _tap(tester, 'Avanti: Olanda');
      expect(find.byType(DsButton), findsOneWidget);
      expect(find.text('Prepara la valigia'), findsOneWidget);
      _expectNoPrimaryOutside(tester, primary, skipDsButton: true);
      final cta = tester.widget<DsButton>(find.byType(DsButton));
      expect(cta.label, 'Prepara la valigia');
      expect(cta.variant, DsButtonVariant.primary);
    });

    testWidgets('con una tappa l unico DsButton è Prepara la valigia', (
      tester,
    ) async {
      final result = _Result();
      await _pump(
        tester,
        plan: _oneStop,
        result: result,
        houses: [_milano],
        luggages: [_zaino],
        tripLuggages: [_zaino],
      );
      final primary = Theme.of(
        tester.element(find.byType(Scaffold)),
      ).colorScheme.primary;

      expect(find.byType(DsButton), findsOneWidget);
      expect(find.text('Prepara la valigia'), findsOneWidget);
      _expectNoPrimaryOutside(tester, primary, skipDsButton: true);
    });
  });
}
