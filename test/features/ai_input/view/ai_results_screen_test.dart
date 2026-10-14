import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/ai_input/model/ai_import_state.dart';
import 'package:pack_log/features/ai_input/providers/ai_import_notifier.dart';
import 'package:pack_log/features/ai_input/view/ai_results_screen.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/fakes.dart'
    show aiResultsState, createPhotoFixtures, photoShirt;
import '../../../screenshots/support/seed.dart' show kHomeId, kEmptyHouseId;

class _FakeAiImport extends AiImportNotifier {
  _FakeAiImport(this._initial);
  final AiImportState _initial;
  List<File>? processedFiles;

  @override
  AiImportState build() => _initial;

  void emit(AiImportState next) => state = next;

  @override
  Future<void> processFiles(List<File> files) async {
    processedFiles = files;
  }

  @override
  Future<void> retryFailed() async {}
}

class _FakeHouseNotifier extends HouseNotifier {
  _FakeHouseNotifier(this.houses);
  final List<HouseModel> houses;

  @override
  Future<List<HouseModel>> build() async => houses;
}

class _FakeItemNotifier extends ItemNotifier {
  _FakeItemNotifier(this.items, {this.isLoading = false});
  final List<ItemModel> items;
  final bool isLoading;

  @override
  Future<List<ItemModel>> build(String houseId) =>
      isLoading ? Completer<List<ItemModel>>().future : Future.value(items);
}

class _MockItemRepository extends Mock implements ItemRepository {}

class _MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class _MockCoreAnalyticsService extends Mock implements CoreAnalyticsService {}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader(this.translations);

  final Map<String, Map<String, dynamic>> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      translations[locale.languageCode] ?? translations['en']!;
}

late AssetLoader _assetLoader;

class _TestApp {
  _TestApp(this.tester, this.container, this.router, this.itemRepository);

  final WidgetTester tester;
  final ProviderContainer container;
  final GoRouter router;
  final _MockItemRepository itemRepository;

  Future<void> finish() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    await tester.pump();
  }
}

final _home = HouseModel(
  id: kHomeId,
  name: 'Casa Milano',
  iconName: 'apartment',
  isPrimary: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _emptyHouse = HouseModel(
  id: kEmptyHouseId,
  name: 'Casa vuota',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _clothes = [
  ItemModel(
    id: 'item-0',
    houseId: kHomeId,
    name: 'T-shirt bianca',
    category: ItemCategory.vestiti,
    quantity: 1,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
];

GoRouter _router() {
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
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
}

Future<_TestApp> _openResults(
  WidgetTester tester, {
  AiImportState? state,
  HouseModel? house,
  List<HouseModel>? houses,
  List<ItemModel>? items,
  bool loadingItems = false,
}) async {
  final itemRepository = _MockItemRepository();
  when(
    () => itemRepository.saveAiItemsToHouse(
      houseId: any(named: 'houseId'),
      newItems: any(named: 'newItems'),
      metadataByItemId: any(named: 'metadataByItemId'),
    ),
  ).thenAnswer((_) async => 0);
  final sync = _MockSyncOrchestrator();
  when(() => sync.requestSync()).thenReturn(null);
  final analytics = _MockCoreAnalyticsService();
  final initial = state ?? aiResultsState();
  final container = ProviderContainer(
    overrides: [
      aiImportNotifierProvider.overrideWith(() => _FakeAiImport(initial)),
      houseNotifierProvider.overrideWith(
        () => _FakeHouseNotifier(houses ?? [house ?? _home, _emptyHouse]),
      ),
      itemNotifierProvider(kHomeId).overrideWith(
        () => _FakeItemNotifier(items ?? _clothes, isLoading: loadingItems),
      ),
      itemNotifierProvider(
        kEmptyHouseId,
      ).overrideWith(() => _FakeItemNotifier(const [])),
      itemRepositoryProvider.overrideWithValue(itemRepository),
      syncOrchestratorProvider.overrideWith((_) => sync),
      coreAnalyticsServiceProvider.overrideWithValue(analytics),
    ],
  );
  final router = _router();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      startLocale: const Locale('it', 'IT'),
      saveLocale: false,
      assetLoader: _assetLoader,
      child: UncontrolledProviderScope(
        container: container,
        child: Builder(
          builder: (context) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  router.push('/houses/$kHomeId');
  await tester.pumpAndSettle();
  router.push('/houses/$kHomeId/ai-import/results');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return _TestApp(tester, container, router, itemRepository);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await createPhotoFixtures();
    _assetLoader = _TestAssetLoader({
      'it':
          jsonDecode(File('assets/translations/it-IT.json').readAsStringSync())
              as Map<String, dynamic>,
      'en':
          jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
              as Map<String, dynamic>,
    });
  });

  testWidgets('mostra righe e CTA anche con risultati iniziali già pronti', (
    tester,
  ) async {
    final app = await _openResults(tester);
    expect(find.byType(AiResultsScreen), findsOneWidget);
    expect(find.text('Camicia di lino azzurra'), findsOneWidget);
    expect(find.text('T-shirt bianca'), findsOneWidget);
    expect(find.text('Jeans slim blu scuro'), findsOneWidget);
    expect(find.text('Salva: 3 nuovi'), findsOneWidget);
    expect(find.text('T-shirt · bianco · tinta unita'), findsOneWidget);
    expect(find.text('Foto 1 · 2 capi'), findsOneWidget);
    expect(find.byKey(const Key('ai_already_here')), findsNWidgets(3));
    await app.finish();
  });

  testWidgets('plurali singolari per un solo capo nuovo o aggiornato', (
    tester,
  ) async {
    final initial = aiResultsState();
    final oneItem = initial.copyWith(
      photoGroups: [
        initial.photoGroups.first.copyWith(
          results: [initial.photoGroups.first.results.first],
        ),
      ],
    );
    final app = await _openResults(tester, state: oneItem);
    expect(find.text('1 capo identificato'), findsOneWidget);
    expect(find.text('Foto 1 · 1 capo'), findsOneWidget);
    expect(find.text('Salva: 1 nuovo'), findsOneWidget);
    await EasyLocalization.of(
      tester.element(find.byType(AiResultsScreen)),
    )!.setLocale(const Locale('en', 'US'));
    await tester.pumpAndSettle();
    expect(find.text('1 item identified'), findsOneWidget);
    expect(find.text('Photo 1 · 1 item'), findsOneWidget);
    expect(find.text('Save: 1 new'), findsOneWidget);

    (app.container.read(aiImportNotifierProvider.notifier) as _FakeAiImport)
        .emit(
          oneItem.copyWith(
            photoGroups: [
              oneItem.photoGroups.single.copyWith(
                linkedItemIds: const {0: 'item-0'},
              ),
            ],
          ),
        );
    await tester.pump();
    expect(find.text('Save: 1 updated'), findsOneWidget);
    await app.finish();
  });

  testWidgets('escludere e includere lascia la riga e aggiorna la CTA', (
    tester,
  ) async {
    final app = await _openResults(tester);
    final checkbox = find.descendant(
      of: find.byKey(const ValueKey('ai_result_0_1')),
      matching: find.byType(Checkbox),
    );
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(find.text('Salva: 2 nuovi'), findsOneWidget);
    expect(find.text('T-shirt bianca'), findsOneWidget);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(find.text('Salva: 3 nuovi'), findsOneWidget);
    await app.finish();
  });

  testWidgets('rinomina due capi e Salva invia subito i nomi aggiornati', (
    tester,
  ) async {
    final app = await _openResults(tester);
    for (final (index, name) in const [
      (0, 'Camicia rinominata'),
      (1, 'T-shirt rinominata'),
    ]) {
      final card = find.byKey(ValueKey('ai_result_0_$index'));
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.byKey(const Key('ai_result_name')),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.descendant(of: card, matching: find.byType(TextField)),
        name,
      );
    }
    await tester.tap(find.text('Salva: 3 nuovi'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => app.itemRepository.saveAiItemsToHouse(
        houseId: captureAny(named: 'houseId'),
        newItems: captureAny(named: 'newItems'),
        metadataByItemId: captureAny(named: 'metadataByItemId'),
      ),
    ).captured;
    final savedItems = captured[1] as List<ItemModel>;
    expect(
      savedItems.map((item) => item.name),
      containsAll(['Camicia rinominata', 'T-shirt rinominata']),
    );
    await app.finish();
  });

  testWidgets('casa vuota nasconde C’è già?', (tester) async {
    final app = await _openResults(
      tester,
      state: aiResultsState(houseId: kEmptyHouseId),
    );
    expect(find.byKey(const Key('ai_already_here')), findsNothing);
    await app.finish();
  });

  testWidgets('cambiare casa aggiorna destinazione e disponibilità collega', (
    tester,
  ) async {
    final app = await _openResults(tester);
    await tester.tap(find.byKey(const Key('ai_destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa vuota'));
    await tester.pumpAndSettle();
    expect(find.text('in Casa vuota'), findsOneWidget);
    expect(find.byKey(const Key('ai_already_here')), findsNothing);

    await tester.tap(find.byKey(const Key('ai_destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa Milano'));
    await tester.pumpAndSettle();
    expect(find.text('in Casa Milano'), findsOneWidget);
    expect(find.byKey(const Key('ai_already_here')), findsNWidgets(3));
    await app.finish();
  });

  testWidgets('C è già confronta categorie AI mappate con gli enum reali', (
    tester,
  ) async {
    final initial = aiResultsState();
    final upperBody = initial.copyWith(
      photoGroups: [
        initial.photoGroups.first.copyWith(
          results: [
            initial.photoGroups.first.results.first.copyWith(
              category: 'Upper Body',
            ),
          ],
        ),
      ],
    );
    final app = await _openResults(
      tester,
      state: upperBody,
      items: [_clothes.single.copyWith(category: ItemCategory.varie)],
    );
    expect(find.byKey(const Key('ai_already_here')), findsNothing);

    (app.container.read(aiImportNotifierProvider.notifier) as _FakeAiImport)
        .emit(
          upperBody.copyWith(
            photoGroups: [
              upperBody.photoGroups.single.copyWith(
                results: [
                  upperBody.photoGroups.single.results.single.copyWith(
                    category: 'Accessory',
                  ),
                ],
              ),
            ],
          ),
        );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai_already_here')), findsOneWidget);
    await app.finish();
  });

  testWidgets('linked id mostra dettaglio aggiornato e permette Annulla', (
    tester,
  ) async {
    final initial = aiResultsState();
    final state = initial.copyWith(
      photoGroups: [
        initial.photoGroups.first.copyWith(linkedItemIds: const {0: 'item-0'}),
        initial.photoGroups.last,
      ],
    );
    final app = await _openResults(tester, state: state);
    expect(
      find.text('Già in casa: «T-shirt bianca» · dettagli aggiunti'),
      findsOneWidget,
    );
    expect(find.text('Salva: 2 nuovi · 1 aggiornato'), findsOneWidget);
    await tester.tap(find.text('Annulla').first);
    await tester.pumpAndSettle();
    expect(find.text('Salva: 3 nuovi'), findsOneWidget);
    await app.finish();
  });

  testWidgets(
    'linked id senza nome caricato resta collegato con testo neutro',
    (tester) async {
      final initial = aiResultsState();
      final state = initial.copyWith(
        photoGroups: [
          initial.photoGroups.first.copyWith(
            linkedItemIds: const {0: 'missing'},
          ),
          initial.photoGroups.last,
        ],
      );
      final app = await _openResults(tester, state: state);
      expect(
        find.text('Oggetto già in casa · dettagli aggiunti'),
        findsOneWidget,
      );
      expect(find.text('Salva: 2 nuovi · 1 aggiornato'), findsOneWidget);
      await app.finish();
    },
  );

  testWidgets(
    'linked id resta distinto da un nuovo capo mentre la casa carica',
    (tester) async {
      final initial = aiResultsState();
      final state = initial.copyWith(
        photoGroups: [
          initial.photoGroups.first.copyWith(
            linkedItemIds: const {0: 'item-0'},
          ),
          initial.photoGroups.last,
        ],
      );
      final app = await _openResults(tester, state: state, loadingItems: true);
      expect(
        find.text('Oggetto già in casa · dettagli aggiunti'),
        findsOneWidget,
      );
      expect(find.text('Salva: 2 nuovi · 1 aggiornato'), findsOneWidget);
      await app.finish();
    },
  );

  testWidgets('anteprima mostra tutta la foto e apre il visualizzatore', (
    tester,
  ) async {
    final app = await _openResults(tester);
    expect(tester.widget<Image>(find.byType(Image).first).fit, BoxFit.contain);
    await tester.tap(find.byKey(const Key('ai_photo_preview')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai_photo_viewer')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await app.finish();
  });

  testWidgets('destinazione lunga non va in overflow su schermo stretto', (
    tester,
  ) async {
    final app = await _openResults(
      tester,
      house: _home.copyWith(
        name:
            'Casa con un nome molto lungo che deve restare leggibile sullo schermo',
      ),
    );
    tester.view.physicalSize = const Size(960, 2730);
    tester.view.devicePixelRatio = 3;
    await tester.pump();
    expect(find.byKey(const Key('ai_destination')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.finish();
  });

  testWidgets('analisi vuota completata non mostra successo né esce', (
    tester,
  ) async {
    final app = await _openResults(
      tester,
      state: const AiImportState(isLoading: true),
    );
    (app.container.read(aiImportNotifierProvider.notifier) as _FakeAiImport)
        .emit(const AiImportState());
    await tester.pumpAndSettle();
    expect(find.byType(AiResultsScreen), findsOneWidget);
    expect(find.text('Risultati salvati con successo.'), findsNothing);
    await app.finish();
  });

  testWidgets('il picker di riprova usa una foto per l ultimo slot', (
    tester,
  ) async {
    final initial = aiResultsState();
    final fourEmptyPhotos = initial.copyWith(
      photoGroups: List.generate(
        4,
        (_) => PhotoGroup(photo: photoShirt, results: const []),
      ),
    );
    final app = await _openResults(tester, state: fourEmptyPhotos);
    const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
          calls.add(call);
          if (call.method == 'pickImage') return '/tmp/retry.jpg';
          return ['/tmp/retry-1.jpg', '/tmp/retry-2.jpg'];
        });

    await tester.tap(find.text('Scegli un\'altra foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();

    expect(calls.map((call) => call.method), ['pickImage']);
    expect(calls.single.arguments['source'], ImageSource.gallery.index);
    expect(
      (app.container.read(aiImportNotifierProvider.notifier) as _FakeAiImport)
          .processedFiles,
      hasLength(1),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, null);
    await app.finish();
  });
}
