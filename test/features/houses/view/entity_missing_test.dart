import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/features/houses/view/add_edit_house_screen.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/view/item_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

class _DelayedItems extends ItemNotifier {
  _DelayedItems(this.result);
  final Future<List<ItemModel>> result;
  @override
  Future<List<ItemModel>> build(String houseId) => result;
}

class _TransientHouses extends HouseNotifier {
  void loading() => state = const AsyncLoading();
  void restore(List<HouseModel> houses) => state = AsyncData(houses);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  testWidgets('modifica casa inesistente non offre di creare una nuova casa', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    final before = await app.container.read(houseNotifierProvider.future);
    showAddEditHouseSheet(
      tester.element(find.byType(Scaffold).last),
      houseId: 'missing',
    );
    await app.settle();
    expect(find.text('Casa non trovata'), findsWidgets);
    expect(find.byType(TextFormField), findsNothing);
    expect(
      (await app.container.read(houseNotifierProvider.future)).length,
      before.length,
    );
    await app.finish();
  });

  testWidgets('oggetto assente mostra un messaggio e il foglio resta aperto', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.dark);
    await tester.runAsync(
      () => app.container.read(itemNotifierProvider(kHomeId).future),
    );
    showItemSheet(
      tester.element(find.byType(Scaffold).last),
      houseId: kHomeId,
      itemId: 'missing',
    );
    await app.settle();
    expect(find.text('Oggetto non trovato'), findsOneWidget);
    expect(find.byType(ItemSheet), findsOneWidget);
    await app.finish();
  });

  testWidgets(
    'un oggetto ancora in caricamento non viene trattato come assente',
    (tester) async {
      final pending = Completer<List<ItemModel>>();
      final app = await ScreenshotApp.start(
        tester,
        theme: ShotTheme.light,
        setup: AppSetup(
          extraOverrides: [
            itemNotifierProvider(
              kHomeId,
            ).overrideWith(() => _DelayedItems(pending.future)),
          ],
        ),
      );
      showItemSheet(
        tester.element(find.byType(Scaffold).last),
        houseId: kHomeId,
        itemId: 'late',
      );
      await app.tester.pump();
      await app.tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(ItemSheet), findsOneWidget);
      pending.complete([
        ItemModel(
          id: 'late',
          houseId: kHomeId,
          name: 'Arrivato',
          category: ItemCategory.vestiti,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      await app.settle();
      expect(find.text('Arrivato'), findsOneWidget);
      await app.finish();
    },
  );
  testWidgets(
    'un viaggio inesistente aperto direttamente torna alla lista viaggi',
    (tester) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await app.go('/trips/missing');
      expect(find.text('Viaggio non trovato'), findsWidgets);
      await app.tap(find.text('Torna ai viaggi'));
      expect(app.router.routeInformationProvider.value.uri.path, '/trips');
      expect(tester.takeException(), isNull);
      await app.finish();
    },
  );

  testWidgets(
    'pagina inesistente nasconde l’errore del router e torna alle case',
    (tester) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await app.go('/pagina-inesistente');
      expect(find.text('Pagina non trovata'), findsWidgets);
      expect(find.textContaining('GoException'), findsNothing);
      await app.tap(find.text('Torna alla lista case'));
      expect(app.router.routeInformationProvider.value.uri.path, '/');
      await app.finish();
    },
  );
  testWidgets(
    'il testo della località in modifica sopravvive a un ricaricamento',
    (tester) async {
      final app = await ScreenshotApp.start(
        tester,
        theme: ShotTheme.light,
        setup: AppSetup(
          extraOverrides: [
            houseNotifierProvider.overrideWith(_TransientHouses.new),
          ],
        ),
      );
      final houses = await app.container.read(houseNotifierProvider.future);
      showAddEditHouseSheet(
        tester.element(find.byType(Scaffold).last),
        houseId: kHomeId,
      );
      await app.settle();
      final field = find.descendant(
        of: find.byKey(const Key('house_sheet_location')),
        matching: find.byType(TextField),
      );
      await app.enterText(field, 'Bologna');
      final notifier =
          app.container.read(houseNotifierProvider.notifier)
              as _TransientHouses;
      notifier.loading();
      await app.settle();
      notifier.restore(houses);
      await app.settle();
      expect(tester.widget<TextField>(field).controller!.text, 'Bologna');
      await app.finish();
    },
  );
}
