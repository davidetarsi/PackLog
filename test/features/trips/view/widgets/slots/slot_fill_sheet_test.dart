import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/widgets/rapid_fire_input.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_fill_sheet.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

import '../../../../../helpers/memory_asset_loader.dart';

/// Registra gli oggetti creati dal Rapid Fire, senza toccare il database.
/// Se [gate] c'è, il salvataggio resta in attesa finché non si completa.
Completer<void>? gate;
Completer<void>? fillGate;

/// Se vero, `onFill` del foglio fallisce.
bool fillFails = false;

class _RecordingItemNotifier extends ItemNotifier {
  _RecordingItemNotifier(this.items);
  final List<ItemModel> items;

  @override
  Future<List<ItemModel>> build(String houseId) async => items;

  @override
  Future<void> addItem(ItemModel model, {bool categoryChosen = false}) async {
    await gate?.future;
  }
}

class _RecordingTripNotifier extends TripNotifier {
  _RecordingTripNotifier(this.items);
  final List<TripItem> items;

  @override
  Future<List<TripModel>> build() async => [
    TripModel(
      id: 't1',
      name: 'Trip',
      items: items,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
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
    fillGate = null;
    fillFails = false;
  });

  Future<void> pumpSheet(
    WidgetTester tester,
    AiSlot slot, {
    List<TripItem> tripItems = const [],
    int inventoryQuantity = 3,
  }) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripNotifierProvider.overrideWith(
            () => _RecordingTripNotifier(tripItems),
          ),
          itemNotifierProvider('h1').overrideWith(
            () => _RecordingItemNotifier([
              ItemModel(
                id: 'inventory-tee',
                houseId: 'h1',
                name: 'T-shirt bianca',
                category: ItemCategory.vestiti,
                quantity: inventoryQuantity,
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ]),
          ),
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
                        tripId: 't1',
                        onFill: (item) async {
                          await fillGate?.future;
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
    expect(
      find.text(
        'La quantità che aggiungi viene scalata da quella richiesta. Puoi segnare da comprare ciò che manca.',
      ),
      findsOneWidget,
    );
    expect(find.text('Da comprare'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cerca nel tuo inventario'), findsOneWidget);
    expect(find.text('T-shirt bianca'), findsNothing);
  });

  testWidgets('aprendo la ricerca preseleziona il nome scritto e trova item', (
    tester,
  ) async {
    await pumpSheet(tester, _slot());
    await tester.enterText(find.byType(TextField).first, '2 T-shirt bianca');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cerca nel tuo inventario'));
    await tester.pumpAndSettle();

    expect(find.text('T-shirt bianca'), findsWidgets);
    expect(find.text('Oggetti trovati'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    expect(find.text('Aggiungi'), findsOneWidget);
    expect(
      find.text('Assicurati che l’oggetto sia adatto al viaggio.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('slot_inventory_search')),
      'Sneakers',
    );
    await tester.pumpAndSettle();
    expect(find.text('Oggetti trovati'), findsNothing);
  });

  testWidgets('la ricerca secondaria riconosce copie in coda', (tester) async {
    await pumpSheet(tester, _slot());
    await tester.enterText(find.byType(TextField).first, 'T-shirt bianca, 2');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cerca nel tuo inventario'));
    await tester.pumpAndSettle();

    expect(find.text('T-shirt bianca'), findsWidgets);
    expect(find.text('×3'), findsOneWidget);
  });

  testWidgets(
    'completamento resta esplicito con un draft Rapid Fire non inviato',
    (tester) async {
      await pumpSheet(tester, _slot(copies: 1));
      await tester.enterText(find.byType(TextField).first, 'T-shirt bianca');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerca nel tuo inventario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();

      expect(
        find.text('Hai aggiunto tutte le copie richieste.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('slot_sheet_done')), findsOneWidget);
      expect(find.byType(RapidFireInput), findsNothing);
      expect(filled.single.id, 'inventory-tee');
    },
  );

  testWidgets('avvisa sul nome duplicato ma il Rapid Fire crea un nuovo ID', (
    tester,
  ) async {
    await pumpSheet(tester, _slot());
    await tester.enterText(find.byType(TextField).first, '2 T-shirt bianca');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Attenzione, nell’inventario c’è già un oggetto con questo nome.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(filled.single.name, 'T-shirt bianca');
    expect(filled.single.quantity, 2);
    expect(filled.single.id, isNot('inventory-tee'));
  });

  testWidgets(
    'collega lo stesso ID, preserva categoria e non riusa copie già nel viaggio',
    (tester) async {
      await pumpSheet(
        tester,
        _slot(copies: 3),
        tripItems: [
          TripItem(
            id: 'inventory-tee',
            name: 'T-shirt bianca',
            category: ItemCategory.vestiti,
            quantity: 2,
            originHouseId: 'h1',
          ),
        ],
      );
      await tester.enterText(find.byType(TextField).first, 'T-shirt bianca');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('slot_open_inventory_search')));
      await tester.pumpAndSettle();

      expect(find.text('×1'), findsOneWidget);
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();

      expect(filled.single.id, 'inventory-tee');
      expect(filled.single.category, ItemCategory.vestiti);
      expect(filled.single.originHouseId, 'h1');
      expect(filled.single.quantity, 1);
      expect(find.byKey(const ValueKey('inventory-tee')), findsOneWidget);
      expect(find.text('×1'), findsOneWidget);
    },
  );

  testWidgets(
    'nome già tutto allocato avvisa il duplicato ma non offre risultati',
    (tester) async {
      await pumpSheet(
        tester,
        _slot(),
        tripItems: [
          TripItem(
            id: 'inventory-tee',
            name: 'T-shirt bianca',
            category: ItemCategory.vestiti,
            quantity: 3,
            originHouseId: 'h1',
          ),
        ],
      );
      await tester.enterText(find.byType(TextField).first, 'T-shirt bianca');
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Attenzione, nell’inventario c’è già un oggetto con questo nome.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('slot_open_inventory_search')));
      await tester.pumpAndSettle();
      expect(
        find.text('Nessun oggetto con questo nome nell’inventario.'),
        findsOneWidget,
      );
      expect(find.text('Aggiungi'), findsNothing);
    },
  );

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

  testWidgets('residuo 3 e due copie aggiunte lasciano residuo 1', (
    tester,
  ) async {
    await pumpSheet(tester, _slot(copies: 3));

    await send(tester, '2 Sneakers bianche');
    await tester.pumpAndSettle();

    expect(find.text('Sneakers ×1'), findsOneWidget);
    expect(filled.single.quantity, 2);
    expect(sheet, findsOneWidget);
  });

  testWidgets('a copie finite mostra conferma e CTA chiudi senza timer', (
    tester,
  ) async {
    await pumpSheet(tester, _slot(copies: 1));

    await send(tester, 'Sneakers bianche');
    await tester.pumpAndSettle();

    expect(find.text('Sneakers bianche'), findsOneWidget);
    expect(find.text('Hai aggiunto tutte le copie richieste.'), findsOneWidget);
    expect(find.text('Chiudi'), findsOneWidget);
    expect(find.text('Cerca nel tuo inventario'), findsNothing);
    expect(find.text('Da comprare'), findsNothing);
    expect(sheet, findsOneWidget);
    await tester.tap(find.byKey(const Key('slot_sheet_done')));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(filled, hasLength(1));
  });

  testWidgets('un invio multiplo oltre le copie salva tutte le copie reali', (
    tester,
  ) async {
    await pumpSheet(tester, _slot(copies: 2));

    await send(tester, '3 sneakers nere');
    await tester.pumpAndSettle();

    expect(sheet, findsOneWidget);
    expect(find.text('Hai aggiunto tutte le copie richieste.'), findsOneWidget);
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

  testWidgets(
    'la creazione Rapid Fire pendente non si perde dietro a un fill',
    (tester) async {
      await pumpSheet(tester, _slot(copies: 1));
      gate = Completer<void>();
      fillGate = Completer<void>();

      await tester.enterText(find.byType(TextField).first, 'Nuovo oggetto');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.tap(find.text('Cerca nel tuo inventario'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(
        find.byKey(const Key('slot_inventory_search')),
        'T-shirt bianca',
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Aggiungi'));
      await tester.pump();

      fillGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RapidFireInput), findsNothing);
      expect(
        find.text('Hai aggiunto tutte le copie richieste.'),
        findsOneWidget,
      );

      gate!.complete();
      await tester.pumpAndSettle();

      expect(filled, hasLength(2));
      expect(filled.map((item) => item.id), contains('inventory-tee'));
      expect(filled.any((item) => item.id != 'inventory-tee'), isTrue);
      expect(find.text('Aggiunte alla valigia'), findsOneWidget);
      expect(find.byKey(ValueKey(filled[0].id)), findsOneWidget);
      expect(find.byKey(ValueKey(filled[1].id)), findsOneWidget);
      expect(
        find.text('Hai aggiunto tutte le copie richieste.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

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
