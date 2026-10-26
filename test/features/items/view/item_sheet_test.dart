import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/clothing_labels.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/view/item_sheet.dart';
import 'package:pack_log/features/items/widgets/category_pill.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  Future<ScreenshotApp> openCalzini(WidgetTester tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await app.go('/');
    await app.push('/houses/$kHomeId');
    await app.tap(find.text('Calzini'));
    return app;
  }

  String nameText(WidgetTester tester) => tester
      .widget<TextFormField>(find.byKey(const Key('item_sheet_name')))
      .controller!
      .text;

  CategoryPillState pillOf(WidgetTester tester, ItemCategory category) => tester
      .widget<CategoryPill>(
        find.byWidgetPredicate(
          (w) => w is CategoryPill && w.category == category,
        ),
      )
      .pillState;

  /// Apre la scheda di creazione sopra la casa e ne raccoglie il risultato.
  Future<({ScreenshotApp app, Future<ItemModel?> result})> openNew(
    WidgetTester tester, {
    String initialName = '',
  }) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await app.go('/');
    await app.push('/houses/$kHomeId');
    final context = tester.element(find.byType(Scaffold).last);
    final result = showNewItemSheet(
      context,
      houseId: kHomeId,
      initialName: initialName,
      submitLabel: 'Aggiungi',
    );
    await app.settle();
    return (app: app, result: result);
  }

  testWidgets('mostra nome, categoria, quantità e spazio', (tester) async {
    final app = await openCalzini(tester);
    expect(find.text('Modifica oggetto'), findsOneWidget);
    expect(nameText(tester), 'Calzini');
    expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.forced);
    for (final other in ItemCategory.values.skip(1)) {
      expect(pillOf(tester, other), CategoryPillState.inactive);
    }
    expect(find.text('7'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('item_sheet_space')),
        matching: find.text('Cassettiera'),
      ),
      findsOneWidget,
    );
    await app.finish();
  });

  testWidgets(
    'crea il primo spazio dalla scheda e lo seleziona senza salvare prima l’oggetto',
    (tester) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await app.push('/houses/$kSeaHouseId');
      await app.tap(find.text('Infradito'));
      await app.tap(find.byKey(const Key('item_sheet_space')));
      await app.tap(find.byKey(const Key('picker_create_space')));
      await app.enterText(
        find.byKey(const Key('space_sheet_name')),
        'Armadio mare',
      );
      await app.tap(find.byKey(const Key('space_sheet_save')));
      expect(
        find.descendant(
          of: find.byKey(const Key('item_sheet_space')),
          matching: find.text('Armadio mare'),
        ),
        findsOneWidget,
      );
      await app.tap(find.byKey(const Key('item_sheet_save')));
      await app.tap(find.text('Infradito'));
      expect(
        find.descendant(
          of: find.byKey(const Key('item_sheet_space')),
          matching: find.text('Armadio mare'),
        ),
        findsOneWidget,
      );
      await app.finish();
    },
  );

  testWidgets('la x sta all estrema destra, con il menu alla sua sinistra', (
    tester,
  ) async {
    final app = await openCalzini(tester);

    expect(
      tester.getCenter(find.byKey(const Key('item_sheet_menu'))).dx,
      lessThan(tester.getCenter(find.byKey(const Key('sheet_close'))).dx),
    );
    await app.finish();
  });

  testWidgets('in modifica "Salva" si accende solo con una modifica', (
    tester,
  ) async {
    final app = await openCalzini(tester);
    VoidCallback? onSave() => tester
        .widget<DsButton>(find.byKey(const Key('item_sheet_save')))
        .onPressed;

    expect(onSave(), isNull);
    await app.tap(find.text('Varie'));
    expect(onSave(), isNotNull);
    // Tornando com'era si spegne di nuovo.
    await app.tap(find.text('Vestiti'));
    expect(onSave(), isNull);
    await app.enterText(find.byKey(const Key('item_sheet_note')), 'Di lana');
    expect(onSave(), isNotNull);
    await app.finish();
  });

  testWidgets('toccare un\'altra categoria la sceglie', (tester) async {
    final app = await openCalzini(tester);
    await app.tap(find.text('Varie'));
    expect(pillOf(tester, ItemCategory.varie), CategoryPillState.forced);
    expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.inactive);

    // Nella modifica una categoria c'è sempre: ritoccarla non la toglie.
    await app.tap(find.text('Varie'));
    expect(pillOf(tester, ItemCategory.varie), CategoryPillState.forced);
    await app.finish();
  });

  testWidgets('Dettagli: il campo nota è sempre visibile e si salva', (
    tester,
  ) async {
    final app = await openCalzini(tester);
    final context = tester.element(find.byKey(const Key('item_sheet_note')));
    final noteBottom = tester
        .getRect(find.byKey(const Key('item_sheet_note')))
        .bottom;
    final saveTop = tester
        .getRect(find.byKey(const Key('item_sheet_save')))
        .top;
    expect(saveTop - noteBottom, greaterThanOrEqualTo(context.spacingLg - 0.1));

    await app.enterText(
      find.byKey(const Key('item_sheet_note')),
      'Quelli di lana',
    );
    await app.tap(find.byKey(const Key('item_sheet_save')));
    await app.tap(find.text('Calzini'));
    final note = tester.widget<TextFormField>(
      find.byKey(const Key('item_sheet_note')),
    );
    expect(note.controller!.text, 'Quelli di lana');
    await app.finish();
  });

  testWidgets('+ e Salva aggiornano la quantità nella lista', (tester) async {
    final app = await openCalzini(tester);
    await app.tap(find.byIcon(Icons.add_circle_outline));
    await app.tap(find.byKey(const Key('item_sheet_save')));
    expect(find.byKey(const Key('item_sheet_name')), findsNothing);
    expect(find.text('x8'), findsOneWidget);
    await app.finish();
  });

  testWidgets('senza nome non salva', (tester) async {
    final app = await openCalzini(tester);
    await app.enterText(find.byKey(const Key('item_sheet_name')), '  ');
    await app.tap(find.byKey(const Key('item_sheet_save')));
    expect(find.byKey(const Key('item_sheet_name')), findsOneWidget);
    expect(find.text('common.name_required_validation'.tr()), findsOneWidget);
    await app.finish();
  });

  testWidgets('Elimina dal menu, con conferma, toglie l oggetto', (
    tester,
  ) async {
    final app = await openCalzini(tester);
    await app.tap(find.byKey(const Key('item_sheet_menu')));
    await app.tap(find.text('Elimina').last);
    // Conferma nel dialog.
    await app.tap(find.text('Elimina').last);
    expect(find.byKey(const Key('item_sheet_name')), findsNothing);
    expect(find.text('Calzini'), findsNothing);
    await app.finish();
  });

  testWidgets('il − e il + della quantità sono neutri', (tester) async {
    final app = await openCalzini(tester);
    final plus = tester.widget<Icon>(find.byIcon(Icons.add_circle_outline));
    expect(plus.color, isNot(AppTheme.light.colorScheme.primary));
    await app.finish();
  });

  testWidgets(
    'oggetto non trovato: spiega il problema e si chiude su richiesta',
    (tester) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await app.go('/');
      await app.push('/houses/$kHomeId');
      final context = tester.element(find.byType(Scaffold).last);
      unawaited(showItemSheet(context, houseId: kHomeId, itemId: 'non-esiste'));
      await app.settle();
      expect(find.byType(ItemSheet), findsOneWidget);
      expect(find.text('Oggetto non trovato'), findsOneWidget);
      await app.tap(find.text('Chiudi'));
      expect(find.byType(ItemSheet), findsNothing);
      await app.finish();
    },
  );

  group('nuovo oggetto', () {
    testWidgets('parte dal nome scritto, senza menu', (tester) async {
      final (:app, result: _) = await openNew(tester, initialName: 'Ciab');
      expect(find.text('Nuovo oggetto'), findsOneWidget);
      expect(nameText(tester), 'Ciab');
      expect(find.byKey(const Key('item_sheet_menu')), findsNothing);
      expect(find.text('Aggiungi'), findsOneWidget);
      await app.finish();
    });

    testWidgets('propone la categoria dal nome e crea con quella', (
      tester,
    ) async {
      final (:app, :result) = await openNew(tester, initialName: 'Maglietta');
      expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.inferred);

      await app.tap(find.byKey(const Key('item_sheet_save')));
      final created = await result;
      expect(created, isNotNull);
      expect(created!.name, 'Maglietta');
      expect(created.category, ItemCategory.vestiti);
      expect(created.houseId, kHomeId);
      expect(find.text('Maglietta'), findsOneWidget);
      await app.finish();
    });

    testWidgets('la categoria toccata vince sulla proposta, ritoccata torna', (
      tester,
    ) async {
      final (:app, result: _) = await openNew(tester, initialName: 'Maglietta');
      await app.tap(find.text('Elettronica'));
      expect(
        pillOf(tester, ItemCategory.elettronica),
        CategoryPillState.forced,
      );
      expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.inactive);

      await app.tap(find.text('Elettronica'));
      expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.inferred);
      await app.finish();
    });

    testWidgets('senza nome nessuna categoria proposta', (tester) async {
      final (:app, result: _) = await openNew(tester);
      for (final category in ItemCategory.values) {
        expect(pillOf(tester, category), CategoryPillState.inactive);
      }
      await app.finish();
    });

    testWidgets('senza nome non crea', (tester) async {
      final (:app, result: _) = await openNew(tester);
      await app.tap(find.byKey(const Key('item_sheet_save')));
      expect(find.byKey(const Key('item_sheet_name')), findsOneWidget);
      expect(find.text('common.name_required_validation'.tr()), findsOneWidget);
      await app.finish();
    });
  });

  group('dettagli a tag', () {
    Future<void> openMaglione(WidgetTester tester, ScreenshotApp app) async {
      await app.go('/');
      await app.push('/houses/$kHomeId');
      await app.tap(find.text('Maglione di lana'));
    }

    /// Il foglio con i dettagli è più alto della superficie di prova: il
    /// bottone "Salva" va portato in vista prima di toccarlo.
    Future<void> tapSave(WidgetTester tester, ScreenshotApp app) async {
      await tester.ensureVisible(find.byKey(const Key('item_sheet_save')));
      await app.tap(find.byKey(const Key('item_sheet_save')));
    }

    VoidCallback? onSave(WidgetTester tester) => tester
        .widget<DsButton>(find.byKey(const Key('item_sheet_save')))
        .onPressed;

    /// Il JSON dei metadati di "Maglione di lana" come è salvato nel DB. Si
    /// cerca fra tutti gli oggetti: il seed sposta il maglione nella baita.
    Future<Map<String, dynamic>> storedMetadata(
      WidgetTester tester,
      ScreenshotApp app,
    ) async {
      // Il salvataggio scrive sul DB in tempo reale: si aspetta che finisca.
      final all = (await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return app.container.read(itemRepositoryProvider).getAllItems();
      }))!;
      final item = all.firstWhere((i) => i.name == 'Maglione di lana');
      return jsonDecode(item.aiMetadata!) as Map<String, dynamic>;
    }

    testWidgets('un capo mostra Dettagli dopo Spazio, con i suoi tag', (
      tester,
    ) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await openMaglione(tester, app);

      expect(find.text('Nota'), findsOneWidget);
      expect(find.byKey(const Key('clothing_type_row')), findsOneWidget);
      expect(find.text(clothingTypeLabel('Sweater')), findsOneWidget);
      expect(find.text(warmthLabel(4)), findsOneWidget);
      final spaceY = tester.getTopLeft(find.text('Spazio')).dy;
      final detailsY = tester
          .getTopLeft(find.byKey(const Key('clothing_type_row')))
          .dy;
      final noteY = tester.getTopLeft(find.text('Nota')).dy;
      expect(detailsY, greaterThan(spaceY));
      expect(noteY, greaterThan(detailsY));
      await app.finish();
    });

    testWidgets('un oggetto senza metadati di capo non ha la sezione', (
      tester,
    ) async {
      final app = await openCalzini(tester);
      expect(find.byKey(const Key('clothing_type_row')), findsNothing);
      expect(find.text('Nota'), findsOneWidget);
      await app.finish();
    });

    testWidgets('un nuovo oggetto non ha la sezione', (tester) async {
      final (:app, result: _) = await openNew(tester, initialName: 'Ciab');
      expect(find.byKey(const Key('clothing_type_row')), findsNothing);
      await app.finish();
    });

    testWidgets('Salva si accende solo con un tag cambiato', (tester) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await openMaglione(tester, app);
      expect(onSave(tester), isNull);

      await app.tap(find.text(warmthLabel(3)));
      expect(onSave(tester), isNotNull);
      await app.finish();
    });

    testWidgets('Calore cambiato si salva e le altre chiavi restano', (
      tester,
    ) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await openMaglione(tester, app);

      await app.tap(find.text(warmthLabel(2)));
      await tapSave(tester, app);

      final meta = await storedMetadata(tester, app);
      expect(meta['warmth'], 2);
      expect(meta['subCategory'], 'Sweater');
      expect(meta['baseColor'], 'Blu');
      expect(meta['pattern'], 'Solid');
      expect(meta['coverage'], 'Long');
      expect(meta['activityTags'], ['Everyday']);
      expect(meta['waterResistance'], 0);
      await app.finish();
    });

    testWidgets('negli usi l\'ultimo tag non si toglie', (tester) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await openMaglione(tester, app);

      await app.tap(find.text(activityLabel('Everyday')));
      expect(onSave(tester), isNull);
      await app.finish();
    });

    testWidgets('"+ Altro colore" aggiunge il colore e lo salva', (
      tester,
    ) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await openMaglione(tester, app);

      await app.tap(find.text('+ Altro colore'));
      await app.enterText(
        find.byKey(const Key('clothing_color_field')),
        'Rosa chiaro',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await app.settle();
      expect(find.text('Rosa chiaro'), findsOneWidget);

      await tapSave(tester, app);
      final meta = await storedMetadata(tester, app);
      expect(meta['baseColor'], 'Rosa chiaro');
      await app.finish();
    });

    testWidgets('il picker del tipo è raggruppato per categoria', (
      tester,
    ) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await openMaglione(tester, app);

      await app.tap(find.byKey(const Key('clothing_type_row')));
      expect(find.text('Scegli il tipo'), findsOneWidget);
      expect(find.byType(DsGroupHeader), findsWidgets);
      await app.finish();
    });
  });
}
