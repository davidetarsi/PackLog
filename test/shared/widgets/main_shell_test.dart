import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/items/view/add_items_sheet.dart';
import 'package:pack_log/shared/widgets/primary_action_button.dart';
import 'package:pack_log/shared/widgets/main_shell.dart';

class _MockAnalytics extends Mock implements AppAnalyticsService {}

class _FakeHouseNotifier extends HouseNotifier {
  _FakeHouseNotifier(this.houses);
  final List<HouseModel> houses;
  @override
  Future<List<HouseModel>> build() async => houses;
}

/// Case mai caricate: simula l'avvio, prima che il DB risponda.
class _LoadingHouseNotifier extends HouseNotifier {
  @override
  Future<List<HouseModel>> build() => Completer<List<HouseModel>>().future;
}

class _FakeSyncing extends Syncing {
  _FakeSyncing(this._value);
  final bool _value;
  @override
  bool build() => _value;
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
      GoRoute(path: '/new-trip', builder: (_, _) => const Text('NEW TRIP')),
      GoRoute(
        path: '/houses/:id/ai-import',
        builder: (_, state) => Text('AI IMPORT ${state.pathParameters['id']}'),
      ),
    ],
  );

  Future<void> pumpShell(
    WidgetTester tester,
    List<HouseModel> houses, {
    bool syncing = false,
    bool housesLoading = false,
  }) async {
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
              () => housesLoading
                  ? _LoadingHouseNotifier()
                  : _FakeHouseNotifier(houses),
            ),
            syncingProvider.overrideWith(() => _FakeSyncing(syncing)),
          ],
          child: MaterialApp.router(routerConfig: buildRouter()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleLabel(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets('la barra ha solo Case e Viaggi', (tester) async {
    await pumpShell(tester, [_house('a')]);
    expect(find.byKey(const Key('nav_houses')), findsOneWidget);
    expect(find.byKey(const Key('nav_trips')), findsOneWidget);
    expect(find.byIcon(Icons.person_3_outlined), findsNothing);
    await settleLabel(tester);
  });

  testWidgets('in Case il bottone apre il foglio Aggiungi oggetti', (
    tester,
  ) async {
    await pumpShell(tester, [_house('a')]);
    await tester.tap(find.byKey(const Key('primary_action_button')));
    await tester.pumpAndSettle();
    expect(find.byType(AddItemsSheet), findsOneWidget);
    verify(
      () => analytics.logEvent(
        'primary_action_tapped',
        properties: {'tab': 'houses', 'action': 'add_items', 'enabled': true},
      ),
    ).called(1);
    await settleLabel(tester);
  });

  bool buttonEnabled(WidgetTester tester) => tester
      .widget<PrimaryActionButton>(
        find.byKey(const Key('primary_action_button')),
      )
      .enabled;

  testWidgets('senza case (e senza sync) il bottone è spento e avvisa', (
    tester,
  ) async {
    await pumpShell(tester, const []);
    expect(buttonEnabled(tester), isFalse);
    await tester.tap(find.byKey(const Key('primary_action_button')));
    await tester.pump();
    expect(find.byType(AddItemsSheet), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    verify(
      () => analytics.logEvent(
        'primary_action_tapped',
        properties: {'tab': 'houses', 'action': 'add_items', 'enabled': false},
      ),
    ).called(1);
    await settleLabel(tester);
  });

  testWidgets('lista vuota con sync in corso: bottone acceso, tocco inerte', (
    tester,
  ) async {
    await pumpShell(tester, const [], syncing: true);
    expect(buttonEnabled(tester), isTrue);
    await tester.tap(find.byKey(const Key('primary_action_button')));
    await tester.pumpAndSettle();
    expect(find.byType(AddItemsSheet), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    verifyNever(
      () => analytics.logEvent(
        'primary_action_tapped',
        properties: any(named: 'properties'),
      ),
    );
    await settleLabel(tester);
  });

  testWidgets('case in caricamento: bottone acceso, tocco inerte', (
    tester,
  ) async {
    await pumpShell(tester, const [], housesLoading: true);
    expect(buttonEnabled(tester), isTrue);
    await tester.tap(find.byKey(const Key('primary_action_button')));
    await tester.pump();
    expect(find.byType(AddItemsSheet), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await settleLabel(tester);
  });

  testWidgets('in Viaggi il bottone apre Nuovo viaggio', (tester) async {
    await pumpShell(tester, [_house('a')]);
    await tester.tap(find.byKey(const Key('nav_trips')));
    await tester.pumpAndSettle();
    expect(find.text('TRIPS'), findsOneWidget);

    await tester.tap(find.byKey(const Key('primary_action_button')));
    await tester.pumpAndSettle();
    expect(find.text('NEW TRIP'), findsOneWidget);
    await settleLabel(tester);
  });
}
