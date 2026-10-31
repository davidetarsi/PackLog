import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/clothing_details.dart';
import 'package:pack_log/features/items/model/clothing_labels.dart';
import 'package:pack_log/features/items/providers/user_colors_provider.dart';
import 'package:pack_log/features/items/view/widgets/clothing_details_section.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_choice_pill.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_asset_loader.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  const details = ClothingDetails(
    subCategory: 'Sweater',
    color: 'Blu',
    warmth: 4,
    waterResistance: 0,
    formality: 'Casual',
    uses: {'Everyday'},
  );

  /// Monta la sezione con le traduzioni in memoria, così non si aspetta il
  /// caricamento asincrono dell'asset.
  Future<void> pump(
    WidgetTester tester, {
    required ClothingDetails value,
    required ValueChanged<ClothingDetails> onChanged,
    Set<String> doubts = const {},
    ValueChanged<String>? onDoubtResolved,
    ValueChanged<ClothingField>? onFieldTouched,
    List<String> userColors = const [],
  }) async {
    // Abbastanza alto da mostrare tutti i gruppi senza scorrere.
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
          overrides: [
            userColorsProvider.overrideWith((ref) async => userColors),
          ],
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: AppTheme.light,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ClothingDetailsSection(
                    details: value,
                    onChanged: onChanged,
                    doubts: doubts,
                    onDoubtResolved: onDoubtResolved,
                    onFieldTouched: onFieldTouched,
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

  /// Pillola con quell'etichetta, per leggerne lo stato di selezione.
  DsChoicePill pill(WidgetTester tester, String label) => tester.widget(
    find.byWidgetPredicate((w) => w is DsChoicePill && w.label == label),
  );

  testWidgets('mostra tipo, colore, calore, pioggia, stile e usi', (
    tester,
  ) async {
    await pump(tester, value: details, onChanged: (_) {});
    await tester.pumpAndSettle();

    expect(find.text('Tipo'), findsOneWidget);
    expect(find.text(clothingTypeLabel('Sweater')), findsOneWidget);
    expect(find.text('Colore'), findsOneWidget);
    expect(find.text('Calore'), findsOneWidget);
    expect(find.text('Pioggia'), findsOneWidget);
    expect(find.text('Stile'), findsOneWidget);
    expect(find.text('Usi'), findsOneWidget);
    expect(find.text('anche più di uno'), findsOneWidget);
    expect(pill(tester, colorLabel('Blu')).selected, isTrue);
    expect(pill(tester, warmthLabel(4)).selected, isTrue);
    expect(pill(tester, warmthLabel(3)).selected, isFalse);
    expect(pill(tester, activityLabel('Everyday')).selected, isTrue);
  });

  testWidgets('toccare un calore emette i dettagli con il calore nuovo', (
    tester,
  ) async {
    ClothingDetails? emitted;
    await pump(tester, value: details, onChanged: (d) => emitted = d);
    await tester.pumpAndSettle();

    await tester.tap(find.text(warmthLabel(2)));
    await tester.pumpAndSettle();

    expect(emitted, details.copyWith(warmth: 2));
  });

  testWidgets('negli usi l\'ultimo non si toglie', (tester) async {
    var calls = 0;
    await pump(tester, value: details, onChanged: (_) => calls++);
    await tester.pumpAndSettle();

    await tester.tap(find.text(activityLabel('Everyday')));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('i colori dell\'utente vengono dopo quelli di base', (
    tester,
  ) async {
    await pump(
      tester,
      value: details,
      onChanged: (_) {},
      userColors: const ['Verde salvia'],
    );
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<DsChoicePill>(find.byType(DsChoicePill))
        .map((p) => p.label)
        .toList();
    final salvia = labels.indexOf('Verde salvia');
    expect(salvia, greaterThan(labels.indexOf(colorLabel('Beige'))));
  });

  testWidgets('"+ Altro colore" aggiunge il colore scritto e lo seleziona', (
    tester,
  ) async {
    ClothingDetails? emitted;
    await pump(tester, value: details, onChanged: (d) => emitted = d);
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ Altro colore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Verde salvia ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(emitted?.color, 'Verde salvia');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('un colore non tra le scelte appare e risulta selezionato', (
    tester,
  ) async {
    await pump(
      tester,
      value: details.copyWith(color: 'Verde acqua'),
      onChanged: (_) {},
    );
    await tester.pumpAndSettle();

    expect(pill(tester, 'Verde acqua').selected, isTrue);
    expect(pill(tester, colorLabel('Blu')).selected, isFalse);
  });

  testWidgets('il picker del tipo è raggruppato e cambia il tipo', (
    tester,
  ) async {
    ClothingDetails? emitted;
    await pump(tester, value: details, onChanged: (d) => emitted = d);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('clothing_type_row')));
    await tester.pumpAndSettle();

    expect(find.text('Scegli il tipo'), findsOneWidget);
    expect(find.byType(DsGroupHeader), findsWidgets);
    await tester.tap(find.text(clothingTypeLabel('T-Shirt')));
    await tester.pumpAndSettle();

    expect(emitted?.subCategory, 'T-Shirt');
  });

  testWidgets('un dubbio mostra "da controllare" e il tocco lo risolve', (
    tester,
  ) async {
    final resolved = <String>[];
    await pump(
      tester,
      value: details,
      onChanged: (_) {},
      doubts: const {'warmth'},
      onDoubtResolved: resolved.add,
    );
    await tester.pumpAndSettle();

    expect(find.text('da controllare'), findsOneWidget);
    await tester.tap(find.text(warmthLabel(4)));
    await tester.pumpAndSettle();
    expect(resolved, ['warmth']);
  });

  testWidgets(
    'senza dettagli: il tipo dice di sceglierlo, nessun calore è scelto',
    (tester) async {
      await pump(tester, value: ClothingDetails.empty, onChanged: (_) {});

      expect(find.text('Scegli il tipo'), findsOneWidget);
      expect(pill(tester, warmthLabel(3)).selected, isFalse);
      expect(pill(tester, warmthLabel(4)).selected, isFalse);
      expect(pill(tester, activityLabel('Everyday')).selected, isFalse);
    },
  );

  group('onFieldTouched', () {
    testWidgets(
      'toccare la pillola già scelta conferma il campo, senza cambiarlo',
      (tester) async {
        final touched = <ClothingField>[];
        var changes = 0;
        await pump(
          tester,
          value: details,
          onChanged: (_) => changes++,
          onFieldTouched: touched.add,
        );

        await tester.tap(find.text(warmthLabel(4)));
        await tester.pumpAndSettle();

        expect(touched, [ClothingField.warmth]);
        expect(changes, 0);
      },
    );

    testWidgets('la scelta di un altro calore conferma il campo', (
      tester,
    ) async {
      final touched = <ClothingField>[];
      await pump(
        tester,
        value: details,
        onChanged: (_) {},
        onFieldTouched: touched.add,
      );

      await tester.tap(find.text(warmthLabel(2)));
      await tester.pumpAndSettle();

      expect(touched, [ClothingField.warmth]);
    });

    testWidgets('la formalità già scelta conferma il campo', (tester) async {
      final touched = <ClothingField>[];
      await pump(
        tester,
        value: details,
        onChanged: (_) {},
        onFieldTouched: touched.add,
      );

      await tester.tap(find.text(formalityLabel('Casual')));
      await tester.pumpAndSettle();

      expect(touched, [ClothingField.formality]);
    });

    testWidgets('il tipo scelto di nuovo, nel picker, conferma il tipo', (
      tester,
    ) async {
      final touched = <ClothingField>[];
      ClothingDetails? emitted;
      await pump(
        tester,
        value: details,
        onChanged: (d) => emitted = d,
        onFieldTouched: touched.add,
      );

      await tester.tap(find.byKey(const Key('clothing_type_row')));
      await tester.pumpAndSettle();
      // Il tipo attuale è scritto anche nella riga: la voce del picker è l'ultima.
      final option = find.text(clothingTypeLabel('Sweater')).last;
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();

      expect(touched, [ClothingField.type]);
      expect(emitted?.subCategory, 'Sweater');
    });

    testWidgets('ogni cambio di colore conferma il campo', (tester) async {
      final touched = <ClothingField>[];
      await pump(
        tester,
        value: details,
        onChanged: (_) {},
        onFieldTouched: touched.add,
      );

      // Toccare il colore già scelto lo toglie: è un cambio.
      await tester.tap(find.text(colorLabel('Blu')));
      await tester.pumpAndSettle();

      expect(touched, [ClothingField.color]);
    });

    testWidgets(
      'un uso in più conferma il campo, l\'ultimo che non si toglie no',
      (tester) async {
        final touched = <ClothingField>[];
        await pump(
          tester,
          value: details,
          onChanged: (_) {},
          onFieldTouched: touched.add,
        );

        await tester.tap(find.text(activityLabel('Everyday')));
        await tester.pumpAndSettle();
        expect(touched, isEmpty);

        await tester.tap(find.text(activityLabel('Beach')));
        await tester.pumpAndSettle();
        expect(touched, [ClothingField.uses]);
      },
    );
  });
}
