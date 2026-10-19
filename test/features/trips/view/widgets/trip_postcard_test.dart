import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/model/trip_postcard.dart';
import 'package:pack_log/features/trips/view/widgets/postcard/postcard_parts.dart';
import 'package:pack_log/features/trips/view/widgets/postcard/trip_postcard.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/memory_asset_loader.dart';

final _stampKey = find.byKey(const Key('postcard_stamp'));

TripModel _trip({
  String name = 'Lisbona',
  DateTime? departure,
  DateTime? returnAt,
  List<TripItem> items = const [],
  List<LuggageModel> luggages = const [],
  List<TripLeg> legs = const [],
}) {
  return TripModel(
    id: 'trip-1',
    name: name,
    departureDateTime: departure,
    returnDateTime: returnAt,
    items: items,
    luggages: luggages,
    legs: legs,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

TripItem _item(String id, {bool checked = false}) => TripItem(
  id: id,
  name: 'Oggetto $id',
  category: ItemCategory.vestiti,
  quantity: 1,
  isChecked: checked,
);

LuggageModel _luggage(String id, String name) => LuggageModel(
  id: id,
  houseId: 'house-1',
  name: name,
  sizeType: LuggageSize.cabinBaggage,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Finder _rows() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('itinerary_row'),
);

late AssetLoader _assetLoader;

Future<void> _pump(
  WidgetTester tester, {
  required TripModel trip,
  String destination = 'Lisbona',
  ValueChanged<PostcardCta>? onCta,
  Size size = const Size(390, 640),
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
      path: 'assets/translations',
      assetLoader: _assetLoader,
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
            body: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: TripPostcard(
                  trip: trip,
                  destination: destination,
                  onCta: onCta ?? (_) {},
                ),
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
    _assetLoader = MemoryAssetLoader(readAppTranslations());
  });

  group('itinerario', () {
    testWidgets('Lisbona con una tappa a Sintra mostra cinque righe', (
      tester,
    ) async {
      final trip = _trip(
        departure: DateTime(2026, 10, 28),
        returnAt: DateTime(2026, 11, 2),
        legs: [
          TripLeg(
            id: 'sintra',
            locationDisplayName: 'Sintra, Portogallo',
            from: DateTime(2026, 10, 31),
            to: DateTime(2026, 11, 2),
          ),
        ],
      );

      await _pump(tester, trip: trip);

      expect(_rows(), findsNWidgets(5));
      expect(find.text('Sintra'), findsOneWidget);
      expect(find.text('Lisbona'), findsWidgets);
    });
  });

  group('francobollo', () {
    testWidgets('giorni alla partenza', (tester) async {
      final now = DateTime.now();
      // Giorni di calendario, non Duration: con il cambio d'ora di ottobre
      // `add(Duration(days: 9))` cade a ore 23 del giorno prima.
      await _pump(
        tester,
        trip: _trip(
          departure: DateTime(
            now.year,
            now.month,
            now.day + 9,
            now.hour,
            now.minute,
          ),
          returnAt: DateTime(
            now.year,
            now.month,
            now.day + 12,
            now.hour,
            now.minute,
          ),
        ),
      );

      expect(
        find.descendant(of: _stampKey, matching: find.text('9')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _stampKey, matching: find.text('giorni')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('postcard_postmark')), findsOneWidget);
    });

    testWidgets('oggi, senza giorni', (tester) async {
      final now = DateTime.now();
      await _pump(
        tester,
        trip: _trip(
          departure: DateTime(now.year, now.month, now.day, 23, 59),
          returnAt: now.add(const Duration(days: 3)),
        ),
      );

      expect(
        find.descendant(of: _stampKey, matching: find.text('oggi')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('postcard_postmark')), findsOneWidget);
    });

    testWidgets('in viaggio, con l icona di decollo', (tester) async {
      final now = DateTime.now();
      await _pump(
        tester,
        trip: _trip(
          departure: now.subtract(const Duration(days: 1)),
          returnAt: now.add(const Duration(days: 3)),
        ),
      );

      expect(
        find.descendant(of: _stampKey, matching: find.text('in viaggio')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _stampKey,
          matching: find.byIcon(Icons.flight_takeoff),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('postcard_postmark')), findsOneWidget);
    });

    testWidgets('senza data: da decidere, senza timbro', (tester) async {
      await _pump(tester, trip: _trip());

      expect(
        find.descendant(of: _stampKey, matching: find.text('da decidere')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _stampKey, matching: find.byIcon(Icons.event)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('postcard_postmark')), findsNothing);
    });
  });

  group('valigia', () {
    testWidgets('con due bagagli mostra la riga bagagli', (tester) async {
      await _pump(
        tester,
        trip: _trip(
          luggages: [_luggage('l1', 'Zaino'), _luggage('l2', 'Trolley')],
        ),
      );

      expect(find.byKey(const Key('postcard_luggage')), findsOneWidget);
      expect(find.textContaining('Zaino'), findsOneWidget);
      expect(find.textContaining('Trolley'), findsOneWidget);
    });

    testWidgets('senza bagagli la riga bagagli non c è', (tester) async {
      await _pump(tester, trip: _trip(items: [_item('a')]));

      expect(find.byKey(const Key('postcard_luggage')), findsNothing);
    });
  });

  group('bottone', () {
    Future<PostcardCta?> tapCta(
      WidgetTester tester, {
      required List<TripItem> items,
    }) async {
      PostcardCta? received;
      await _pump(
        tester,
        trip: _trip(items: items),
        onCta: (cta) => received = cta,
      );
      await tester.tap(find.byKey(const Key('postcard_cta')));
      await tester.pump();
      return received;
    }

    testWidgets('senza oggetti chiama prepare', (tester) async {
      expect(await tapCta(tester, items: const []), PostcardCta.prepare);
    });

    testWidgets('tutti spuntati chiama ready', (tester) async {
      expect(
        await tapCta(
          tester,
          items: [_item('a', checked: true), _item('b', checked: true)],
        ),
        PostcardCta.ready,
      );
    });

    testWidgets('parziale chiama continuePacking', (tester) async {
      expect(
        await tapCta(tester, items: [_item('a', checked: true), _item('b')]),
        PostcardCta.continuePacking,
      );
    });
  });

  testWidgets('il bottone sta in fondo alla carta anche su un box alto', (
    tester,
  ) async {
    // La finestra di test è 800x600: serve più altezza perché la carta sia alta 700.
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    await _pump(
      tester,
      size: const Size(390, 700),
      trip: _trip(
        departure: now.add(const Duration(days: 20)),
        returnAt: now.add(const Duration(days: 25)),
        items: [_item('a'), _item('b', checked: true)],
        luggages: [_luggage('l1', 'Zaino')],
      ),
    );

    final card = tester.getRect(find.byType(PostcardPaper));
    final padding = tester.element(find.byType(TripPostcard)).spacingLg;
    final ctaBottom = tester
        .getBottomLeft(find.byKey(const Key('postcard_cta')))
        .dy;
    // Il bordo della carta aggiunge 1 px allo spazio interno.
    expect(ctaBottom, closeTo(card.bottom - padding, 2));
  });

  testWidgets('nomi lunghi non producono overflow', (tester) async {
    final now = DateTime.now();
    await _pump(
      tester,
      destination: "Baita dei nonni a Courmayeur, Valle d'Aosta",
      size: const Size(390, 560),
      trip: _trip(
        name: 'Weekend in montagna',
        departure: now.add(const Duration(days: 20)),
        returnAt: now.add(const Duration(days: 25)),
        items: [_item('a'), _item('b', checked: true)],
        luggages: [
          _luggage('l1', 'Trolley cabina grande'),
          _luggage('l2', 'Zaino da trekking blu'),
          _luggage('l3', 'Borsa da palestra'),
        ],
        legs: [
          for (final (i, name) in [
            'Aosta, Italia',
            'Pila, Italia',
            'Cogne, Italia',
            'Champoluc, Italia',
          ].indexed)
            TripLeg(
              id: 'leg-$i',
              locationDisplayName: name,
              from: now.add(Duration(days: 21 + i)),
              to: now.add(Duration(days: 22 + i)),
            ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    // Intestazione e prima riga dell'itinerario mostrano la stessa meta.
    expect(
      find.text("Baita dei nonni a Courmayeur, Valle d'Aosta"),
      findsWidgets,
    );
  });
}
