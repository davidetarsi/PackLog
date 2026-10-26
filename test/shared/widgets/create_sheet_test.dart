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
    bool fromTrips = false,
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
                    result = await showCreateSheet(
                      context,
                      fromTrips: fromTrips,
                    );
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

  testWidgets('cambiare casa e scegliere "scrivili a mano"', (tester) async {
    final read = await openSheet(
      tester,
      houses: [_house('a', primary: true), _house('b')],
    );
    await tester.tap(find.byKey(const Key('create_destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa b').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create_manual_items')));
    await tester.pumpAndSettle();
    expect(read()!.action, CreateAction.manualItems);
    expect(read()!.houseId, 'b');
  });

  testWidgets('Nuova casa e Nuovo viaggio', (tester) async {
    var read = await openSheet(tester, houses: [_house('a')]);
    await tester.tap(find.byKey(const Key('create_new_house')));
    await tester.pumpAndSettle();
    expect(read()!.action, CreateAction.newHouse);

    read = await openSheet(tester, houses: [_house('a')]);
    await tester.tap(find.byKey(const Key('create_new_trip')));
    await tester.pumpAndSettle();
    expect(read()!.action, CreateAction.newTrip);
  });

  testWidgets(
    'ordine delle voci: da Case prima la casa, da Viaggi il viaggio',
    (tester) async {
      double y(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;

      await openSheet(tester, houses: [_house('a')]);
      expect(y('create_new_house'), lessThan(y('create_new_trip')));
      Navigator.of(tester.element(find.byType(CreateSheet))).pop();
      await tester.pumpAndSettle();

      await openSheet(tester, houses: [_house('a')], fromTrips: true);
      expect(y('create_new_trip'), lessThan(y('create_new_house')));
    },
  );

  testWidgets('senza case: scansione spenta, niente link, Nuova casa in '
      'evidenza', (tester) async {
    final read = await openSheet(tester, houses: const []);
    expect(find.text('create_sheet.need_house'), findsOneWidget);
    expect(find.byKey(const Key('create_manual_items')), findsNothing);
    expect(find.byKey(const Key('create_destination')), findsNothing);

    await tester.tap(find.byKey(const Key('create_ai_scan')));
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
  });

  testWidgets('Valigia con AI è una riga attiva, senza "In arrivo"', (
    tester,
  ) async {
    final read = await openSheet(tester, houses: [_house('a')]);
    expect(find.text('create_sheet.ai_suitcase'), findsOneWidget);
    expect(find.text('common.coming_soon'), findsNothing);

    final row = tester.widget<ListTile>(
      find.descendant(
        of: find.byKey(const Key('create_ai_suitcase')),
        matching: find.byType(ListTile),
      ),
    );
    expect(row.enabled, isTrue);
    expect(row.onTap, isNotNull);

    await tester.tap(find.byKey(const Key('create_ai_suitcase')));
    await tester.pumpAndSettle();
    expect(read()!.action, CreateAction.aiSuitcase);
  });

  testWidgets('scansioni esaurite: scansione spenta, il link a mano resta', (
    tester,
  ) async {
    final read = await openSheet(
      tester,
      houses: [_house('a')],
      aiExhausted: true,
    );
    expect(find.text('create_sheet.ai_exhausted'), findsOneWidget);
    await tester.tap(find.byKey(const Key('create_ai_scan')));
    await tester.pumpAndSettle();
    expect(read(), isNull);

    await tester.tap(find.byKey(const Key('create_manual_items')));
    await tester.pumpAndSettle();
    expect(read()!.action, CreateAction.manualItems);
  });
}
