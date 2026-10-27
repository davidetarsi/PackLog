import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/profile/providers/gpt_usage_provider.dart';
import 'package:pack_log/shared/widgets/create_sheet.dart';
import 'package:pack_log/shared/widgets/ds_glass_band.dart';
import 'package:pack_log/shared/widgets/main_shell.dart';

class _MockAnalytics extends Mock implements AppAnalyticsService {}

class _FakeHouseNotifier extends HouseNotifier {
  _FakeHouseNotifier(this.houses);
  final List<HouseModel> houses;
  @override
  Future<List<HouseModel>> build() async => houses;
}

HouseModel _house(String id) => HouseModel(
  id: id,
  name: 'Casa $id',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late _MockAnalytics analytics;

  setUp(() {
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  GoRouter buildRouter() => GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const Text('HOUSES')),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/trips', builder: (_, _) => const Text('TRIPS')),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/new-trip',
        builder: (_, state) => Text(
          state.uri.queryParameters['ai'] == '1' ? 'NEW TRIP AI' : 'NEW TRIP',
        ),
      ),
      GoRoute(
        path: '/houses/:id',
        builder: (_, state) => Text(
          'HOUSE ${state.pathParameters['id']} '
          'add=${state.uri.queryParameters['add']}',
        ),
      ),
    ],
  );

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        saveLocale: false,
        child: ProviderScope(
          overrides: [
            analyticsServiceProvider.overrideWithValue(analytics),
            houseNotifierProvider.overrideWith(
              () => _FakeHouseNotifier([_house('a')]),
            ),
            gptUsageProvider.overrideWith(
              (ref) async => const GptUsageModel(usageCount: 3, usageCap: 30),
            ),
          ],
          child: MaterialApp.router(routerConfig: buildRouter()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCreate(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('nav_create')));
    await tester.pumpAndSettle();
  }

  testWidgets('la barra ha Case, Crea e Viaggi, con Crea al centro', (
    tester,
  ) async {
    await pumpShell(tester);
    double x(String key) => tester.getCenter(find.byKey(Key(key))).dx;
    expect(x('nav_houses'), lessThan(x('nav_create')));
    expect(x('nav_create'), lessThan(x('nav_trips')));
  });

  testWidgets('la barra delle tab sta sulla fascia di vetro', (tester) async {
    await pumpShell(tester);
    final band = find.byType(DsGlassBand);
    expect(band, findsOneWidget);
    expect(
      find.descendant(of: band, matching: find.byKey(const Key('nav_create'))),
      findsOneWidget,
    );
  });

  testWidgets('le tre scritte sono allineate', (tester) async {
    await pumpShell(tester);
    double labelY(String key) => tester
        .getCenter(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
          ),
        )
        .dy;
    expect(labelY('nav_create'), labelY('nav_houses'));
    expect(labelY('nav_create'), labelY('nav_trips'));
  });

  testWidgets('le tre icone hanno la stessa misura', (tester) async {
    await pumpShell(tester);
    Size iconSize(String key) => tester.getSize(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(Icon)),
    );
    expect(iconSize('nav_create'), iconSize('nav_houses'));
    expect(iconSize('nav_create'), iconSize('nav_trips'));
  });

  testWidgets('tab attiva: lineetta arancio, scritte dei luoghi non arancio', (
    tester,
  ) async {
    await pumpShell(tester);
    Finder indicatorIn(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byKey(const Key('nav_indicator')),
    );
    expect(indicatorIn('nav_houses'), findsOneWidget);
    expect(indicatorIn('nav_trips'), findsNothing);

    final scheme = Theme.of(
      tester.element(find.byKey(const Key('nav_houses'))),
    ).colorScheme;
    Color? labelColor(String key) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
          ),
        )
        .style
        ?.color;
    expect(labelColor('nav_houses'), scheme.onSurface);
    expect(labelColor('nav_trips'), scheme.onSurface);
    expect(labelColor('nav_create'), scheme.primary);

    await tester.tap(find.byKey(const Key('nav_trips')));
    await tester.pumpAndSettle();
    expect(indicatorIn('nav_houses'), findsNothing);
    expect(indicatorIn('nav_trips'), findsOneWidget);
  });

  testWidgets('Crea da Case apre il foglio e lo segna da Case', (tester) async {
    await pumpShell(tester);
    await openCreate(tester);
    expect(find.byType(CreateSheet), findsOneWidget);
    verify(
      () => analytics.logEvent('create_tapped', properties: {'tab': 'houses'}),
    ).called(1);
  });

  testWidgets('Crea da Viaggi apre lo stesso foglio e lo segna da Viaggi', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.byKey(const Key('nav_trips')));
    await tester.pumpAndSettle();
    await openCreate(tester);
    expect(find.byType(CreateSheet), findsOneWidget);
    verify(
      () => analytics.logEvent('create_tapped', properties: {'tab': 'trips'}),
    ).called(1);
  });

  group('scelta nel foglio Crea', () {
    testWidgets('Scansiona con AI apre il selettore immagini', (tester) async {
      await pumpShell(tester);
      await openCreate(tester);
      await tester.tap(find.byKey(const Key('create_ai_scan')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      verify(
        () => analytics.logEvent(
          'create_sheet_choice',
          properties: {'choice': 'ai_scan', 'tab': 'houses'},
        ),
      ).called(1);
    });

    testWidgets('"Scrivili a mano" apre la casa con il rapid fire', (
      tester,
    ) async {
      await pumpShell(tester);
      await openCreate(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('create_manual_items')),
          matching: find.byIcon(Icons.edit_outlined),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('HOUSE a add=manual'), findsOneWidget);
    });

    testWidgets('Nuovo viaggio apre il wizard', (tester) async {
      await pumpShell(tester);
      await openCreate(tester);
      await tester.tap(find.byKey(const Key('create_new_trip')));
      await tester.pumpAndSettle();
      expect(find.text('NEW TRIP'), findsOneWidget);
    });

    testWidgets('Valigia con AI apre il nuovo viaggio con ai=1 e lo traccia', (
      tester,
    ) async {
      await pumpShell(tester);
      await openCreate(tester);
      await tester.tap(find.byKey(const Key('create_ai_suitcase')));
      await tester.pumpAndSettle();
      expect(find.text('NEW TRIP AI'), findsOneWidget);
      verify(
        () => analytics.logEvent(
          'create_sheet_choice',
          properties: {'choice': 'ai_suitcase', 'tab': 'houses'},
        ),
      ).called(1);
    });

    testWidgets('chiudere il foglio non fa nulla', (tester) async {
      await pumpShell(tester);
      await openCreate(tester);
      Navigator.of(tester.element(find.byType(CreateSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CreateSheet), findsNothing);
      expect(find.text('HOUSES'), findsOneWidget);
      verifyNever(
        () => analytics.logEvent(
          'create_sheet_choice',
          properties: any(named: 'properties'),
        ),
      );
    });
  });
}
