import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/view/bulk_move_sheet.dart';
import 'package:pack_log/shared/widgets/ds_settings.dart';
import 'package:pack_log/features/spaces/model/space_model.dart';
import 'package:pack_log/features/spaces/repositories/space_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

class _MockHouseRepository extends Mock implements HouseRepository {}

class _MockSpaceRepository extends Mock implements SpaceRepository {}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      translations;
}

void main() {
  late _TestAssetLoader assetLoader;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final translations =
        jsonDecode(File('assets/translations/it-IT.json').readAsStringSync())
            as Map<String, dynamic>;
    assetLoader = _TestAssetLoader(translations);
  });

  testWidgets('errore spazi mostra retry e il retry ricarica il provider', (
    tester,
  ) async {
    final houseRepository = _MockHouseRepository();
    final spaceRepository = _MockSpaceRepository();
    var spaceLoads = 0;
    final now = DateTime(2026);
    final destination = HouseModel(
      id: 'destination',
      name: 'Casa destinazione',
      createdAt: now,
      updatedAt: now,
    );

    when(
      () => houseRepository.getAllHouses(),
    ).thenAnswer((_) async => [destination]);
    when(() => spaceRepository.getSpacesByHouseId('destination')).thenAnswer((
      _,
    ) async {
      spaceLoads++;
      if (spaceLoads == 1) throw Exception('errore temporaneo');
      return <SpaceModel>[];
    });

    BulkMoveDestination? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          houseRepositoryProvider.overrideWithValue(houseRepository),
          spaceRepositoryProvider.overrideWithValue(spaceRepository),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('it', 'IT')],
          path: 'assets/translations',
          fallbackLocale: const Locale('it', 'IT'),
          startLocale: const Locale('it', 'IT'),
          assetLoader: assetLoader,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await BulkMoveSheet.show(
                        context,
                        itemCount: 1,
                        sourceHouseId: 'source',
                      );
                    },
                    child: const Text('Apri'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa destinazione'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(find.text('storage.load_failed'.tr()), findsOneWidget);
    expect(find.text('common.retry'.tr()), findsOneWidget);
    await tester.tap(find.text('common.retry'.tr()));
    await tester.pumpAndSettle();

    expect(spaceLoads, 2);
    expect(find.byType(BulkMoveSheet), findsNothing);
    expect(result?.houseId, 'destination');
    expect(result?.spaceId, isNull);
  });

  testWidgets('doppio tocco sullo spazio chiude solo il foglio una volta', (
    tester,
  ) async {
    final houseRepository = _MockHouseRepository();
    final spaceRepository = _MockSpaceRepository();
    final now = DateTime(2026);
    final destination = HouseModel(
      id: 'destination',
      name: 'Casa destinazione',
      createdAt: now,
      updatedAt: now,
    );
    final space = SpaceModel(
      id: 'space-1',
      houseId: destination.id,
      name: 'Armadio camera',
      createdAt: now,
      updatedAt: now,
    );

    when(
      () => houseRepository.getAllHouses(),
    ).thenAnswer((_) async => [destination]);
    when(
      () => spaceRepository.getSpacesByHouseId(destination.id),
    ).thenAnswer((_) async => [space]);

    BulkMoveDestination? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          houseRepositoryProvider.overrideWithValue(houseRepository),
          spaceRepositoryProvider.overrideWithValue(spaceRepository),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('it', 'IT')],
          path: 'assets/translations',
          fallbackLocale: const Locale('it', 'IT'),
          startLocale: const Locale('it', 'IT'),
          assetLoader: assetLoader,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await BulkMoveSheet.show(
                        context,
                        itemCount: 1,
                        sourceHouseId: 'source',
                      );
                    },
                    child: const Text('Apri'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(destination.name));
    await tester.pumpAndSettle();
    final spaceFinder = find.text(space.name);
    final spaceTile = tester.widget<ListTile>(
      find.ancestor(of: spaceFinder, matching: find.byType(ListTile)),
    );
    final onTap = spaceTile.onTap;
    expect(onTap, isNotNull);
    onTap!();
    onTap();
    await tester.pumpAndSettle();

    expect(result?.houseId, destination.id);
    expect(result?.spaceId, space.id);
    expect(find.byType(BulkMoveSheet), findsNothing);
    expect(find.text('Apri'), findsOneWidget);
  });

  testWidgets('durante il caricamento non parte una seconda casa', (
    tester,
  ) async {
    final houseRepository = _MockHouseRepository();
    final spaceRepository = _MockSpaceRepository();
    final now = DateTime(2026);
    final firstHouse = HouseModel(
      id: 'first',
      name: 'Casa A',
      createdAt: now,
      updatedAt: now,
    );
    final secondHouse = HouseModel(
      id: 'second',
      name: 'Casa B',
      createdAt: now,
      updatedAt: now,
    );
    final firstLoad = Completer<List<SpaceModel>>();
    var secondHouseLoads = 0;

    when(
      () => houseRepository.getAllHouses(),
    ).thenAnswer((_) async => [firstHouse, secondHouse]);
    when(
      () => spaceRepository.getSpacesByHouseId(firstHouse.id),
    ).thenAnswer((_) => firstLoad.future);
    when(() => spaceRepository.getSpacesByHouseId(secondHouse.id)).thenAnswer((
      _,
    ) async {
      secondHouseLoads++;
      return <SpaceModel>[];
    });

    BulkMoveDestination? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          houseRepositoryProvider.overrideWithValue(houseRepository),
          spaceRepositoryProvider.overrideWithValue(spaceRepository),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('it', 'IT')],
          path: 'assets/translations',
          fallbackLocale: const Locale('it', 'IT'),
          startLocale: const Locale('it', 'IT'),
          assetLoader: assetLoader,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await BulkMoveSheet.show(
                        context,
                        itemCount: 1,
                        sourceHouseId: 'source',
                      );
                    },
                    child: const Text('Apri'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(firstHouse.name));
    await tester.pump();
    await tester.tap(find.text(secondHouse.name));
    await tester.pump();

    expect(secondHouseLoads, 0);
    expect(
      tester
          .widget<ListTile>(
            find.ancestor(
              of: find.text(secondHouse.name),
              matching: find.byType(ListTile),
            ),
          )
          .enabled,
      isFalse,
    );

    firstLoad.complete(<SpaceModel>[]);
    await tester.pumpAndSettle();
    expect(result?.houseId, firstHouse.id);
    expect(find.text('Apri'), findsOneWidget);
  });

  testWidgets('case e spazi sono gruppi del design system', (tester) async {
    final houseRepository = _MockHouseRepository();
    final spaceRepository = _MockSpaceRepository();
    final now = DateTime(2026);
    final destination = HouseModel(
      id: 'destination',
      name: 'Casa destinazione',
      createdAt: now,
      updatedAt: now,
    );
    final space = SpaceModel(
      id: 'space-1',
      houseId: destination.id,
      name: 'Armadio camera',
      createdAt: now,
      updatedAt: now,
    );

    when(
      () => houseRepository.getAllHouses(),
    ).thenAnswer((_) async => [destination]);
    when(
      () => spaceRepository.getSpacesByHouseId(destination.id),
    ).thenAnswer((_) async => [space]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          houseRepositoryProvider.overrideWithValue(houseRepository),
          spaceRepositoryProvider.overrideWithValue(spaceRepository),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('it', 'IT')],
          path: 'assets/translations',
          fallbackLocale: const Locale('it', 'IT'),
          startLocale: const Locale('it', 'IT'),
          assetLoader: assetLoader,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => BulkMoveSheet.show(
                      context,
                      itemCount: 1,
                      sourceHouseId: 'source',
                    ),
                    child: const Text('Apri'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    expect(find.byType(DsSettingsGroup), findsOneWidget);

    await tester.tap(find.text(destination.name));
    await tester.pumpAndSettle();

    expect(find.byType(DsSettingsGroup), findsNWidgets(2));
  });
}
