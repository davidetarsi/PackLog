import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stuff_tracker_2/features/items/model/item_model.dart';
import 'package:stuff_tracker_2/features/items/repositories/item_repository.dart';
import 'package:stuff_tracker_2/features/items/providers/item_provider.dart';
import 'package:stuff_tracker_2/features/bulk_creation/providers/bulk_creation_provider.dart';
import 'package:stuff_tracker_2/features/bulk_creation/model/user_gender.dart';

/// Mock del repository degli item.
class MockItemRepository extends Mock implements ItemRepository {}

void main() {
  late MockItemRepository mockRepository;
  late ProviderContainer container;

  setUpAll(() {
    // Registra fallback per argomenti any()
    registerFallbackValue(<ItemModel>[]);
  });

  setUp(() {
    mockRepository = MockItemRepository();

    container = ProviderContainer(
      overrides: [
        itemRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('BulkCreationNotifier - saveToDatabase', () {
    test('should throw StateError if targetHouseId is null', () async {
      // === ARRANGE ===
      final notifier = container.read(bulkCreationNotifierProvider.notifier);

      // Add some manual items (without setting targetHouseId)
      notifier.addManualItem(ItemCategory.varie);

      // === ACT & ASSERT ===
      expect(
        () => notifier.saveToDatabase(),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('targetHouseId non impostato'),
        )),
      );

      // Verify repository was never called
      verifyNever(() => mockRepository.insertMultipleItems(any()));
    });

    test('should throw StateError if no items to save', () async {
      // === ARRANGE ===
      final notifier = container.read(bulkCreationNotifierProvider.notifier);
      notifier.setTargetHouse('test-house-1');

      // === ACT & ASSERT ===
      expect(
        () => notifier.saveToDatabase(),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Nessun item da salvare'),
        )),
      );

      verifyNever(() => mockRepository.insertMultipleItems(any()));
    });

    test('should generate fresh UUIDs and save items to database', () async {
      // === ARRANGE ===
      final notifier = container.read(bulkCreationNotifierProvider.notifier);
      notifier.setTargetHouse('house-123');

      // Add manual items (they will have deterministic or random IDs in state)
      notifier.addManualItem(ItemCategory.vestiti);
      notifier.addManualItem(ItemCategory.elettronica);

      final state = container.read(bulkCreationNotifierProvider);
      expect(state.allItems, hasLength(2));

      // Mock successful insertion
      when(() => mockRepository.insertMultipleItems(any()))
          .thenAnswer((_) async {});

      // === ACT ===
      await notifier.saveToDatabase();

      // === ASSERT ===
      final captured = verify(
        () => mockRepository.insertMultipleItems(captureAny()),
      ).captured.single as List<ItemModel>;

      // Verify correct number of items
      expect(captured, hasLength(2));

      // Verify all items have:
      // - Fresh UUIDs (not the deterministic IDs from state)
      // - Correct houseId
      // - Valid timestamps
      for (final item in captured) {
        expect(item.id, isNotEmpty);
        expect(item.id, isNot(startsWith('tpl_'))); // Not a deterministic ID
        expect(item.houseId, 'house-123');
        expect(item.createdAt, isNotNull);
        expect(item.updatedAt, isNotNull);
      }
    });

    test('should invalidate itemNotifierProvider after successful save', () async {
      // === ARRANGE ===
      final houseId = 'house-456';
      final notifier = container.read(bulkCreationNotifierProvider.notifier);

      notifier.setTargetHouse(houseId);
      notifier.addManualItem(ItemCategory.varie);

      when(() => mockRepository.insertMultipleItems(any()))
          .thenAnswer((_) async {});

      // Listen to the provider to detect invalidation
      var invalidationCount = 0;
      container.listen(
        itemNotifierProvider(houseId),
        (previous, next) => invalidationCount++,
        fireImmediately: false,
      );

      // === ACT ===
      await notifier.saveToDatabase();

      // === ASSERT ===
      // Provider should be invalidated after save
      expect(invalidationCount, greaterThan(0));
    });

    test('should reset state after successful save', () async {
      // === ARRANGE ===
      final notifier = container.read(bulkCreationNotifierProvider.notifier);

      notifier.setTargetHouse('house-789');
      notifier.setGender(UserGender.female);
      notifier.addManualItem(ItemCategory.vestiti);

      when(() => mockRepository.insertMultipleItems(any()))
          .thenAnswer((_) async {});

      // Verify state before save
      var stateBefore = container.read(bulkCreationNotifierProvider);
      expect(stateBefore.targetHouseId, 'house-789');
      expect(stateBefore.gender, UserGender.female);
      expect(stateBefore.allItems, isNotEmpty);

      // === ACT ===
      await notifier.saveToDatabase();

      // === ASSERT ===
      final stateAfter = container.read(bulkCreationNotifierProvider);
      expect(stateAfter.targetHouseId, isNull);
      expect(stateAfter.gender, UserGender.neutral);
      expect(stateAfter.allItems, isEmpty);
      expect(stateAfter.selectedTemplateKeys, isEmpty);
    });

    test('should include spaceId if set in state', () async {
      // === ARRANGE ===
      final notifier = container.read(bulkCreationNotifierProvider.notifier);

      notifier.setTargetHouse('house-with-space');
      notifier.setTargetSpace('kitchen-space');
      notifier.addManualItem(ItemCategory.varie);

      when(() => mockRepository.insertMultipleItems(any()))
          .thenAnswer((_) async {});

      // === ACT ===
      await notifier.saveToDatabase();

      // === ASSERT ===
      final captured = verify(
        () => mockRepository.insertMultipleItems(captureAny()),
      ).captured.single as List<ItemModel>;

      expect(captured.first.spaceId, 'kitchen-space');
    });

    test('should propagate repository errors to caller', () async {
      // === ARRANGE ===
      final notifier = container.read(bulkCreationNotifierProvider.notifier);

      notifier.setTargetHouse('house-error');
      notifier.addManualItem(ItemCategory.varie);

      // Mock repository failure
      when(() => mockRepository.insertMultipleItems(any()))
          .thenThrow(Exception('Database connection failed'));

      // === ACT & ASSERT ===
      expect(
        () => notifier.saveToDatabase(),
        throwsException,
      );

      // State should NOT be reset on failure
      final stateAfterError = container.read(bulkCreationNotifierProvider);
      expect(stateAfterError.allItems, isNotEmpty,
          reason: 'State should be preserved on save failure');
    });

    test('should correctly map all DraftItem fields to ItemModel', () async {
      // === ARRANGE ===
      final notifier = container.read(bulkCreationNotifierProvider.notifier);

      notifier.setTargetHouse('house-mapping-test');
      notifier.addManualItem(ItemCategory.elettronica);

      // Rename and update quantity
      final state = container.read(bulkCreationNotifierProvider);
      final itemId = state.allItems.first.id;
      notifier.renameItem(itemId, 'Custom Laptop');
      notifier.updateQuantity(itemId, 2); // Quantity becomes 3

      when(() => mockRepository.insertMultipleItems(any()))
          .thenAnswer((_) async {});

      // === ACT ===
      await notifier.saveToDatabase();

      // === ASSERT ===
      final captured = verify(
        () => mockRepository.insertMultipleItems(captureAny()),
      ).captured.single as List<ItemModel>;

      final savedItem = captured.first;
      expect(savedItem.name, 'Custom Laptop');
      expect(savedItem.category, ItemCategory.elettronica);
      expect(savedItem.quantity, 3);
      expect(savedItem.houseId, 'house-mapping-test');
      expect(savedItem.description, isNull);
    });
  });
}
