import 'package:flutter_test/flutter_test.dart';
import 'package:stuff_tracker_2/core/database/converters/item_category_converter.dart';
import 'package:stuff_tracker_2/features/items/model/item_model.dart';

/// Unit tests for ItemCategoryConverter.
/// 
/// Tests the bidirectional conversion between ItemCategory enum and String:
/// - toDatabase: ItemCategory → String (for SQLite storage)
/// - fromDatabase: String → ItemCategory (for deserialization)
/// - Fallback handling for invalid/unknown database strings
void main() {
  group('ItemCategoryConverter - toDatabase (Enum → String)', () {
    test('should convert vestiti to string', () {
      // === ACT ===
      final result = ItemCategoryConverter.toDatabase(ItemCategory.vestiti);

      // === ASSERT ===
      expect(result, equals('vestiti'));
    });

    test('should convert toiletries to string', () {
      // === ACT ===
      final result = ItemCategoryConverter.toDatabase(ItemCategory.toiletries);

      // === ASSERT ===
      expect(result, equals('toiletries'));
    });

    test('should convert elettronica to string', () {
      // === ACT ===
      final result = ItemCategoryConverter.toDatabase(ItemCategory.elettronica);

      // === ASSERT ===
      expect(result, equals('elettronica'));
    });

    test('should convert varie to string', () {
      // === ACT ===
      final result = ItemCategoryConverter.toDatabase(ItemCategory.varie);

      // === ASSERT ===
      expect(result, equals('varie'));
    });

    test('should convert all enum values correctly (comprehensive)', () {
      // === ARRANGE ===
      final expectedMappings = {
        ItemCategory.vestiti: 'vestiti',
        ItemCategory.toiletries: 'toiletries',
        ItemCategory.elettronica: 'elettronica',
        ItemCategory.varie: 'varie',
      };

      // === ACT & ASSERT ===
      for (final entry in expectedMappings.entries) {
        final result = ItemCategoryConverter.toDatabase(entry.key);
        expect(
          result,
          equals(entry.value),
          reason: '${entry.key} should map to ${entry.value}',
        );
      }
    });
  });

  group('ItemCategoryConverter - fromDatabase (String → Enum)', () {
    test('should convert "vestiti" string to enum', () {
      // === ACT ===
      final result = ItemCategoryConverter.fromDatabase('vestiti');

      // === ASSERT ===
      expect(result, equals(ItemCategory.vestiti));
    });

    test('should convert "toiletries" string to enum', () {
      // === ACT ===
      final result = ItemCategoryConverter.fromDatabase('toiletries');

      // === ASSERT ===
      expect(result, equals(ItemCategory.toiletries));
    });

    test('should convert "elettronica" string to enum', () {
      // === ACT ===
      final result = ItemCategoryConverter.fromDatabase('elettronica');

      // === ASSERT ===
      expect(result, equals(ItemCategory.elettronica));
    });

    test('should convert "varie" string to enum', () {
      // === ACT ===
      final result = ItemCategoryConverter.fromDatabase('varie');

      // === ASSERT ===
      expect(result, equals(ItemCategory.varie));
    });

    test('should fallback to varie for unknown database string', () {
      // === ACT ===
      final result = ItemCategoryConverter.fromDatabase('unknown_category');

      // === ASSERT ===
      // Architectural Intent: Safe fallback prevents app crashes from corrupted data
      expect(result, equals(ItemCategory.varie), reason: 'Unknown values should default to varie');
    });

    test('should fallback to varie for empty string', () {
      // === ACT ===
      final result = ItemCategoryConverter.fromDatabase('');

      // === ASSERT ===
      expect(result, equals(ItemCategory.varie), reason: 'Empty string should default to varie');
    });

    test('should be case-sensitive (uppercase should fallback)', () {
      // === ACT ===
      final result = ItemCategoryConverter.fromDatabase('VESTITI');

      // === ASSERT ===
      // Current implementation uses exact match (enum.name)
      expect(result, equals(ItemCategory.varie), reason: 'Case mismatch should fallback to varie');
    });
  });

  group('ItemCategoryConverter - Bidirectional Consistency', () {
    test('should maintain consistency through round-trip conversion', () {
      // === ARRANGE ===
      final allCategories = ItemCategory.values;

      // === ACT & ASSERT ===
      // For each enum value, convert to DB string and back
      for (final category in allCategories) {
        final dbString = ItemCategoryConverter.toDatabase(category);
        final roundTripCategory = ItemCategoryConverter.fromDatabase(dbString);

        expect(
          roundTripCategory,
          equals(category),
          reason: '$category should survive round-trip conversion',
        );
      }
    });
  });
}
