import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_fill_sheet.dart';
import 'package:pack_log/shared/theme/app_motion.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

import '../../../../../helpers/memory_asset_loader.dart';

/// Registra gli oggetti creati dal Rapid Fire, senza toccare il database.
/// Se [gate] c'è, il salvataggio resta in attesa finché non si completa.
Completer<void>? gate;

/// Se vero, `onFill` del foglio fallisce.
bool fillFails = false;

class _RecordingItemNotifier extends ItemNotifier {
  @override
  Future<List<ItemModel>> build(String houseId) async => const [];

  @override
  Future<void> addItem(ItemModel model, {bool categoryChosen = false}) async {
    await gate?.future;
  }
}

AiSlot _slot({
  int copies = 3,
  AiSlotLevel level = AiSlotLevel.useful,
  bool toBuy = false,
}) => AiSlot(
  id: 'u-sneakers',
  type: 'sneakers',
  category: ItemCategory.vestiti,
  level: level,
  name: 'Sneakers',
  copies: copies,
  remaining: copies,
  addLabel: 'Aggiungi le tue',
  toBuy: toBuy,
);

void main() {
  final filled = <TripItem>[];
  var toBuyCalls = 0;
  var disableAnimations = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    filled.clear();
    toBuyCalls = 0;
    disableAnimations = false;
    gate = null;
    fillFails = false;
  });

  Future<void> pumpSheet(WidgetTester tester, AiSlot slot) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemNotifierProvider('h1').overrideWith(_RecordingItemNotifier.new),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
          path: 'assets/translations',
          assetLoader: MemoryAssetLoader(readAppTranslations()),
          fallbackLocale: const Locale('en', 'US'),
          startLocale: const Locale('it', 'IT'),
          saveLocale: false,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.dark,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: disableAnimations),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => unawaited(
                      showSlotFillSheet(
                        context,
                        slot: slot,
                        houseId: 'h1',
                        onFill: (item) async {
                          if (fillFails) throw StateError('boom');
                          filled.add(item);
                        },
                        onToBuy: () => toBuyCalls++,
                      ),
                    ),
                    child: const Text('apri'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
  }

  final sheet = find.byType(SlotFillSheet);

  testWidgets('si apre con nome, copie e la frase', (tester) async {
    await pumpSheet(tester, _slot());

    expect(sheet, findsOneWidget);
    expect(find.text('Sneakers ×3'), findsOneWidget);
    expect(find.textContaining('PackLog ne propone 3'), findsOneWidget);
    expect(find.text('Da comprare'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('un invio mostra l\'oggetto e fa scendere ×3 a ×2', (
    tester,
  ) async {
    await pumpSheet(tester, _slot());

    await send(tester, 'Sneakers bianche');
    await tester.pumpAndSettle();

    expect(find.text('Sneakers bianche'), findsOneWidget);
    expect(find.text('Sneakers ×2'), findsOneWidget);
    expect(filled.single.name, 'Sneakers bianche');
    expect(sheet, findsOneWidget);
  });

  testWidgets('a copie finite disabilita il campo e chiude dopo l\'attesa', (
    tester,
  ) async {
    await pumpSheet(tester, _slot(copies: 1));

    await send(tester, 'Sneakers bianche');
    await tester.pump(AppMotion.slow ~/ 2);

    // L'oggetto è già nella lista e il campo è fermo.
    expect(find.text('Sneakers bianche'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(sheet, findsOneWidget);

    // Finita l'entrata della riga l'attesa non è ancora scaduta.
    await tester.pump(AppMotion.slow ~/ 2 + AppMotion.slotSheetCloseDelay ~/ 2);
    expect(sheet, findsOneWidget);

    await tester.pump(AppMotion.slotSheetCloseDelay);
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets('con le animazioni spente chiude subito', (tester) async {
    disableAnimations = true;
    await pumpSheet(tester, _slot(copies: 1));

    await send(tester, 'Sneakers bianche');
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(filled, hasLength(1));
  });

  testWidgets('un invio multiplo oltre le copie chiude e salva tutto', (
    tester,
  ) async {
    await pumpSheet(tester, _slot(copies: 2));

    await send(tester, '3 sneakers nere');
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(filled.single.quantity, 3);
  });

  testWidgets('chiuso a mano, gli oggetti già scritti restano salvati', (
    tester,
  ) async {
    await pumpSheet(tester, _slot());
    await send(tester, 'Sneakers bianche');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sheet_close')));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(filled, hasLength(1));
    expect(toBuyCalls, 0);
  });

  testWidgets('chiuso mentre l\'invio è in corso, l\'oggetto si salva', (
    tester,
  ) async {
    await pumpSheet(tester, _slot());
    gate = Completer<void>();

    await send(tester, 'Sneakers bianche');
    await tester.tap(find.byKey(const Key('sheet_close')));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(filled, isEmpty);

    gate!.complete();
    await tester.pumpAndSettle();

    expect(filled.single.name, 'Sneakers bianche');
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Da comprare" chiude il foglio e segna il posto', (
    tester,
  ) async {
    await pumpSheet(tester, _slot());

    await tester.tap(find.text('Da comprare'));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(toBuyCalls, 1);
  });

  testWidgets('un posto già da comprare non offre "Da comprare"', (
    tester,
  ) async {
    await pumpSheet(tester, _slot(toBuy: true));

    expect(find.text('Da comprare'), findsNothing);
  });

  testWidgets('chiuso a mano durante l\'attesa: nessun secondo pop e nessun '
      'timer pendente', (tester) async {
    await pumpSheet(tester, _slot(copies: 1));
    await send(tester, 'Sneakers bianche');
    await tester.pump(AppMotion.slow ~/ 2);

    await tester.tap(find.byKey(const Key('sheet_close')));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    // La pagina sotto resta: un secondo pop la toglierebbe.
    expect(find.text('apri'), findsOneWidget);

    await tester.pump(AppMotion.slow + AppMotion.slotSheetCloseDelay);
    expect(find.text('apri'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Il test finisce senza timer in sospeso.
  });

  testWidgets('onFill che fallisce: la riga non resta e il campo è attivo', (
    tester,
  ) async {
    fillFails = true;
    await pumpSheet(tester, _slot(copies: 1));

    await send(tester, 'Sneakers bianche');
    await tester.pumpAndSettle();

    expect(find.text('Sneakers bianche'), findsNothing);
    expect(find.text('Sneakers ×1'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(sheet, findsOneWidget);
  });
}
