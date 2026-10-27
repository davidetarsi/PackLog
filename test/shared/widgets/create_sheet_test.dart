import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/profile/providers/gpt_usage_provider.dart';
import 'package:pack_log/shared/widgets/create_sheet.dart';

HouseModel _house(String id, {bool primary = false}) => HouseModel(
  id: id,
  name: 'Casa $id',
  isPrimary: primary,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _FakeHouseNotifier extends HouseNotifier {
  _FakeHouseNotifier(this.houses);
  final List<HouseModel> houses;
  @override
  Future<List<HouseModel>> build() async => houses;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('defaultDestinationHouse', () {
    test('null senza case', () {
      expect(defaultDestinationHouse(const []), isNull);
    });
    test('preferisce la casa principale', () {
      expect(
        defaultDestinationHouse([_house('a'), _house('b', primary: true)])!.id,
        'b',
      );
    });
    test('senza principale prende la prima', () {
      expect(defaultDestinationHouse([_house('a'), _house('b')])!.id, 'a');
    });
  });

  /// Monta un bottone che apre il foglio; restituisce una funzione che legge
  /// la scelta (null se il foglio è ancora aperto o chiuso senza scelta).
  Future<CreateChoice? Function()> openSheet(
    WidgetTester tester, {
    required List<HouseModel> houses,
    bool aiExhausted = false,
  }) async {
    CreateChoice? result;
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        saveLocale: false,
        child: ProviderScope(
          overrides: [
            houseNotifierProvider.overrideWith(
              () => _FakeHouseNotifier(houses),
            ),
            gptUsageProvider.overrideWith(
              (ref) async =>
                  GptUsageModel(usageCount: aiExhausted ? 30 : 3, usageCap: 30),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  key: const Key('open'),
                  onPressed: () async {
                    result = await showCreateSheet(context);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byType(CreateSheet), findsOneWidget);
    return () => result;
  }

  testWidgets('Scansiona con AI restituisce la casa principale', (
    tester,
  ) async {
    final read = await openSheet(
      tester,
      houses: [_house('a'), _house('b', primary: true)],
    );
    await tester.tap(find.byKey(const Key('create_ai_scan')));
    await tester.pumpAndSettle();
    expect(read()!.action, CreateAction.aiScan);
    expect(read()!.houseId, 'b');
  });

  testWidgets('cambiare casa e scegliere Aggiungi oggetti', (tester) async {
    final read = await openSheet(
      tester,
      houses: [_house('a', primary: true), _house('b')],
    );
    await tester.tap(find.byKey(const Key('create_destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa b').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('create_manual_items')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_manual_items')));
    await tester.pumpAndSettle();
    expect(read()!.action, CreateAction.manualItems);
    expect(read()!.houseId, 'b');
  });

  testWidgets('Nuova casa e Nuovo viaggio', (tester) async {
    var read = await openSheet(tester, houses: [_house('a')]);
    await tester.ensureVisible(find.byKey(const Key('create_new_house')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_new_house')));
    await tester.pumpAndSettle();
    expect(read()!.action, CreateAction.newHouse);

    read = await openSheet(tester, houses: [_house('a')]);
    await tester.ensureVisible(find.byKey(const Key('create_new_trip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_new_trip')));
    await tester.pumpAndSettle();
    expect(read()!.action, CreateAction.newTrip);
  });

  testWidgets('ordine fisso: le due AI in alto, poi oggetti, viaggio, casa', (
    tester,
  ) async {
    double y(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;

    await openSheet(tester, houses: [_house('a')]);
    final order = [
      'create_ai_scan',
      'create_ai_suitcase',
      'create_manual_items',
      'create_new_trip',
      'create_new_house',
    ];
    for (var i = 1; i < order.length; i++) {
      expect(y(order[i - 1]), lessThan(y(order[i])), reason: order[i]);
    }
    expect(find.text('create_sheet.without_ai'), findsOneWidget);
  });

  testWidgets('la casa sta sotto il testo della scansione, in colore neutro', (
    tester,
  ) async {
    await openSheet(tester, houses: [_house('a')]);
    final chooser = find.byKey(const Key('create_destination'));
    final title = find.text('create_sheet.ai_scan');

    expect(tester.getTopLeft(chooser).dx, tester.getTopLeft(title).dx);
    expect(
      tester.getTopLeft(chooser).dy,
      greaterThan(tester.getTopLeft(title).dy),
    );
    expect(
      find.descendant(of: chooser, matching: find.byIcon(Icons.expand_more)),
      findsOneWidget,
    );

    final scheme = Theme.of(tester.element(chooser)).colorScheme;
    final label = tester.widget<Text>(
      find.descendant(of: chooser, matching: find.byType(Text)),
    );
    expect(label.style?.color, scheme.onSurface);
  });

  testWidgets('senza case: scansione e oggetti spenti, Viaggio con AI attivo, '
      'Nuova casa in evidenza', (tester) async {
    final read = await openSheet(tester, houses: const []);
    expect(find.text('create_sheet.need_house'), findsOneWidget);
    expect(find.text('create_sheet.manual_need_house'), findsOneWidget);
    expect(find.byKey(const Key('create_destination')), findsNothing);

    await tester.tap(find.byKey(const Key('create_ai_scan')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('create_manual_items')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_manual_items')));
    await tester.pumpAndSettle();
    expect(find.byType(CreateSheet), findsOneWidget, reason: 'non si chiude');
    expect(read(), isNull);

    final scheme = Theme.of(
      tester.element(find.byType(CreateSheet)),
    ).colorScheme;
    final title = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('create_new_house')),
        matching: find.text('create_sheet.new_house'),
      ),
    );
    expect(title.style?.color, scheme.primary);

    await tester.tap(find.byKey(const Key('create_ai_suitcase')));
    await tester.pumpAndSettle();
    expect(read()!.action, CreateAction.aiSuitcase);
  });

  testWidgets('Viaggio con AI restituisce aiSuitcase', (tester) async {
    final read = await openSheet(tester, houses: [_house('a')]);
    expect(find.text('create_sheet.ai_suitcase'), findsOneWidget);
    expect(find.text('create_sheet.ai_suitcase_hint'), findsOneWidget);

    await tester.tap(find.byKey(const Key('create_ai_suitcase')));
    await tester.pumpAndSettle();
    expect(read()!.action, CreateAction.aiSuitcase);
  });

  testWidgets(
    'usi AI esauriti: le due card spente, gli oggetti a mano restano',
    (tester) async {
      final read = await openSheet(
        tester,
        houses: [_house('a')],
        aiExhausted: true,
      );
      expect(find.text('create_sheet.ai_exhausted'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('create_ai_scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create_ai_suitcase')));
      await tester.pumpAndSettle();
      expect(read(), isNull);

      await tester.ensureVisible(find.byKey(const Key('create_manual_items')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_manual_items')));
      await tester.pumpAndSettle();
      expect(read()!.action, CreateAction.manualItems);
    },
  );

  testWidgets('testo a 2.0 su schermo stretto: niente overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await openSheet(tester, houses: [_house('una casa dal nome molto lungo')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la testata ha la x e chiude senza scelta', (tester) async {
    final read = await openSheet(tester, houses: [_house('a')]);

    await tester.tap(find.byKey(const Key('sheet_close')));
    await tester.pumpAndSettle();

    expect(find.byType(CreateSheet), findsNothing);
    expect(read(), isNull);
  });
}
