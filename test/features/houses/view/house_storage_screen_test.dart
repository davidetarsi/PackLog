import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/spaces/model/space_model.dart';
import 'package:pack_log/features/spaces/providers/space_provider.dart';
import 'package:pack_log/features/luggages/providers/luggage_provider.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_parts.dart';
import 'package:pack_log/features/spaces/view/add_edit_space_screen.dart';
import 'package:pack_log/features/luggages/view/add_edit_luggage_screen.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

class _ReadErrorSpaces extends SpaceNotifier {
  _ReadErrorSpaces(this.shouldFail);
  final bool Function() shouldFail;
  @override
  Future<List<SpaceModel>> build(String houseId) async {
    if (shouldFail()) throw StateError('errore di lettura');
    return super.build(houseId);
  }
}

class _SaveErrorSpaces extends SpaceNotifier {
  var attempts = 0;
  @override
  Future<void> addSpace(SpaceModel model) async {
    if (attempts++ == 0) throw StateError('errore di scrittura');
    return super.addSpace(model);
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  Future<ScreenshotApp> openStorage(
    WidgetTester tester, {
    String houseId = kHomeId,
    AppSetup setup = const AppSetup(),
  }) async {
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.dark,
      setup: setup,
    );
    await app.push('/houses/$houseId');
    await app.push('/houses/$houseId/storage');
    return app;
  }

  testWidgets(
    'il menu mantiene Modifica casa e apre una sola pagina per spazi e bagagli',
    (tester) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.dark);
      await app.push('/houses/$kHomeId');
      await app.tap(find.byIcon(Icons.more_vert));
      expect(find.text('Modifica casa'), findsOneWidget);
      await app.tap(find.text('Spazi e bagagli'));
      expect(find.byKey(const Key('house_storage')), findsOneWidget);
      expect(find.text('Spazi · 3'), findsOneWidget);
      expect(find.text('Bagagli · 3'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('storage_space_space-armadio')),
          matching: find.text('5 oggetti'),
        ),
        findsOneWidget,
      );
      expect(find.text('Trolley cabina'), findsOneWidget);
      app.router.pop();
      await app.settle();
      expect(find.text('Casa Milano'), findsWidgets);
      await app.finish();
    },
  );

  testWidgets(
    'creazione, rinomina e annullamento dello spazio persistono correttamente',
    (tester) async {
      final app = await openStorage(tester, houseId: kEmptyHouseId);
      await app.tap(find.byKey(const Key('storage_add_space')));
      expect(
        tester
            .widget<DsButton>(find.byKey(const Key('space_sheet_save')))
            .onPressed,
        isNull,
      );
      await app.enterText(
        find.byKey(const Key('space_sheet_name')),
        'Ripostiglio',
      );
      await app.tap(find.byKey(const Key('space_sheet_save')));
      expect(find.text('Ripostiglio'), findsOneWidget);
      await app.tap(find.text('Ripostiglio'));
      expect(
        tester
            .widget<DsButton>(find.byKey(const Key('space_sheet_save')))
            .onPressed,
        isNull,
      );
      await app.enterText(find.byKey(const Key('space_sheet_name')), 'Garage');
      await app.tap(find.byKey(const Key('sheet_close')));
      expect(find.text('Ripostiglio'), findsOneWidget);
      expect(find.text('Garage'), findsNothing);
      await app.tap(find.text('Ripostiglio'));
      await app.enterText(find.byKey(const Key('space_sheet_name')), 'Garage');
      await app.tap(find.byKey(const Key('space_sheet_save')));
      expect(find.text('Garage'), findsOneWidget);
      await app.finish();
    },
  );

  testWidgets(
    'eliminare uno spazio conserva gli oggetti e li lascia senza spazio',
    (tester) async {
      final app = await openStorage(tester);
      await tester.runAsync(
        () => app.container.read(tripNotifierProvider.future),
      );
      final before = await tester.runAsync(
        () => app.container
            .read(itemRepositoryProvider)
            .getItemsByHouseId(kHomeId),
      );
      await app.tap(find.byKey(const Key('storage_space_space-cassettiera')));
      await app.tap(find.byKey(const Key('space_sheet_menu')));
      await app.tap(find.text('Elimina spazio'));
      expect(
        find.text('Gli oggetti restano nella casa, senza spazio.'),
        findsOneWidget,
      );
      await app.tap(find.text('Elimina'));
      expect(
        find.byKey(const Key('storage_space_space-cassettiera')),
        findsNothing,
      );
      final items = await tester.runAsync(
        () => app.container.read(itemNotifierProvider(kHomeId).future),
      );
      expect(items!.where((i) => i.id == 'item-4').single.spaceId, isNull);
      expect(items.map((i) => i.id), unorderedEquals(before!.map((i) => i.id)));
      await app.finish();
    },
  );

  testWidgets('bagaglio personalizzato richiede litri validi e si salva', (
    tester,
  ) async {
    final app = await openStorage(tester, houseId: kEmptyHouseId);
    await app.tap(find.byKey(const Key('storage_add_luggage')));
    await app.enterText(
      find.byKey(const Key('luggage_sheet_name')),
      'Zaino trekking',
    );
    await app.tap(find.byKey(const Key('luggage_sheet_size')));
    await app.tap(find.text('Personalizzato'));
    await app.enterText(find.byKey(const Key('luggage_sheet_volume')), '0');
    expect(
      tester
          .widget<DsButton>(find.byKey(const Key('luggage_sheet_save')))
          .onPressed,
      isNull,
    );
    await app.enterText(find.byKey(const Key('luggage_sheet_volume')), '35');
    await app.tap(find.byKey(const Key('luggage_sheet_save')));
    expect(find.text('Zaino trekking'), findsOneWidget);
    expect(find.text('35 L'), findsOneWidget);
    await app.finish();
  });

  testWidgets('errore di lettura recuperabile senza nascondere i bagagli', (
    tester,
  ) async {
    var fail = true;
    final app = await openStorage(
      tester,
      setup: AppSetup(
        extraOverrides: [
          spaceNotifierProvider(
            kHomeId,
          ).overrideWith(() => _ReadErrorSpaces(() => fail)),
        ],
      ),
    );
    expect(
      find.text('Non è stato possibile caricare i dati. Riprova.'),
      findsOneWidget,
    );
    expect(find.text('Trolley cabina'), findsOneWidget);
    fail = false;
    await app.tap(find.text('Riprova'));
    expect(
      find.byKey(const Key('storage_space_space-armadio')),
      findsOneWidget,
    );
    await app.finish();
  });

  testWidgets(
    'salvataggio fallito conserva i campi e il retry crea un solo spazio',
    (tester) async {
      final app = await openStorage(
        tester,
        houseId: kEmptyHouseId,
        setup: AppSetup(
          extraOverrides: [
            spaceNotifierProvider(
              kEmptyHouseId,
            ).overrideWith(_SaveErrorSpaces.new),
          ],
        ),
      );
      await app.tap(find.byKey(const Key('storage_add_space')));
      await app.enterText(find.byKey(const Key('space_sheet_name')), 'Garage');
      await app.tap(find.byKey(const Key('space_sheet_save')));
      expect(find.textContaining('Vuoi riprovare'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('space_sheet_name')))
            .controller!
            .text,
        'Garage',
      );
      await app.tap(find.text('Riprova'));
      expect(find.text('Garage'), findsOneWidget);
      final spaces = await tester.runAsync(
        () => app.container.read(spaceNotifierProvider(kEmptyHouseId).future),
      );
      expect(spaces, hasLength(1));
      await app.finish();
    },
  );

  testWidgets('con tastiera e testo al 200% il modulo resta utilizzabile', (
    tester,
  ) async {
    final app = await openStorage(tester, houseId: kEmptyHouseId);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.viewInsets = FakeViewPadding(
      bottom: 300 * tester.view.devicePixelRatio,
    );
    await app.settle();
    await app.tap(find.byKey(const Key('storage_add_space')));
    await app.enterText(find.byKey(const Key('space_sheet_name')), 'Garage');
    expect(
      find.byKey(const Key('space_sheet_save')).hitTestable(),
      findsOneWidget,
    );
    expect(app.issues, isEmpty);
    await app.tap(find.byKey(const Key('space_sheet_save')));
    expect(find.text('Garage'), findsOneWidget);
    await app.finish();
  });

  testWidgets(
    'rinomina e cancellazione di un bagaglio aggiornano anche i viaggi già caricati',
    (tester) async {
      final app = await openStorage(tester);
      final initialTrips = await tester.runAsync(
        () => app.container.read(tripNotifierProvider.future),
      );
      final linkedBefore = initialTrips!
          .expand((t) => t.luggages)
          .where((l) => l.id == 'lug-cabina')
          .length;
      expect(linkedBefore, greaterThan(0));
      await app.tap(find.byKey(const Key('storage_luggage_lug-cabina')));
      await app.enterText(
        find.byKey(const Key('luggage_sheet_name')),
        'Trolley nuovo',
      );
      await app.tap(find.byKey(const Key('luggage_sheet_save')));
      var trips = await tester.runAsync(
        () => app.container.read(tripNotifierProvider.future),
      );
      expect(
        trips!
            .expand((t) => t.luggages)
            .where((l) => l.id == 'lug-cabina')
            .map((l) => l.name),
        allOf(hasLength(linkedBefore), everyElement('Trolley nuovo')),
      );
      await app.tap(find.byKey(const Key('storage_luggage_lug-cabina')));
      await app.tap(find.byKey(const Key('luggage_sheet_menu')));
      await app.tap(find.text('Elimina bagaglio'));
      await app.tap(find.text('Elimina'));
      trips = await tester.runAsync(
        () => app.container.read(tripNotifierProvider.future),
      );
      expect(
        trips!.expand((t) => t.luggages).where((l) => l.id == 'lug-cabina'),
        isEmpty,
      );
      final luggages = await tester.runAsync(
        () => app.container.read(luggageNotifierProvider(kHomeId).future),
      );
      expect(luggages!.any((l) => l.id == 'lug-cabina'), isFalse);
      await app.finish();
    },
  );

  testWidgets('un’entità rimossa non apre un modulo vuoto modificabile', (
    tester,
  ) async {
    final app = await openStorage(tester);
    final context = tester.element(find.byKey(const Key('house_storage')));
    showAddEditSpaceSheet(context, houseId: kHomeId, spaceId: 'missing');
    await app.settle();
    expect(find.text('Spazio non trovato'), findsOneWidget);
    expect(find.byKey(const Key('space_sheet_name')), findsNothing);
    await app.tap(find.byKey(const Key('sheet_close')));
    showAddEditLuggageSheet(context, houseId: kHomeId, luggageId: 'missing');
    await app.settle();
    expect(find.text('Bagaglio non trovato'), findsOneWidget);
    expect(find.byKey(const Key('luggage_sheet_name')), findsNothing);
    await app.finish();
  });

  testWidgets(
    'creare un bagaglio dalla valigia lo seleziona e lo salva nel viaggio',
    (tester) async {
      final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
      await app.go('/trips');
      await app.push('/trips/$kUpcomingTripId/edit-items');
      await tester.ensureVisible(find.byKey(const Key('pack_new_luggage')));
      await app.tap(find.byKey(const Key('pack_new_luggage')));
      await app.enterText(
        find.byKey(const Key('luggage_sheet_name')),
        'Zaino trekking',
      );
      await app.tap(find.byKey(const Key('luggage_sheet_save')));
      expect(
        find.byWidgetPredicate(
          (w) => w is PackPill && w.label == 'Zaino trekking' && w.selected,
        ),
        findsOneWidget,
      );
      await app.tap(
        find.byWidgetPredicate(
          (w) => w is DsButton && w.label.startsWith('Fatto'),
        ),
      );
      final trips = await tester.runAsync(
        () => app.container.read(tripNotifierProvider.future),
      );
      expect(
        trips!
            .firstWhere((t) => t.id == kUpcomingTripId)
            .luggages
            .any((l) => l.name == 'Zaino trekking'),
        isTrue,
      );
      await app.finish();
    },
  );

  testWidgets('casa non trovata offre un ritorno alla lista', (tester) async {
    final app = await openStorage(tester, houseId: 'missing');
    expect(find.byKey(const Key('storage_not_found')), findsOneWidget);
    await app.tap(find.byKey(const Key('storage_go_home')));
    expect(find.byKey(const Key('house_storage')), findsNothing);
    await app.finish();
  });
}
