import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/features/ai_input/model/ai_import_state.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';
import 'package:pack_log/features/ai_input/providers/ai_import_notifier.dart';
import 'package:pack_log/features/ai_input/view/ai_results_screen.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/shared/widgets/ds_icon_button.dart';

/// Verifica la fine del flusso di scansione AI: lo stack radice deve restare
/// [shell, dettaglio casa], senza `go()` che butterebbe via la shell.
class _FakeAiImport extends AiImportNotifier {
  _FakeAiImport(this._initial);
  final AiImportState _initial;

  @override
  AiImportState build() => _initial;

  void emit(AiImportState next) => state = next;

  @override
  Future<void> saveItems() async {
    state = state.copyWith(isLoading: true);
    state = const AiImportState();
  }
}

class _FakeHouseNotifier extends HouseNotifier {
  @override
  Future<List<HouseModel>> build() async => [_house];
}

class _FakeItemNotifier extends ItemNotifier {
  @override
  Future<List<ItemModel>> build(String houseId) async => const [];
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      translations;
}

final _house = HouseModel(
  id: 'a',
  name: 'Casa a',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _garment = ClothingAnalysisResult(
  name: 'Camicia',
  category: 'vestiti',
  baseColor: 'Azzurro',
  pattern: 'Tinta unita',
  coverage: 'Busto',
  fit: 'Regular',
  warmth: 2,
  formality: 'Casual',
  activityTags: [],
);

void main() {
  late AssetLoader assetLoader;
  late File photo;
  late AiImportState resultsState;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    assetLoader = _TestAssetLoader(
      jsonDecode(File('assets/translations/it-IT.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final dir = Directory.systemTemp.createTempSync('ai_exit_test');
    photo = File('${dir.path}/p.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        ),
      );
    resultsState = AiImportState(
      selectedHouseId: 'a',
      photoGroups: [
        PhotoGroup(photo: photo, results: const [_garment]),
      ],
    );
  });

  late GoRouter router;
  late _FakeAiImport fakeAi;

  /// Router minimo con le stesse route (e gli stessi nomi) di app_router.dart.
  GoRouter buildRouter(GlobalKey<NavigatorState> rootKey) => GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'houses',
                builder: (_, _) => const Text('SHELL'),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/houses/:id',
        name: 'house-detail',
        parentNavigatorKey: rootKey,
        builder: (_, state) => Text('DETAIL ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/houses/:id/ai-import/results',
        name: 'ai-import-results',
        parentNavigatorKey: rootKey,
        builder: (_, state) => AiResultsScreen(
          houseId: state.pathParameters['id'],
          isFirstTimeOnboarding: false,
        ),
      ),
    ],
  );

  Future<void> pumpApp(
    WidgetTester tester, {
    required bool fromDetail,
    bool emitResults = true,
  }) async {
    fakeAi = _FakeAiImport(const AiImportState(isLoading: true));
    router = buildRouter(GlobalKey<NavigatorState>());
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        saveLocale: false,
        assetLoader: assetLoader,
        child: ProviderScope(
          overrides: [
            aiImportNotifierProvider.overrideWith(() => fakeAi),
            houseNotifierProvider.overrideWith(_FakeHouseNotifier.new),
            itemNotifierProvider('a').overrideWith(_FakeItemNotifier.new),
          ],
          child: Builder(
            builder: (context) => MaterialApp.router(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (fromDetail) {
      router.push('/houses/a');
      await tester.pumpAndSettle();
    }
    router.push('/houses/a/ai-import/results');
    // Lo stato di caricamento ha un'animazione infinita: niente pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Transizione caricamento → risultati, come nell'app.
    if (emitResults) {
      fakeAi.emit(resultsState);
      await tester.pumpAndSettle();
    }
  }

  /// Stack radice atteso: indietro dal dettaglio torna alla shell, e dalla
  /// shell non si può più tornare (non resta un secondo dettaglio sotto).
  Future<void> expectShellThenDetailOnly(WidgetTester tester) async {
    expect(find.text('DETAIL a'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('SHELL'), findsOneWidget);
    expect(find.text('DETAIL a', skipOffstage: false), findsNothing);
    expect(router.canPop(), isFalse);
  }

  testWidgets('X dal flusso partito dalla tab Case: [shell, dettaglio]', (
    tester,
  ) async {
    await pumpApp(tester, fromDetail: false);
    await tester.tap(find.byKey(const Key('ai_results_close')));
    await tester.pumpAndSettle();
    expect(find.text('Scartare i risultati?'), findsOneWidget);
    await tester.tap(find.text('Scarta'));
    await tester.pumpAndSettle();
    await expectShellThenDetailOnly(tester);
  });

  testWidgets('X dal flusso partito dal dettaglio: un solo dettaglio', (
    tester,
  ) async {
    await pumpApp(tester, fromDetail: true);
    await tester.tap(find.byKey(const Key('ai_results_close')));
    await tester.pumpAndSettle();
    expect(find.text('Scartare i risultati?'), findsOneWidget);
    await tester.tap(find.text('Scarta'));
    await tester.pumpAndSettle();
    await expectShellThenDetailOnly(tester);
  });

  testWidgets('salvataggio riuscito dalla tab Case: [shell, dettaglio]', (
    tester,
  ) async {
    await pumpApp(tester, fromDetail: false);
    await tester.tap(find.text('Salva: 1 nuovo'));
    await tester.pumpAndSettle();
    await expectShellThenDetailOnly(tester);
  });

  testWidgets('salvataggio riuscito dal dettaglio: un solo dettaglio', (
    tester,
  ) async {
    await pumpApp(tester, fromDetail: true);
    await tester.tap(find.text('Salva: 1 nuovo'));
    await tester.pumpAndSettle();
    await expectShellThenDetailOnly(tester);
  });

  testWidgets(
    'back durante loading resta sulla pagina; con zero pending esce',
    (tester) async {
      await pumpApp(tester, fromDetail: true, emitResults: false);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AiResultsScreen), findsOneWidget);
      expect(
        tester
            .widget<DsIconButton>(find.byKey(const Key('ai_results_close')))
            .onPressed,
        isNull,
      );

      fakeAi.emit(
        resultsState.copyWith(
          photoGroups: [
            resultsState.photoGroups.single.copyWith(excluded: const {0}),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pumpAndSettle();
      await expectShellThenDetailOnly(tester);
    },
  );

  testWidgets('doppio tap X senza pending non duplica il dettaglio', (
    tester,
  ) async {
    await pumpApp(tester, fromDetail: false);
    fakeAi.emit(
      resultsState.copyWith(
        photoGroups: [
          resultsState.photoGroups.single.copyWith(excluded: const {0}),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final close = find.byKey(const Key('ai_results_close'));
    await tester.tap(close);
    await tester.tap(close);
    await tester.pump();
    await tester.pumpAndSettle();
    await expectShellThenDetailOnly(tester);
  });
}
