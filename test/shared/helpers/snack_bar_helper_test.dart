import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pack_log/shared/helpers/snack_bar_helper.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

import '../../helpers/memory_asset_loader.dart';

void main() {
  testWidgets("showUndo mostra il messaggio e l'azione Annulla", (
    tester,
  ) async {
    var undone = 0;
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
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AppSnackBar.showUndo(
                    context,
                    'Capo tolto',
                    onUndo: () => undone++,
                  ),
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // EasyLocalization carica le traduzioni in modo asincrono.
    await tester.pump();
    await tester.tap(find.text('apri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Capo tolto'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Annulla'), findsOneWidget);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Annulla'));
    await tester.pump();

    expect(undone, 1);
  });
}
