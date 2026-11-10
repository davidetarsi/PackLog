import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/widgets/category_pill.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_asset_loader.dart';
import '../../../screenshots/support/fonts.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await loadRealFonts();
  });

  testWidgets('pillole categoria su 320 con testo a 2.0: niente overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
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
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.light,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: AppConstants.categoryRowHeight,
                  child: Row(
                    children: [
                      for (final category in ItemCategory.values) ...[
                        if (category != ItemCategory.values.first)
                          const SizedBox(width: 4),
                        Expanded(
                          child: CategoryPill(
                            category: category,
                            pillState: CategoryPillState.forced,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byType(CategoryPill),
      findsNWidgets(ItemCategory.values.length),
    );
  });

  for (final (nome, tema) in [
    ('chiaro', AppTheme.light),
    ('scuro', AppTheme.dark),
  ]) {
    testWidgets(
      'tema $nome: ogni stato ha un fondo pieno, la lista non si vede '
      'attraverso',
      (tester) async {
        for (final stato in CategoryPillState.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: tema,
              home: Scaffold(
                body: SizedBox(
                  width: 80,
                  height: AppConstants.categoryRowHeight,
                  child: CategoryPill(
                    category: ItemCategory.vestiti,
                    pillState: stato,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final box = tester.widget<AnimatedContainer>(
            find.byType(AnimatedContainer),
          );
          final fondo = (box.decoration! as BoxDecoration).color!;
          expect(fondo.a, 1.0, reason: '$stato in tema $nome');
        }
      },
    );
  }
}
