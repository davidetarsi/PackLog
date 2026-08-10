import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/trips/view/trip_items_selector.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

class MockHouseRepository extends Mock implements HouseRepository {}

class MockItemRepository extends Mock implements ItemRepository {}

void main() {
  late MockHouseRepository houseRepo;
  late MockItemRepository itemRepo;

  final house = HouseModel(
    id: 'house-1',
    name: 'Senigallia',
    isPrimary: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    houseRepo = MockHouseRepository();
    itemRepo = MockItemRepository();
    when(() => houseRepo.getAllHouses()).thenAnswer((_) async => [house]);
  });

  Future<void> pumpSelector(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          houseRepositoryProvider.overrideWithValue(houseRepo),
          itemRepositoryProvider.overrideWithValue(itemRepo),
        ],
        child: MaterialApp(
          // DsEmptyState legge context.errorEmptyTheme dal ThemeExtension
          // registrato in AppTheme: senza, il tema di default di MaterialApp
          // non lo espone e il build esplode con un null-check.
          theme: AppTheme.light,
          home: Scaffold(
            body: TripItemsSelector(
              selectedItems: const [],
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Il selettore preseleziona la casa primaria in un postFrameCallback che
    // parte al primo frame, prima che la lista case (async) sia arrivata: in
    // un widget test il risultato è una race persa quasi sempre, quindi
    // selezioniamo la casa esplicitamente com'è farebbe l'utente.
    await tester.tap(find.text(house.name).first);
    await tester.pumpAndSettle();
  }

  group('TripItemsSelector — casa senza oggetti', () {
    testWidgets('offre di creare un oggetto nella casa selezionata', (
      tester,
    ) async {
      // Senza questa azione, creare un viaggio da una casa vuota finisce in un
      // vicolo cieco: la pagina dice che non c'è niente e non offre una strada.
      when(
        () => itemRepo.getItemsByHouseId(any()),
      ).thenAnswer((_) async => <ItemModel>[]);

      await pumpSelector(tester);

      expect(find.byKey(const Key('trip_items_empty_add')), findsOneWidget);
    });

    testWidgets('con oggetti presenti non mostra l azione', (tester) async {
      when(() => itemRepo.getItemsByHouseId(any())).thenAnswer(
        (_) async => [
          ItemModel(
            id: 'item-1',
            houseId: 'house-1',
            name: 'Spazzolino',
            category: ItemCategory.toiletries,
            quantity: 1,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
      );

      await pumpSelector(tester);

      expect(find.byKey(const Key('trip_items_empty_add')), findsNothing);
    });
  });
}
