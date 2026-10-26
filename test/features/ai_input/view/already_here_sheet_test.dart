import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/features/ai_input/model/ai_import_state.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';
import 'package:pack_log/features/ai_input/providers/ai_import_notifier.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/ai_input/view/widgets/already_here_sheet.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/fakes.dart';
import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

class _MockAnalytics extends Mock implements CoreAnalyticsService {}

class _JsonAssetLoader extends AssetLoader {
  const _JsonAssetLoader(this.translations);

  final Map<String, Map<String, dynamic>> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      translations[locale.languageCode]!;
}

class _SheetHouseNotifier extends HouseNotifier {
  @override
  Future<List<HouseModel>> build() async => [
    HouseModel(
      id: kHomeId,
      name: 'Casa vacanze in montagna con armadi e ripostigli',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
}

class _SheetItemNotifier extends ItemNotifier {
  @override
  Future<List<ItemModel>> build(String houseId) async => [
    for (var i = 0; i < 30; i++)
      ItemModel(
        id: 'long-$i',
        houseId: houseId,
        name: i < 10
            ? 'Maglia estiva riconosciuta variante numero $i'
            : 'Giacca impermeabile di cotone variante numero $i',
        category: ItemCategory.vestiti,
        quantity: 2,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];
}

class _RetrySheetItemNotifier extends ItemNotifier {
  static var builds = 0;

  @override
  Future<List<ItemModel>> build(String houseId) async {
    builds++;
    if (builds == 1) throw StateError('private diagnostic detail');
    return [
      ItemModel(
        id: 'retry-candidate',
        houseId: houseId,
        name: 'T-shirt bianca',
        category: ItemCategory.vestiti,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];
  }
}

ClothingAnalysisResult _scanned(String category) => ClothingAnalysisResult(
  name: 'T-shirt bianca',
  category: category,
  subCategory: 'T-shirt',
  baseColor: 'Bianco',
  pattern: 'Tinta unita',
  coverage: 'Busto',
  fit: 'Regular',
  warmth: 2,
  formality: 'Casual',
  activityTags: const [],
);

AiImportState _state(String category, {String? name}) => AiImportState(
  selectedHouseId: kHomeId,
  photoGroups: [
    PhotoGroup(
      photo: photoShirt,
      results: [_scanned(category).copyWith(name: name ?? 'T-shirt bianca')],
    ),
  ],
);

Future<void> _openResults(ScreenshotApp app) async {
  await app.push('/houses/$kHomeId');
  await app.push('/houses/$kHomeId/ai-import/results');
}

void main() {
  late _JsonAssetLoader isolatedAssetLoader;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await createPhotoFixtures();
    isolatedAssetLoader = _JsonAssetLoader({
      'it':
          jsonDecode(File('assets/translations/it-IT.json').readAsStringSync())
              as Map<String, dynamic>,
      'en':
          jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
              as Map<String, dynamic>,
    });
  });

  test('normalizza e conta una sola volta parole ripetute', () {
    final duplicated = _scanned('Upper Body').copyWith(
      name: 'T-shirt T-SHIRT biànca',
      subCategory: 'T-SHIRT',
      baseColor: 'Bianca',
    );
    final item = ItemModel(
      id: 'scored',
      houseId: kHomeId,
      name: 'T-SHIRT Bianca',
      category: ItemCategory.vestiti,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(alreadyHereScore(duplicated, item), 2);
    expect(
      alreadyHereScore(
        duplicated.copyWith(
          name: 'camicia elegante',
          subCategory: 'camicia manica lunga',
          baseColor: 'bianco sporco',
        ),
        item.copyWith(name: 'camicia manica lunga bianco sporco elegante'),
      ),
      6,
    );
  });

  testWidgets('filtra per categoria AI mappata e apre candidati manuali', (
    tester,
  ) async {
    final analytics = _MockAnalytics();
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(
            () => FakeAiImport(_state('Upper Body')),
          ),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
        ],
      ),
    );

    final repository = app.container.read(itemRepositoryProvider);
    await tester.runAsync(() async {
      await repository.insertMultipleItems([
        ItemModel(
          id: 'already-ai',
          houseId: kHomeId,
          name: 'T-shirt bianca AI',
          category: ItemCategory.vestiti,
          aiMetadata: '{}',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        ItemModel(
          id: 'other-category',
          houseId: kHomeId,
          name: 'T-shirt bianca wrong category',
          category: ItemCategory.elettronica,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
    });
    app.container.invalidate(itemNotifierProvider(kHomeId));
    await _openResults(app);

    await app.tap(find.byKey(const Key('ai_already_here')));
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThan(915 * 0.75),
    );
    expect(find.text("C'è già in Casa Milano?"), findsOneWidget);
    expect(find.text('Più simili · 2'), findsOneWidget);
    expect(find.text('T-shirt bianca'), findsWidgets);
    expect(find.text('T-shirt bianca wrong category'), findsNothing);
    expect(find.text('Aggiungi i dettagli'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    verify(
      () => analytics.trackAlreadyHereOpened(hasManualCandidates: true),
    ).called(1);
    expect(find.text('Maglione di lana'), findsNothing);
    await app.finish();
  });

  testWidgets('Accessory usa Varie e il gruppo altri si può espandere', (
    tester,
  ) async {
    final analytics = _MockAnalytics();
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(
            () => FakeAiImport(_state('Accessory', name: 'Occhiali da sole')),
          ),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
        ],
      ),
    );
    await _openResults(app);
    await app.tap(find.byKey(const Key('ai_already_here')));
    expect(find.text('Più simili · 1'), findsOneWidget);
    expect(find.textContaining('Altri oggetti'), findsOneWidget);
    expect(find.text('Aggiungi i dettagli'), findsNothing);
    expect(find.text('Passaporto'), findsNothing);
    await app.tap(find.textContaining('Altri oggetti'));
    expect(find.text('Passaporto'), findsOneWidget);
    expect(find.text('Borraccia'), findsOneWidget);
    await app.finish();
  });

  testWidgets(
    'viewport piccolo mantiene CTA e righe scorrevoli senza overflow',
    (tester) async {
      tester.view.physicalSize = const Size(960, 1704);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final analytics = _MockAnalytics();
      final container = ProviderContainer(
        overrides: [
          houseNotifierProvider.overrideWith(_SheetHouseNotifier.new),
          itemNotifierProvider(kHomeId).overrideWith(_SheetItemNotifier.new),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          startLocale: const Locale('it', 'IT'),
          saveLocale: false,
          assetLoader: isolatedAssetLoader,
          child: UncontrolledProviderScope(
            container: container,
            child: Builder(
              builder: (context) => MaterialApp(
                theme: AppTheme.light,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => FilledButton(
                      onPressed: () => showAlreadyHereSheet(
                        context,
                        houseId: kHomeId,
                        scanned: _scanned('Upper Body').copyWith(
                          name:
                              'Maglia estiva riconosciuta con didascalia lunga',
                        ),
                      ),
                      child: const Text('Apri'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Apri'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('sheet_close')), findsOneWidget);
      expect(find.text('x2'), findsWidgets);
      expect(
        find.text("Se c'è già, togli la spunta per non aggiungerlo."),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      final scrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        greaterThan(0),
      );
    },
  );

  testWidgets('errore mostra testo comprensibile e Riprova carica i dati', (
    tester,
  ) async {
    _RetrySheetItemNotifier.builds = 0;
    final analytics = _MockAnalytics();
    final container = ProviderContainer(
      overrides: [
        houseNotifierProvider.overrideWith(_SheetHouseNotifier.new),
        itemNotifierProvider(kHomeId).overrideWith(_RetrySheetItemNotifier.new),
        coreAnalyticsServiceProvider.overrideWithValue(analytics),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        assetLoader: isolatedAssetLoader,
        child: UncontrolledProviderScope(
          container: container,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Scaffold(
                body: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () => showAlreadyHereSheet(
                      context,
                      houseId: kHomeId,
                      scanned: _scanned('Upper Body'),
                    ),
                    child: const Text('Apri'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Apri'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.text('Impossibile caricare gli oggetti della casa. Riprova.'),
      findsOneWidget,
    );
    expect(find.textContaining('private diagnostic detail'), findsNothing);
    verifyNever(
      () => analytics.trackAlreadyHereOpened(
        hasManualCandidates: any(named: 'hasManualCandidates'),
      ),
    );

    await tester.tap(find.text('Riprova'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('T-shirt bianca'), findsWidgets);
    verify(
      () => analytics.trackAlreadyHereOpened(hasManualCandidates: true),
    ).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('X chiude il foglio senza collegare né scrivere nel database', (
    tester,
  ) async {
    final analytics = _MockAnalytics();
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(
            () => FakeAiImport(_state('Upper Body')),
          ),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
        ],
      ),
    );
    await _openResults(app);
    await app.tap(find.byKey(const Key('ai_already_here')));
    await app.tap(find.byKey(const Key('sheet_close')));

    expect(find.text('Salva: 1 nuovo'), findsOneWidget);
    verifyNever(
      () => analytics.trackAiItemsSaved(
        count: any(named: 'count'),
        isOnboarding: any(named: 'isOnboarding'),
      ),
    );
    await app.finish();
  });

  testWidgets('chiusura fuori dal foglio non collega il risultato', (
    tester,
  ) async {
    final analytics = _MockAnalytics();
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(
            () => FakeAiImport(_state('Upper Body')),
          ),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
        ],
      ),
    );
    await _openResults(app);
    await app.tap(find.byKey(const Key('ai_already_here')));
    await tester.tapAt(const Offset(8, 8));
    await app.settle();

    expect(find.byKey(const Key('sheet_close')), findsNothing);
    expect(find.text('Salva: 1 nuovo'), findsOneWidget);
    await app.finish();
  });

  testWidgets('due callback nello stesso frame aprono una sola sheet', (
    tester,
  ) async {
    final analytics = _MockAnalytics();
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(
            () => FakeAiImport(_state('Upper Body')),
          ),
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
        ],
      ),
    );
    await _openResults(app);
    final action = tester.widget<TextButton>(
      find.byKey(const Key('ai_already_here')),
    );
    action.onPressed!();
    action.onPressed!();
    await app.settle(frames: 16);

    expect(find.byKey(const Key('sheet_close')), findsOneWidget);
    verify(
      () => analytics.trackAlreadyHereOpened(hasManualCandidates: true),
    ).called(1);
    await app.tap(find.byKey(const Key('sheet_close')));
    await app.finish();
  });

  testWidgets('DsSheetHeader senza onClose non aggiunge il controllo X', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DsSheetHeader(title: 'Titolo')),
      ),
    );
    expect(find.byKey(const Key('sheet_close')), findsNothing);
  });
}
