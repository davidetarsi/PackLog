import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';
import 'package:pack_log/features/items/model/clothing_labels.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/user_colors_provider.dart';
import 'package:pack_log/features/items/view/item_sheet.dart';
import 'package:pack_log/features/items/widgets/category_pill.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_asset_loader.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  const maglia = ClothingAnalysisResult(
    name: 'Maglia blu',
    category: 'Upper Body',
    subCategory: 'Sweater',
    baseColor: 'Blu',
    pattern: 'Solid',
    coverage: 'Long',
    fit: 'Regular',
    warmth: 4,
    formality: 'Casual',
    activityTags: ['Everyday'],
    appCategory: 'vestiti',
    extras: {'waterResistance': 0},
  );

  // Esito dell'ultima apertura: `finished` diventa true quando la scheda chiude.
  var finished = false;
  ClothingAnalysisResult? returned;

  /// Un'app con le traduzioni in memoria e i colori dell'utente vuoti.
  Widget app(Widget Function(BuildContext) home) {
    return EasyLocalization(
      supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
      path: 'assets/translations',
      assetLoader: MemoryAssetLoader(readAppTranslations()),
      fallbackLocale: const Locale('en', 'US'),
      startLocale: const Locale('it', 'IT'),
      saveLocale: false,
      child: ProviderScope(
        overrides: [userColorsProvider.overrideWith((ref) async => const [])],
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: AppTheme.light,
            home: Builder(builder: home),
          ),
        ),
      ),
    );
  }

  /// Apre la scheda dal bottone "Apri" e ne aspetta la chiusura o il salvataggio.
  Future<void> open(WidgetTester tester, ClothingAnalysisResult result) async {
    // Abbastanza alto da mostrare la scheda con i dettagli senza scorrere.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    finished = false;
    returned = null;

    await tester.pumpWidget(
      app(
        (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('apri'),
              onPressed: () async {
                returned = await showScanItemSheet(context, result: result);
                finished = true;
              },
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apri')));
    await tester.pumpAndSettle();
  }

  CategoryPillState pillOf(WidgetTester tester, ItemCategory category) => tester
      .widget<CategoryPill>(
        find.byWidgetPredicate(
          (w) => w is CategoryPill && w.category == category,
        ),
      )
      .pillState;

  VoidCallback? onSave(WidgetTester tester) => tester
      .widget<DsButton>(find.byKey(const Key('item_sheet_save')))
      .onPressed;

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('item_sheet_save')));
    await tester.tap(find.byKey(const Key('item_sheet_save')));
    await tester.pumpAndSettle();
  }

  group('scheda dalla scansione', () {
    testWidgets(
      'senza ⋯, Spazio, Quantità e Nota; con nome, categoria e dettagli',
      (tester) async {
        await open(tester, maglia);

        expect(find.text('items.edit_item'.tr()), findsOneWidget);
        expect(find.byKey(const Key('item_sheet_menu')), findsNothing);
        expect(find.text('items.space_label'.tr()), findsNothing);
        expect(find.text('items.quantity'.tr()), findsNothing);
        expect(find.text('items.note_label'.tr()), findsNothing);

        final name = tester.widget<TextFormField>(
          find.descendant(
            of: find.byKey(const Key('item_sheet_name')),
            matching: find.byType(TextFormField),
          ),
        );
        expect(name.controller!.text, 'Maglia blu');
        expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.forced);
        expect(find.byKey(const Key('clothing_type_row')), findsOneWidget);
        expect(find.text(warmthLabel(4)), findsOneWidget);
      },
    );

    testWidgets('un risultato che non è un capo non mostra i dettagli', (
      tester,
    ) async {
      await open(
        tester,
        const ClothingAnalysisResult(
          name: 'Shampoo',
          category: 'Not Clothing',
          baseColor: '',
          pattern: '',
          coverage: '',
          fit: '',
          warmth: 3,
          formality: 'Casual',
          activityTags: [],
          appCategory: 'toiletries',
        ),
      );

      expect(find.byKey(const Key('clothing_type_row')), findsNothing);
      expect(pillOf(tester, ItemCategory.toiletries), CategoryPillState.forced);
    });

    testWidgets('Salva è spento finché non si cambia qualcosa', (tester) async {
      await open(tester, maglia);
      expect(onSave(tester), isNull);

      await tester.tap(find.text(warmthLabel(2)));
      await tester.pumpAndSettle();
      expect(onSave(tester), isNotNull);
    });

    testWidgets(
      'Pioggia cambiata e Salva: il capo restituito ha il valore nuovo e senza dubbio',
      (tester) async {
        await open(
          tester,
          maglia.withDoubts(const ['waterResistance', 'warmth']),
        );

        await tester.tap(find.text(waterResistanceLabel(2)));
        await tester.pumpAndSettle();
        await tapSave(tester);

        expect(finished, isTrue);
        expect(returned, isNotNull);
        expect(returned!.waterResistance, 2);
        expect(returned!.doubts, ['warmth']);
        expect(returned!.name, 'Maglia blu');
      },
    );

    testWidgets('nome cambiato: il capo restituito ha il nome nuovo', (
      tester,
    ) async {
      await open(tester, maglia);

      await tester.enterText(
        find.byKey(const Key('item_sheet_name')),
        'Giacca blu',
      );
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(returned!.name, 'Giacca blu');
      expect(returned!.warmth, 4);
    });

    testWidgets('categoria toccata: il capo restituito ha il suo appCategory', (
      tester,
    ) async {
      await open(tester, maglia);

      await tester.tap(find.text('Varie'));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(returned!.appCategory, 'varie');
    });

    testWidgets('chiusura senza Salva: nessun capo restituito', (tester) async {
      await open(tester, maglia);

      await tester.enterText(
        find.byKey(const Key('item_sheet_name')),
        'Altro nome',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet_close')));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
      expect(returned, isNull);
    });
  });
}
