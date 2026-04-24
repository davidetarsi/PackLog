import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/trips/domain/packing_inventory_service.dart';

class MockItemRepository extends Mock implements ItemRepository {}

ItemModel _makeItem({
  required String id,
  required ItemCategory category,
  Map<String, dynamic>? aiMetadata,
}) {
  return ItemModel(
    id: id,
    houseId: 'house-1',
    name: 'Item $id',
    category: category,
    aiMetadata: aiMetadata,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

void main() {
  late MockItemRepository mockRepo;
  late PackingInventoryService service;

  setUp(() {
    mockRepo = MockItemRepository();
    service = PackingInventoryService(mockRepo);

    // Default: no items
    when(
      () => mockRepo.getAllItemsByCategories(any()),
    ).thenAnswer((_) async => []);
  });

  group('PackingInventoryService - getFilteredInventoryForTrip', () {
    group('Bucket splitting', () {
      test('vestiti items go to wardrobe bucket', () async {
        final shirt = _makeItem(id: 'shirt', category: ItemCategory.vestiti);
        when(
          () => mockRepo.getAllItemsByCategories([ItemCategory.vestiti]),
        ).thenAnswer((_) async => [shirt]);

        final result = await service.getFilteredInventoryForTrip([]);
        expect(result.wardrobe, contains(shirt));
        expect(result.essentials, isEmpty);
      });

      test('toiletries, elettronica, varie go to essentials bucket', () async {
        final soap = _makeItem(id: 'soap', category: ItemCategory.toiletries);
        final phone = _makeItem(id: 'phone', category: ItemCategory.elettronica);
        final misc = _makeItem(id: 'misc', category: ItemCategory.varie);

        when(
          () => mockRepo.getAllItemsByCategories([
            ItemCategory.toiletries,
            ItemCategory.elettronica,
            ItemCategory.varie,
          ]),
        ).thenAnswer((_) async => [soap, phone, misc]);

        final result = await service.getFilteredInventoryForTrip([]);
        expect(result.essentials, containsAll([soap, phone, misc]));
        expect(result.wardrobe, isEmpty);
      });
    });

    group('Weather filtering — wardrobe only', () {
      test('items WITHOUT aiMetadata are always kept', () async {
        final noMeta = _makeItem(id: 'no-meta', category: ItemCategory.vestiti);
        when(
          () => mockRepo.getAllItemsByCategories([ItemCategory.vestiti]),
        ).thenAnswer((_) async => [noMeta]);

        final result = await service.getFilteredInventoryForTrip(['Hot', 'Sunny']);
        expect(result.wardrobe, contains(noMeta));
      });

      test('items with empty weather array in aiMetadata are always kept', () async {
        final emptyWeather = _makeItem(
          id: 'empty-weather',
          category: ItemCategory.vestiti,
          aiMetadata: {'weather': <String>[], 'category': 'Upper Body'},
        );
        when(
          () => mockRepo.getAllItemsByCategories([ItemCategory.vestiti]),
        ).thenAnswer((_) async => [emptyWeather]);

        final result = await service.getFilteredInventoryForTrip(['Cold', 'Snow']);
        expect(result.wardrobe, contains(emptyWeather));
      });

      test('cold-only item is dropped on a hot trip', () async {
        final winterCoat = _makeItem(
          id: 'winter-coat',
          category: ItemCategory.vestiti,
          aiMetadata: {'weather': ['Snow', 'Cold'], 'category': 'Outerwear'},
        );
        when(
          () => mockRepo.getAllItemsByCategories([ItemCategory.vestiti]),
        ).thenAnswer((_) async => [winterCoat]);

        final result = await service.getFilteredInventoryForTrip(['Hot', 'Sunny']);
        expect(result.wardrobe, isEmpty,
            reason: 'winter coat should be dropped on a hot trip');
      });

      test('hot-only item is dropped on a cold trip', () async {
        final swimwear = _makeItem(
          id: 'swimwear',
          category: ItemCategory.vestiti,
          aiMetadata: {'weather': ['Hot', 'Sunny'], 'category': 'Lower Body'},
        );
        when(
          () => mockRepo.getAllItemsByCategories([ItemCategory.vestiti]),
        ).thenAnswer((_) async => [swimwear]);

        final result = await service.getFilteredInventoryForTrip(['Snow', 'Cold']);
        expect(result.wardrobe, isEmpty,
            reason: 'swimwear should be dropped on a cold trip');
      });

      test('item with overlapping weather tags is kept even on opposite trip', () async {
        // A raincoat works in cold rain AND mild rain → overlaps with 'Rain'
        final raincoat = _makeItem(
          id: 'raincoat',
          category: ItemCategory.vestiti,
          aiMetadata: {
            'weather': ['Rain', 'Cold'],
            'category': 'Outerwear',
          },
        );
        when(
          () => mockRepo.getAllItemsByCategories([ItemCategory.vestiti]),
        ).thenAnswer((_) async => [raincoat]);

        // Trip is hot but rainy — raincoat overlaps ('Rain' is neutral)
        final result = await service.getFilteredInventoryForTrip(['Hot', 'Rain']);
        expect(result.wardrobe, contains(raincoat));
      });

      test('item with mixed (hot + cold) weather tags is always kept', () async {
        // A versatile jacket could work in multiple climates
        final versatile = _makeItem(
          id: 'versatile-jacket',
          category: ItemCategory.vestiti,
          aiMetadata: {
            'weather': ['Cold', 'Mild', 'Sunny'],
            'category': 'Outerwear',
          },
        );
        when(
          () => mockRepo.getAllItemsByCategories([ItemCategory.vestiti]),
        ).thenAnswer((_) async => [versatile]);

        // Hot trip: item has Cold AND Mild — not ONLY cold, so kept
        final result = await service.getFilteredInventoryForTrip(['Hot', 'Sunny']);
        expect(result.wardrobe, contains(versatile));
      });

      test('essentials are never filtered by weather', () async {
        final toothbrush = _makeItem(
          id: 'toothbrush',
          category: ItemCategory.toiletries,
          aiMetadata: {'weather': ['Snow', 'Cold']}, // irrelevant for essentials
        );
        when(
          () => mockRepo.getAllItemsByCategories([
            ItemCategory.toiletries,
            ItemCategory.elettronica,
            ItemCategory.varie,
          ]),
        ).thenAnswer((_) async => [toothbrush]);

        final result = await service.getFilteredInventoryForTrip(['Hot', 'Sunny']);
        expect(result.essentials, contains(toothbrush));
      });

      test('empty tripWeatherTags keeps all wardrobe items', () async {
        final winterCoat = _makeItem(
          id: 'coat',
          category: ItemCategory.vestiti,
          aiMetadata: {'weather': ['Snow', 'Cold']},
        );
        when(
          () => mockRepo.getAllItemsByCategories([ItemCategory.vestiti]),
        ).thenAnswer((_) async => [winterCoat]);

        // No trip weather info → no filtering possible
        final result = await service.getFilteredInventoryForTrip([]);
        expect(result.wardrobe, contains(winterCoat));
      });
    });
  });
}
