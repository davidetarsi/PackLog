import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/items/view/add_items_sheet.dart';

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
      final houses = [_house('a'), _house('b', primary: true)];
      expect(defaultDestinationHouse(houses)!.id, 'b');
    });
    test('senza principale prende la prima', () {
      final houses = [_house('a'), _house('b')];
      expect(defaultDestinationHouse(houses)!.id, 'a');
    });
  });

  Future<Future<AddItemsChoice?> Function()> pumpLauncher(
    WidgetTester tester,
    List<HouseModel> houses,
  ) async {
    AddItemsChoice? result;
    var done = false;
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
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  key: const Key('open'),
                  onPressed: () async {
                    result = await showAddItemsSheet(context);
                    done = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return () async {
      expect(done, isTrue, reason: 'il foglio doveva chiudersi');
      return result;
    };
  }

  testWidgets('Scansiona con AI restituisce la casa principale', (
    tester,
  ) async {
    final read = await pumpLauncher(tester, [
      _house('a'),
      _house('b', primary: true),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byType(AddItemsSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_items_ai_scan')));
    await tester.pumpAndSettle();

    final choice = await read();
    expect(choice!.method, AddItemsMethod.aiScan);
    expect(choice.houseId, 'b');
  });

  testWidgets('cambiare casa e scegliere Scrivi a mano', (tester) async {
    final read = await pumpLauncher(tester, [
      _house('a', primary: true),
      _house('b'),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_items_destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa b').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_items_manual')));
    await tester.pumpAndSettle();

    final choice = await read();
    expect(choice!.method, AddItemsMethod.manual);
    expect(choice.houseId, 'b');
  });
}
