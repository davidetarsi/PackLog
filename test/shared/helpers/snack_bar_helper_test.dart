import 'dart:ui' as ui;

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

  Future<void> pumpHost(
    WidgetTester tester,
    void Function(BuildContext context) action,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => action(context),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('showAction: messaggio, azione e chiave', (tester) async {
    var retried = 0;
    await pumpHost(
      tester,
      (context) => AppSnackBar.showAction(
        context,
        'Errore del selettore',
        actionLabel: 'Riprova',
        onAction: () => retried++,
        key: const Key('ai_picker_error'),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('ai_picker_error')), findsOneWidget);
    expect(find.text('Errore del selettore'), findsOneWidget);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Riprova'));
    await tester.pump();

    expect(retried, 1);
  });

  testWidgets('senza ScaffoldMessenger non lancia', (tester) async {
    await tester.pumpWidget(
      Theme(
        data: AppTheme.light,
        child: Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Builder(
            builder: (context) => GestureDetector(
              onTap: () => AppSnackBar.showAction(
                context,
                'Scansione annullata',
                actionLabel: 'Riprova',
                onAction: () {},
              ),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('showErrorOn usa il messenger passato', (tester) async {
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    AppSnackBar.showErrorOn(messenger, 'Cancellazione fallita');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cancellazione fallita'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
      AppTheme.light.colorScheme.error,
    );
  });
}
