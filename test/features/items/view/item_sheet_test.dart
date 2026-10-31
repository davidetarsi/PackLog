import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/clothing_labels.dart';
import 'package:pack_log/features/items/providers/item_enrichment_provider.dart';
import 'package:pack_log/features/items/providers/item_metadata_service_provider.dart';
import 'package:pack_log/features/items/services/item_metadata_service.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/view/item_sheet.dart';
import 'package:pack_log/features/items/widgets/category_pill.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_choice_pill.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

/// Il salvataggio dell'oggetto aspetta [gate]: serve a tenere la scheda
/// occupata mentre il test prova a chiuderla.
class _GatedItems extends ItemNotifier {
  _GatedItems(this.gate);
  final Completer<void> gate;

  @override
  Future<void> updateItem(ItemModel model) async {
    await gate.future;
    return super.updateItem(model);
  }
}

/// item-metadata finto: registra i nomi chiesti e risponde sempre [result].
class _RecordingMetadata extends ItemMetadataService {
  _RecordingMetadata(this.result) : super(url: '', anonKey: '');

  final ItemMetadataResult result;
  final names = <String>[];

  @override
  Future<ItemMetadataResult?> fromName(String name) async {
    names.add(name);
    return result;
  }
}

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
      .widget<TextFormField>(
        find.descendant(
          of: find.byKey(const Key('item_sheet_name')),
          matching: find.byType(TextFormField),
        ),
      )
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

  testWidgets('durante il salvataggio il foglio non si chiude', (tester) async {
    final gate = Completer<void>();
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: AppSetup(
        extraOverrides: [
          itemNotifierProvider(kHomeId).overrideWith(() => _GatedItems(gate)),
        ],
      ),
    );
    await app.go('/');
    await app.push('/houses/$kHomeId');
    await app.tap(find.text('Calzini'));
    await app.enterText(find.byKey(const Key('item_sheet_note')), 'Di lana');
    await app.tap(find.byKey(const Key('item_sheet_save')));

    // Salvataggio ancora in corso: né il tocco fuori né il tasto indietro
    // chiudono il foglio.
    await tester.tapAt(const Offset(10, 10));
    await app.settle();
    tester.binding.handlePopRoute();
    await app.settle();
    expect(find.byType(ItemSheet), findsOneWidget);

    gate.complete();
    await app.settle(frames: 30);
    expect(find.byType(ItemSheet), findsNothing);
    await app.finish();
  });

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
    // Con la sezione dei dettagli (anche vuota) il campo nota sta più in basso:
    // si porta in vista come farebbe chi scorre.
    await tester.ensureVisible(find.byKey(const Key('item_sheet_note')));
    final context = tester.element(find.byKey(const Key('item_sheet_note')));
    final noteBottom = tester
        .getRect(find.byKey(const Key('item_sheet_note')))
        .bottom;
    final saveTop = tester
        .getRect(find.byKey(const Key('item_sheet_save')))
        .top;
    expect(saveTop - noteBottom, greaterThanOrEqualTo(context.spacingMd - 0.1));

    await app.enterText(
      find.byKey(const Key('item_sheet_note')),
      'Quelli di lana',
    );
    await app.tap(find.byKey(const Key('item_sheet_save')));
    await app.tap(find.text('Calzini'));
    final note = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(const Key('item_sheet_note')),
        matching: find.byType(TextFormField),
      ),
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

    Future<void> tapSave(WidgetTester tester, ScreenshotApp app) =>
        app.tap(find.byKey(const Key('item_sheet_save')));

    /// I dettagli stanno nel contenuto che scorre: la scelta va portata in
    /// vista prima di toccarla, il foglio è più basso dello schermo di prova.
    Future<void> tapDetail(
      WidgetTester tester,
      ScreenshotApp app,
      Finder finder,
    ) async {
      await tester.ensureVisible(finder.first);
      await app.tap(finder);
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

    /// La pillola con quell'etichetta è selezionata?
    bool selectedPill(WidgetTester tester, String label) => tester
        .widget<DsChoicePill>(
          find.byWidgetPredicate((w) => w is DsChoicePill && w.label == label),
        )
        .selected;

    /// I metadati salvati di [name] come stringa, com'erano nel DB.
    Future<String?> storedRaw(
      WidgetTester tester,
      ScreenshotApp app,
      String name,
    ) async {
      final all = (await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return app.container.read(itemRepositoryProvider).getAllItems();
      }))!;
      return all.firstWhere((i) => i.name == name).aiMetadata;
    }

    Future<Map<String, dynamic>> storedOf(
      WidgetTester tester,
      ScreenshotApp app,
      String name,
    ) async {
      final raw = await storedRaw(tester, app, name);
      return jsonDecode(raw!) as Map<String, dynamic>;
    }

    /// L'oggetto [name] com'è nel provider adesso.
    ItemModel itemNamed(ScreenshotApp app, String name) => app.container
        .read(itemNotifierProvider(kHomeId))
        .value!
        .firstWhere((i) => i.name == name);

    /// I metadati di "Maglione di lana" con alcuni campi cambiati: la risposta
    /// dell'AI.
    Map<String, dynamic> aiAnswer(Map<String, dynamic> changes) => {
      ...(jsonDecode(kMaglioneAiMetadata) as Map<String, dynamic>),
      ...changes,
    };

    /// La risposta dell'AI arriva: scrive [ai] sull'oggetto [item], come fa
    /// `item-metadata` (senza `userFields`, quindi l'AI può scrivere tutto).
    Future<void> answerAi(
      ScreenshotApp app,
      ItemModel item, {
      required Map<String, dynamic> ai,
      ItemCategory? category,
    }) async {
      await app.container
          .read(itemNotifierProvider(kHomeId).notifier)
          .updateItem(
            item.copyWith(
              aiMetadata: jsonEncode(ai),
              category: category ?? item.category,
              updatedAt: DateTime.now(),
            ),
          );
      await app.settle();
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

    testWidgets(
      'un oggetto senza metadati ha la sezione vuota e modificabile',
      (tester) async {
        final app = await openCalzini(tester);
        expect(find.byKey(const Key('clothing_type_row')), findsOneWidget);
        expect(find.text('Scegli il tipo'), findsOneWidget);
        expect(selectedPill(tester, warmthLabel(4)), isFalse);
        expect(onSave(tester), isNull);

        await tapDetail(tester, app, find.text(warmthLabel(4)));
        expect(onSave(tester), isNotNull);
        await app.finish();
      },
    );

    testWidgets('un nuovo oggetto senza nome non ha la sezione', (
      tester,
    ) async {
      final (:app, result: _) = await openNew(tester);
      expect(find.byKey(const Key('clothing_type_row')), findsNothing);
      await app.finish();
    });

    testWidgets('un nuovo oggetto con categoria dedotta ha la sezione', (
      tester,
    ) async {
      final (:app, result: _) = await openNew(tester, initialName: 'Ciab');
      expect(find.byKey(const Key('clothing_type_row')), findsOneWidget);
      await app.finish();
    });

    testWidgets('Salva si accende solo con un tag cambiato', (tester) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await openMaglione(tester, app);
      expect(onSave(tester), isNull);

      await tapDetail(tester, app, find.text(warmthLabel(3)));
      expect(onSave(tester), isNotNull);
      await app.finish();
    });

    testWidgets('Calore cambiato si salva e le altre chiavi restano', (
      tester,
    ) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await openMaglione(tester, app);

      await tapDetail(tester, app, find.text(warmthLabel(2)));
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

      await tapDetail(tester, app, find.text('+ Altro colore'));
      await app.enterText(
        find.byKey(const Key('clothing_color_field')),
        'Verde salvia',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await app.settle();
      expect(find.text('Verde salvia'), findsOneWidget);

      await tapSave(tester, app);
      final meta = await storedMetadata(tester, app);
      expect(meta['baseColor'], 'Verde salvia');
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

    testWidgets('creando un capo senza toccare i dettagli non salva metadati', (
      tester,
    ) async {
      final (:app, :result) = await openNew(tester, initialName: 'Maglietta');
      expect(find.byKey(const Key('clothing_type_row')), findsOneWidget);
      expect(selectedPill(tester, warmthLabel(4)), isFalse);

      await tapSave(tester, app);
      final created = await result;
      expect(created!.aiMetadata, isNull);
      await app.finish();
    });

    testWidgets('creando un capo, un calore scelto è una scelta dell utente', (
      tester,
    ) async {
      final (:app, :result) = await openNew(tester, initialName: 'Maglietta');
      await tapDetail(tester, app, find.text(warmthLabel(4)));
      await tapSave(tester, app);

      final created = await result;
      final meta = jsonDecode(created!.aiMetadata!) as Map<String, dynamic>;
      expect(meta['warmth'], 4);
      expect(meta['userFields'], ['warmth']);
      expect(meta['aiPending'], isTrue);
      await app.finish();
    });

    testWidgets('creando un capo, Elettronica e Igiene nascondono i dettagli', (
      tester,
    ) async {
      final (:app, result: _) = await openNew(tester, initialName: 'Maglietta');
      await app.tap(find.text('Elettronica'));
      expect(find.byKey(const Key('clothing_type_row')), findsNothing);
      await app.tap(find.text('Igiene'));
      expect(find.byKey(const Key('clothing_type_row')), findsNothing);
      await app.finish();
    });

    testWidgets('un oggetto senza metadati, con un calore scelto, li riceve', (
      tester,
    ) async {
      final app = await openCalzini(tester);
      await tapDetail(tester, app, find.text(warmthLabel(4)));
      await tapSave(tester, app);

      final meta = await storedOf(tester, app, 'Calzini');
      expect(meta['warmth'], 4);
      expect(meta['userFields'], ['warmth']);
      expect(meta['aiPending'], isTrue);
      await app.finish();
    });

    testWidgets(
      'senza campi toccati i metadati salvati restano byte per byte',
      (tester) async {
        final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
        await openMaglione(tester, app);

        await app.enterText(
          find.byKey(const Key('item_sheet_note')),
          'Di lana',
        );
        await tapSave(tester, app);
        expect(
          await storedRaw(tester, app, 'Maglione di lana'),
          kMaglioneAiMetadata,
        );
        await app.finish();
      },
    );

    testWidgets('toccare la pillola già scelta rende la scheda modificata', (
      tester,
    ) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await openMaglione(tester, app);
      expect(onSave(tester), isNull);

      await tapDetail(tester, app, find.text(warmthLabel(4)));
      expect(onSave(tester), isNotNull);
      await tapSave(tester, app);

      final meta = await storedOf(tester, app, 'Maglione di lana');
      expect(meta['warmth'], 4);
      expect(meta['userFields'], ['warmth']);
      await app.finish();
    });

    testWidgets(
      'la risposta dell AI riempie i campi non toccati, quello toccato resta',
      (tester) async {
        final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
        await openMaglione(tester, app);
        await tapDetail(tester, app, find.text(warmthLabel(2)));

        await answerAi(
          app,
          itemNamed(app, 'Maglione di lana'),
          ai: aiAnswer({
            'subCategory': 'T-Shirt',
            'baseColor': 'Beige',
            'warmth': 5,
            'formality': 'Business',
          }),
        );

        expect(selectedPill(tester, warmthLabel(2)), isTrue);
        expect(selectedPill(tester, warmthLabel(5)), isFalse);
        expect(find.text(clothingTypeLabel('T-Shirt')), findsOneWidget);
        expect(selectedPill(tester, colorLabel('Beige')), isTrue);
        expect(selectedPill(tester, formalityLabel('Business')), isTrue);
        expect(onSave(tester), isNotNull);

        await tapSave(tester, app);
        final meta = await storedOf(tester, app, 'Maglione di lana');
        expect(meta['warmth'], 2);
        expect(meta['userFields'], ['warmth']);
        expect(meta['subCategory'], 'T-Shirt');
        expect(meta['baseColor'], 'Beige');
        await app.finish();
      },
    );

    testWidgets('la categoria segue l AI finché l utente non ne tocca una', (
      tester,
    ) async {
      final app = await openCalzini(tester);
      await answerAi(
        app,
        itemNamed(app, 'Calzini'),
        category: ItemCategory.varie,
        ai: const {'name': 'Calzini'},
      );

      expect(pillOf(tester, ItemCategory.varie), CategoryPillState.forced);
      expect(pillOf(tester, ItemCategory.vestiti), CategoryPillState.inactive);
      expect(onSave(tester), isNull);
      await app.finish();
    });

    testWidgets(
      'rinomina scritta a scheda aperta, salvata dopo la risposta per il nome '
      'vecchio: la scheda si chiede di nuovo e le scelte dell utente restano',
      (tester) async {
        final service = _RecordingMetadata(
          const ItemMetadataResult(
            metadata: {
              'category': 'Upper Body',
              'warmth': 5,
              'baseColor': 'blu',
            },
          ),
        );
        final app = await ScreenshotApp.start(
          tester,
          theme: ShotTheme.light,
          setup: AppSetup(
            extraOverrides: [
              itemMetadataServiceProvider.overrideWithValue(service),
            ],
          ),
        );
        await app.go('/');
        await app.push('/houses/$kHomeId');
        await app.tap(find.text('Calzini'));

        // Scrive il nome nuovo e sceglie il calore; poi arriva la risposta
        // per "Calzini" e solo dopo salva.
        await app.enterText(
          find.byKey(const Key('item_sheet_name')),
          'Calzini di lana',
        );
        await tapDetail(tester, app, find.text(warmthLabel(4)));
        await answerAi(
          app,
          itemNamed(app, 'Calzini'),
          ai: const {
            'category': 'Upper Body',
            'warmth': 2,
            'baseColor': 'rosso',
          },
        );
        await tapSave(tester, app);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await app.settle();

        expect(service.names, ['Calzini di lana']);
        final meta = await storedOf(tester, app, 'Calzini di lana');
        expect(meta['warmth'], 4);
        expect(meta['userFields'], ['warmth']);
        expect(meta['baseColor'], 'blu');
        expect(meta.containsKey('aiPending'), isFalse);
        await app.finish();
      },
    );

    testWidgets(
      'rinomina salvata con la risposta già arrivata: i valori restano finché '
      'non arriva quella del nome nuovo (aiPending)',
      (tester) async {
        final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
        await app.go('/');
        await app.push('/houses/$kHomeId');
        await app.tap(find.text('Calzini'));
        await app.enterText(
          find.byKey(const Key('item_sheet_name')),
          'Calzini di lana',
        );
        await answerAi(
          app,
          itemNamed(app, 'Calzini'),
          ai: const {'category': 'Upper Body', 'warmth': 2},
        );
        await tapSave(tester, app);

        final meta = await storedOf(tester, app, 'Calzini di lana');
        expect(meta['aiPending'], isTrue);
        expect(meta['warmth'], 2);
        await app.finish();
      },
    );

    testWidgets(
      'la riga "Sto completando" sta sopra i dettagli mentre l oggetto è in attesa',
      (tester) async {
        final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
        await openMaglione(tester, app);
        const pending = 'Sto completando i dettagli. Puoi già modificarli.';
        expect(find.text(pending), findsNothing);

        final id = itemNamed(app, 'Maglione di lana').id;
        app.container.read(itemEnrichmentProvider.notifier).start(id);
        await app.settle();
        expect(find.text(pending), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(pending)).dy,
          lessThan(
            tester.getTopLeft(find.byKey(const Key('clothing_type_row'))).dy,
          ),
        );

        app.container.read(itemEnrichmentProvider.notifier).finish(id);
        await app.settle();
        expect(find.text(pending), findsNothing);
        await app.finish();
      },
    );
  });
}
