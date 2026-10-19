import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/view/widgets/postcard/postcard_parts.dart';
import 'package:pack_log/features/trips/view/widgets/postcard/trip_album.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/memory_asset_loader.dart';

TripModel _trip(
  String id, {
  String? name,
  DateTime? departure,
  DateTime? returnAt,
}) {
  return TripModel(
    id: id,
    name: name ?? 'Viaggio $id',
    departureDateTime: departure,
    returnDateTime: returnAt,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Finder _cards() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('album_postcard_'),
);

late AssetLoader _assetLoader;

Widget _maybeRefresh(Future<void> Function()? onRefresh, Widget child) =>
    onRefresh == null
    ? child
    : RefreshIndicator(onRefresh: onRefresh, child: child);

Future<void> _pump(
  WidgetTester tester, {
  required List<TripAlbumGroup> groups,
  bool cancelledStamps = true,
  ValueChanged<TripModel>? onTap,
  ValueChanged<TripModel>? onLongPress,
  ValueChanged<TripModel>? onReuse,
  String Function(TripModel)? destinationOf,
  Size size = const Size(390, 800),
  Future<void> Function()? onRefresh,
}) async {
  // La scala responsive dipende dalla larghezza della vista: si fissa a 390.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
                child: _maybeRefresh(
                  onRefresh,
                  TripAlbum(
                    groups: groups,
                    cancelledStamps: cancelledStamps,
                    destinationOf: destinationOf ?? (trip) => trip.name,
                    onTap: onTap ?? (_) {},
                    onLongPress: onLongPress ?? (_) {},
                    onReuse: onReuse ?? (_) {},
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
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    _assetLoader = MemoryAssetLoader(readAppTranslations());
  });

  final lisbona = _trip(
    'lisbona',
    name: 'Lisbona',
    departure: DateTime(2026, 8, 20),
    returnAt: DateTime(2026, 8, 25),
  );
  final firenze = _trip(
    'firenze',
    name: 'Firenze',
    departure: DateTime(2026, 2, 20),
    returnAt: DateTime(2026, 2, 27),
  );
  final courmayeur = _trip(
    'courmayeur',
    name: "Baita dei nonni a Courmayeur, Valle d'Aosta",
    departure: DateTime(2025, 12, 26),
    returnAt: DateTime(2026, 1, 2),
  );

  final groups = [
    TripAlbumGroup('2026', [lisbona, firenze]),
    TripAlbumGroup('2025', [courmayeur]),
  ];

  testWidgets('un header per gruppo e una cartolina per viaggio', (
    tester,
  ) async {
    await _pump(tester, groups: groups);

    expect(find.byType(DsGroupHeader), findsNWidgets(2));
    expect(_cards(), findsNWidgets(3));
    expect(find.byKey(const Key('album_postcard_lisbona')), findsOneWidget);
    expect(find.byKey(const Key('album_postcard_firenze')), findsOneWidget);
    expect(find.byKey(const Key('album_postcard_courmayeur')), findsOneWidget);
  });

  testWidgets('Riusa chiama onReuse con il viaggio della cartolina', (
    tester,
  ) async {
    final reused = <TripModel>[];
    await _pump(tester, groups: groups, onReuse: reused.add);

    await tester.tap(find.byKey(const Key('album_reuse_firenze')));
    await tester.pumpAndSettle();

    expect(reused.map((t) => t.id), ['firenze']);
  });

  testWidgets('tap sulla cartolina chiama onTap, pressione lunga onLongPress', (
    tester,
  ) async {
    final tapped = <TripModel>[];
    final held = <TripModel>[];
    await _pump(
      tester,
      groups: groups,
      onTap: tapped.add,
      onLongPress: held.add,
    );

    await tester.tap(find.text('Lisbona'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Firenze'));
    await tester.pumpAndSettle();

    expect(tapped.map((t) => t.id), ['lisbona']);
    expect(held.map((t) => t.id), ['firenze']);
  });

  testWidgets('tap su Riusa chiama solo onReuse, non onTap', (tester) async {
    final reused = <TripModel>[];
    final tapped = <TripModel>[];
    await _pump(tester, groups: groups, onTap: tapped.add, onReuse: reused.add);

    await tester.tap(find.byKey(const Key('album_reuse_lisbona')));
    await tester.pumpAndSettle();

    expect(reused.map((t) => t.id), ['lisbona']);
    expect(tapped, isEmpty);
  });

  testWidgets('con cancelledStamps c è un timbro annullato per cartolina', (
    tester,
  ) async {
    await _pump(tester, groups: groups);

    expect(find.byType(CancelWaves), findsNWidgets(3));
  });

  testWidgets('senza cancelledStamps nessun timbro annullato', (tester) async {
    await _pump(tester, groups: groups, cancelledStamps: false);

    expect(find.byType(CancelWaves), findsNothing);
  });

  testWidgets('un viaggio senza date mostra il segnalibro', (tester) async {
    final undated = _trip('undated', name: 'Da decidere');
    await _pump(
      tester,
      groups: [
        TripAlbumGroup('Da riusare', [undated]),
      ],
    );

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.textContaining('notti'), findsNothing);
  });

  testWidgets('mostra il giorno, il mese e le notti del viaggio', (
    tester,
  ) async {
    await _pump(
      tester,
      groups: [
        TripAlbumGroup('2026', [lisbona]),
      ],
    );

    expect(find.text('20'), findsOneWidget);
    expect(find.text('AGO 26'), findsOneWidget);
    expect(find.text('5 notti'), findsOneWidget);
    expect(find.text('Saluti da'), findsOneWidget);
    expect(find.text('Riusa'), findsOneWidget);
  });

  testWidgets('la meta lunga su larghezza 390 non va in overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      groups: [
        TripAlbumGroup('2025', [courmayeur]),
      ],
      destinationOf: (trip) => trip.name,
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Baita dei nonni'), findsOneWidget);
  });

  testWidgets('la meta lunga su larghezza 360 non va in overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      groups: [
        TripAlbumGroup('2025', [courmayeur]),
      ],
      size: const Size(360, 800),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Baita dei nonni'), findsOneWidget);
  });

  testWidgets(
    'album corto dentro RefreshIndicator: il trascinamento aggiorna',
    (tester) async {
      var refreshes = 0;
      await _pump(
        tester,
        groups: [
          TripAlbumGroup('2026', [lisbona]),
        ],
        onRefresh: () async {
          refreshes++;
        },
      );

      expect(
        tester.widget<ListView>(find.byType(ListView)).physics,
        isA<AlwaysScrollableScrollPhysics>(),
      );

      await tester.drag(find.byType(TripAlbum), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(refreshes, 1);
    },
  );

  testWidgets('senza timbro annullato il francobollo è centrato', (
    tester,
  ) async {
    await _pump(
      tester,
      groups: [
        TripAlbumGroup('2026', [lisbona]),
      ],
      cancelledStamps: false,
    );

    final stamp = tester.getRect(find.byType(PostageStamp).first);
    final day = tester.getCenter(find.text('20'));
    expect(day.dx, closeTo(stamp.center.dx, 0.5));
  });
}
