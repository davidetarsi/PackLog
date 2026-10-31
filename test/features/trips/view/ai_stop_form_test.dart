import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/catalog/catalog.dart';
import 'package:pack_log/core/catalog/catalog_store.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/view/widgets/ai/ai_stop_form.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_choice_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../helpers/memory_asset_loader.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() => caricaCatalogoDelRepo());
  tearDown(() => CatalogStore.set(Catalog.vuoto));

  /// Il catalogo del repo cambiato: "Bicicletta" è disattivata, "Cene e serate" è
  /// attiva (già nel repo).
  Future<void> pump(
    WidgetTester tester, {
    required AiStopAnswers answers,
    required ValueChanged<AiStopAnswers> onChanged,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        assetLoader: MemoryAssetLoader(readAppTranslations()),
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        child: ProviderScope(
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: AppTheme.light,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiStopForm(
                    answers: answers,
                    onChanged: onChanged,
                    stopName: 'Lisbona',
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

  DsChoicePill pill(WidgetTester tester, String label) => tester.widget(
    find.byWidgetPredicate((w) => w is DsChoicePill && w.label == label),
  );

  bool mostrata(String label) => find
      .byWidgetPredicate((w) => w is DsChoicePill && w.label == label)
      .evaluate()
      .isNotEmpty;

  testWidgets('le attività da proporre: una voce disattivata non compare', (
    tester,
  ) async {
    await pump(tester, answers: const AiStopAnswers(), onChanged: (_) {});

    expect(mostrata('Cene e serate'), isTrue);
    expect(mostrata('Matrimoni e cerimonie'), isTrue);
    expect(mostrata('Bicicletta'), isFalse);
    expect(mostrata('Cena elegante'), isFalse);
  });

  testWidgets(
    'un viaggio salvato con una voce disattivata la mostra selezionata, con la sua etichetta',
    (tester) async {
      await pump(
        tester,
        answers: const AiStopAnswers(
          activities: ['formal_dinner', 'city'],
          stay: 'hotel',
        ),
        onChanged: (_) {},
      );

      expect(mostrata('Cena elegante'), isTrue);
      expect(pill(tester, 'Cena elegante').selected, isTrue);
      expect(pill(tester, 'Città e musei').selected, isTrue);
      expect(pill(tester, 'Mare').selected, isFalse);
    },
  );

  testWidgets('risalvando una tappa con una voce disattivata la si tiene', (
    tester,
  ) async {
    AiStopAnswers? salvate;
    await pump(
      tester,
      answers: const AiStopAnswers(activities: ['formal_dinner']),
      onChanged: (a) => salvate = a,
    );

    await tester.tap(find.text('Cene e serate'));
    await tester.pumpAndSettle();

    expect(salvate?.activities, ['formal_dinner', 'evenings']);
  });
}
