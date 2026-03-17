import 'package:flutter_test/flutter_test.dart';
import 'package:stuff_tracker_2/core/database/converters/luggage_size_converter.dart';
import 'package:stuff_tracker_2/features/luggages/model/luggage_model.dart';

/// Unit tests for LuggageSizeConverter (Drift TypeConverter).
/// 
/// Tests the bidirectional conversion between LuggageSize enum and String:
/// - toSql: LuggageSize → String (for SQLite storage)
/// - fromSql: String → LuggageSize (for deserialization)
/// - Fallback handling for invalid/unknown database strings
void main() {
  late LuggageSizeConverter converter;

  setUp(() {
    converter = const LuggageSizeConverter();
  });

  group('LuggageSizeConverter - toSql (Enum → String)', () {
    test('should convert smallBackpack to string', () {
      // === ACT ===
      final result = converter.toSql(LuggageSize.smallBackpack);

      // === ASSERT ===
      expect(result, equals('small_backpack'));
    });

    test('should convert cabinBaggage to string', () {
      // === ACT ===
      final result = converter.toSql(LuggageSize.cabinBaggage);

      // === ASSERT ===
      expect(result, equals('cabin_baggage'));
    });

    test('should convert holdBaggage to string', () {
      // === ACT ===
      final result = converter.toSql(LuggageSize.holdBaggage);

      // === ASSERT ===
      expect(result, equals('hold_baggage'));
    });

    test('should convert custom to string', () {
      // === ACT ===
      final result = converter.toSql(LuggageSize.custom);

      // === ASSERT ===
      expect(result, equals('custom'));
    });

    test('should convert all enum values correctly (comprehensive)', () {
      // === ARRANGE ===
      final expectedMappings = {
        LuggageSize.smallBackpack: 'small_backpack',
        LuggageSize.cabinBaggage: 'cabin_baggage',
        LuggageSize.holdBaggage: 'hold_baggage',
        LuggageSize.custom: 'custom',
      };

      // === ACT & ASSERT ===
      for (final entry in expectedMappings.entries) {
        final result = converter.toSql(entry.key);
        expect(
          result,
          equals(entry.value),
          reason: '${entry.key} should map to ${entry.value}',
        );
      }
    });
  });

  group('LuggageSizeConverter - fromSql (String → Enum)', () {
    test('should convert "small_backpack" string to enum', () {
      // === ACT ===
      final result = converter.fromSql('small_backpack');

      // === ASSERT ===
      expect(result, equals(LuggageSize.smallBackpack));
    });

    test('should convert "cabin_baggage" string to enum', () {
      // === ACT ===
      final result = converter.fromSql('cabin_baggage');

      // === ASSERT ===
      expect(result, equals(LuggageSize.cabinBaggage));
    });

    test('should convert "hold_baggage" string to enum', () {
      // === ACT ===
      final result = converter.fromSql('hold_baggage');

      // === ASSERT ===
      expect(result, equals(LuggageSize.holdBaggage));
    });

    test('should convert "custom" string to enum', () {
      // === ACT ===
      final result = converter.fromSql('custom');

      // === ASSERT ===
      expect(result, equals(LuggageSize.custom));
    });

    test('should fallback to custom for unknown database string', () {
      // === ACT ===
      final result = converter.fromSql('unknown_luggage_type');

      // === ASSERT ===
      // Architectural Intent: Safe fallback prevents app crashes from:
      // - Database corruption
      // - Schema evolution (new types added later)
      // - Manual DB edits
      expect(result, equals(LuggageSize.custom), reason: 'Unknown values should default to custom');
    });

    test('should fallback to custom for empty string', () {
      // === ACT ===
      final result = converter.fromSql('');

      // === ASSERT ===
      expect(result, equals(LuggageSize.custom), reason: 'Empty string should default to custom');
    });

    test('should fallback to custom for invalid format', () {
      // === ACT ===
      final testCases = [
        'HOLD_BAGGAGE', // Uppercase
        'hold-baggage', // Wrong separator
        'holdBaggage',  // camelCase
        'hold baggage', // Space instead of underscore
        '123',          // Numeric
        'null',         // String "null"
      ];

      // === ASSERT ===
      for (final testCase in testCases) {
        final result = converter.fromSql(testCase);
        expect(
          result,
          equals(LuggageSize.custom),
          reason: '"$testCase" should fallback to custom',
        );
      }
    });
  });

  group('LuggageSizeConverter - Bidirectional Consistency', () {
    test('should maintain consistency through round-trip conversion', () {
      // === ARRANGE ===
      final allSizes = LuggageSize.values;

      // === ACT & ASSERT ===
      // For each enum value, convert to DB string and back
      for (final size in allSizes) {
        final dbString = converter.toSql(size);
        final roundTripSize = converter.fromSql(dbString);

        expect(
          roundTripSize,
          equals(size),
          reason: '$size should survive round-trip conversion',
        );
      }
    });
  });
}
