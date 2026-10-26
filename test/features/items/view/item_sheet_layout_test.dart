import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/providers/item_provider.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/view/item_sheet.dart';
import 'package:pack_log/features/spaces/model/space_model.dart';
import 'package:pack_log/features/spaces/repositories/space_repository.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_asset_loader.dart';

class MockItemRepository extends Mock implements ItemRepository {}

class MockSpaceRepository extends Mock implements SpaceRepository {}

/// Apre la scheda dell'oggetto [item] nella casa h1, con gli [spaces] della
/// casa e il testo ingrandito di [textScaler].
Future<void> _pumpSheet(
  WidgetTester tester, {
  required ItemModel item,
  List<SpaceModel> spaces = const [],
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final items = MockItemRepository();
  final spaceRepo = MockSpaceRepository();
  when(() => items.getItemsByHouseId('h1')).thenAnswer((_) async => [item]);
  when(
    () => spaceRepo.getSpacesByHouseId('h1'),
  ).thenAnswer((_) async => spaces);

  final container = ProviderContainer(
    overrides: [
      itemRepositoryProvider.overrideWithValue(items),
      spaceRepositoryProvider.overrideWithValue(spaceRepo),
    ],
  );
  addTearDown(container.dispose);
  // La scheda legge l'oggetto dalla lista già caricata.
  await container.read(itemNotifierProvider('h1').future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        assetLoader: MemoryAssetLoader(readAppTranslations()),
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.light,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showItemSheet(context, houseId: 'h1', itemId: item.id),
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

ItemModel _calzini({String? description, String? spaceId}) => ItemModel(
  id: 'i1',
  houseId: 'h1',
  name: 'Calzini',
  category: ItemCategory.vestiti,
  description: description,
  spaceId: spaceId,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('un nome di spazio lungo si accorcia invece di sforare', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const longName = 'Cassettiera grande della camera degli ospiti al piano';
    await _pumpSheet(
      tester,
      item: _calzini(spaceId: 's1'),
      spaces: [
        SpaceModel(
          id: 's1',
          houseId: 'h1',
          name: longName,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );

    expect(find.byKey(const Key('item_sheet_space')), findsOneWidget);
    expect(find.text(longName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la CTA resta visibile senza scorrere', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longNote = List.filled(40, 'Nota lunga per la scheda.').join(' ');
    await _pumpSheet(tester, item: _calzini(description: longNote));

    expect(
      find.byKey(const Key('item_sheet_save')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(const Key('item_sheet_save')),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('testo a 2.0 con menu e x ancora raggiungibili', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSheet(
      tester,
      item: _calzini(spaceId: 's1'),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('item_sheet_menu')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byKey(const Key('sheet_close')).hitTestable(), findsOneWidget);
  });
}
