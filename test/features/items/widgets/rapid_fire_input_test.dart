import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/widgets/category_pill.dart';
import 'package:pack_log/features/items/widgets/rapid_fire_input.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

void main() {
  testWidgets(
    'input espanso: la riga delle categorie non sfora su spazio stretto',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  // 412 - 2×120 = 172 dp utili. Nell'app reale l'overflow
                  // compariva a 412 dp con i font veri (15 px, vedi manifest degli
                  // screenshot); col font di test serve meno spazio per vederlo.
                  // Sul codice prima del fix questa larghezza sforava di 116 px.
                  padding: EdgeInsets.symmetric(horizontal: 120),
                  child: RapidFireInput(houseId: 'h1'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(
        find.byType(CategoryPill),
        findsNWidgets(ItemCategory.values.length),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('autofocus: si apre già espanso con la tastiera', (tester) async {
    var expanded = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RapidFireInput(
                houseId: 'h1',
                autofocus: true,
                onExpandedChanged: (v) => expanded = v,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode?.hasFocus, isTrue);
    expect(expanded, isTrue);
    expect(
      find.byType(CategoryPill),
      findsNWidgets(ItemCategory.values.length),
    );
  });

  Future<void> pumpInput(
    WidgetTester tester, {
    ValueChanged<String>? onTextChanged,
    ValueChanged<bool>? onExpandedChanged,
    FocusNode? focusNode,
    bool enabled = true,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RapidFireInput(
                  houseId: 'h1',
                  onTextChanged: onTextChanged,
                  onExpandedChanged: onExpandedChanged,
                  focusNode: focusNode,
                  enabled: enabled,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('enabled false: il campo non si scrive', (tester) async {
    String? last;
    await pumpInput(tester, enabled: false, onTextChanged: (v) => last = v);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Felpa');
    await tester.pump();
    expect(last, isNull);
    expect(find.text('Felpa'), findsNothing);
  });

  testWidgets('pillole col nome intero, tutte larghe uguali', (tester) async {
    await pumpInput(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('categories.vestiti'), findsOneWidget);
    expect(find.text('categories.varie'), findsOneWidget);
    final pills = find.byType(CategoryPill);
    final first = tester.getSize(pills.at(0)).width;
    for (var i = 1; i < ItemCategory.values.length; i++) {
      expect(tester.getSize(pills.at(i)).width, first);
    }
  });

  testWidgets('niente "+" per il form completo', (tester) async {
    await pumpInput(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('il testo scritto arriva a onTextChanged', (tester) async {
    String? last;
    await pumpInput(tester, onTextChanged: (v) => last = v);
    await tester.enterText(find.byType(TextField), 'Calz');
    expect(last, 'Calz');
  });

  testWidgets('usa il FocusNode passato da fuori', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var expanded = false;
    await pumpInput(
      tester,
      focusNode: node,
      onExpandedChanged: (v) => expanded = v,
    );
    node.requestFocus();
    await tester.pumpAndSettle();
    expect(expanded, isTrue);
  });

  testWidgets('invio da tastiera: il campo resta a fuoco per il prossimo', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await pumpInput(tester, focusNode: node);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Felpa verde');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    // Il salvataggio tocca il database: qui conta solo il focus, qualunque
    // sia l'esito del salvataggio.
    await tester.pump(const Duration(milliseconds: 100));
    expect(node.hasFocus, isTrue);
  });

  testWidgets('"aux bt" diventa "Aux bt" mentre si scrive', (tester) async {
    String? last;
    await pumpInput(tester, onTextChanged: (v) => last = v);
    await tester.enterText(find.byType(TextField), 'aux bt');
    expect(last, 'Aux bt');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Aux bt',
    );
  });

  group('copie', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpWithFake(
      WidgetTester tester,
      _RecordingItemNotifier fake, {
      ValueChanged<ItemModel>? onItemCreated,
      String? hintText,
    }) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [itemNotifierProvider('h1').overrideWith(() => fake)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RapidFireInput(
                    houseId: 'h1',
                    onItemCreated: onItemCreated,
                    hintText: hintText,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();
    }

    testWidgets('"2 t-shirt nere" mostra ×2 e crea "T-shirt nere" x2', (
      tester,
    ) async {
      final fake = _RecordingItemNotifier();
      await pumpWithFake(tester, fake);
      await tester.enterText(find.byType(TextField), '2 t-shirt nere');
      await tester.pump();
      expect(find.text('×2'), findsOneWidget);

      await submit(tester);
      expect(fake.added, hasLength(1));
      expect(fake.added.single.name, 'T-shirt nere');
      expect(fake.added.single.quantity, 2);
    });

    testWidgets('virgola in fondo: il nome tiene la maiuscola del formatter', (
      tester,
    ) async {
      final fake = _RecordingItemNotifier();
      await pumpWithFake(tester, fake);
      await tester.enterText(find.byType(TextField), 't-shirt nera, 3');
      await tester.pump();
      expect(find.text('×3'), findsOneWidget);

      await submit(tester);
      expect(fake.added.single.name, 'T-shirt nera');
      expect(fake.added.single.quantity, 3);
    });

    testWidgets('toccare ×2 su "2 in 1 caricatore" crea il nome intero x1', (
      tester,
    ) async {
      final fake = _RecordingItemNotifier();
      await pumpWithFake(tester, fake);
      await tester.enterText(find.byType(TextField), '2 in 1 caricatore');
      await tester.pump();
      await tester.tap(find.text('×2'));
      await tester.pump();
      expect(find.text('×2'), findsNothing);

      await submit(tester);
      expect(fake.added.single.name, '2 in 1 caricatore');
      expect(fake.added.single.quantity, 1);
    });

    testWidgets('la pillola tolta torna quando il campo si svuota', (
      tester,
    ) async {
      final fake = _RecordingItemNotifier();
      await pumpWithFake(tester, fake);
      await tester.enterText(find.byType(TextField), '2 calzini');
      await tester.pump();
      await tester.tap(find.text('×2'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '3 calzini');
      await tester.pump();
      expect(find.text('×3'), findsOneWidget);
    });

    testWidgets('senza numero il testo intero va con quantità 1', (
      tester,
    ) async {
      final fake = _RecordingItemNotifier();
      await pumpWithFake(tester, fake);
      await tester.enterText(find.byType(TextField), 'Cavo, 100');
      await tester.pump();
      expect(find.textContaining('×'), findsNothing);

      await submit(tester);
      expect(fake.added.single.name, 'Cavo, 100');
      expect(fake.added.single.quantity, 1);
    });

    testWidgets('la riga del suggerimento compare una volta sola', (
      tester,
    ) async {
      final fake = _RecordingItemNotifier();
      await pumpWithFake(tester, fake);
      expect(find.text('items.copies_tip'), findsNothing);

      await tester.enterText(find.byType(TextField), '2 t-shirt nere');
      await tester.pumpAndSettle();
      expect(find.text('items.copies_tip'), findsOneWidget);

      await submit(tester);
      expect(find.text('items.copies_tip'), findsNothing);

      await tester.enterText(find.byType(TextField), '3 calzini');
      await tester.pumpAndSettle();
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('items.copies_tip'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('rapid_fire_copies_tip_seen'), isTrue);
    });

    testWidgets('il suggerimento già visto in passato non compare', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'rapid_fire_copies_tip_seen': true,
      });
      final fake = _RecordingItemNotifier();
      await pumpWithFake(tester, fake);
      await tester.enterText(find.byType(TextField), '2 t-shirt nere');
      await tester.pumpAndSettle();
      expect(find.text('×2'), findsOneWidget);
      expect(find.text('items.copies_tip'), findsNothing);
    });

    testWidgets('onItemCreated riceve l\'oggetto creato', (tester) async {
      final fake = _RecordingItemNotifier();
      final created = <ItemModel>[];
      await pumpWithFake(tester, fake, onItemCreated: created.add);
      await tester.enterText(find.byType(TextField), '2 t-shirt nere');
      await tester.pump();
      await submit(tester);
      expect(created, hasLength(1));
      expect(created.single.name, 'T-shirt nere');
      expect(created.single.quantity, 2);
    });

    testWidgets('onItemCreated non parte se il salvataggio fallisce', (
      tester,
    ) async {
      final fake = _RecordingItemNotifier(fail: true);
      final created = <ItemModel>[];
      await pumpWithFake(tester, fake, onItemCreated: created.add);
      await tester.enterText(find.byType(TextField), 'Felpa');
      await tester.pump();
      await submit(tester);
      expect(created, isEmpty);
    });

    testWidgets('hintText sostituisce il segnaposto di default', (
      tester,
    ) async {
      final fake = _RecordingItemNotifier();
      await pumpWithFake(tester, fake, hintText: 'Aggiungi al viaggio');
      expect(find.text('Aggiungi al viaggio'), findsOneWidget);
      expect(find.text('items.rapid_fire_hint'), findsNothing);
    });
  });
}

class _RecordingItemNotifier extends ItemNotifier {
  _RecordingItemNotifier({this.fail = false});

  final bool fail;
  final added = <ItemModel>[];

  @override
  Future<List<ItemModel>> build(String houseId) async => const [];

  @override
  Future<void> addItem(ItemModel model, {bool categoryChosen = false}) async {
    if (fail) throw StateError('boom');
    added.add(model);
  }
}
