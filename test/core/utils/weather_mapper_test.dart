import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/utils/weather_mapper.dart';

void main() {
  group('mapWmoCodeToTags', () {
    group('Clear / Cloudy (0–3)', () {
      test('code 0 → [Sunny]', () {
        expect(mapWmoCodeToTags(0), equals(['Sunny']));
      });

      test('code 1 → [Sunny]', () {
        expect(mapWmoCodeToTags(1), equals(['Sunny']));
      });

      test('code 2 → [Cloudy]', () {
        expect(mapWmoCodeToTags(2), equals(['Cloudy']));
      });

      test('code 3 → [Cloudy]', () {
        expect(mapWmoCodeToTags(3), equals(['Cloudy']));
      });
    });

    group('Fog (45, 48)', () {
      test('code 45 → [Cloudy]', () {
        expect(mapWmoCodeToTags(45), equals(['Cloudy']));
      });

      test('code 48 → [Cloudy]', () {
        expect(mapWmoCodeToTags(48), equals(['Cloudy']));
      });
    });

    group('Drizzle (51–57)', () {
      test('code 51 → [Rain]', () {
        expect(mapWmoCodeToTags(51), equals(['Rain']));
      });

      test('code 53 → [Rain]', () {
        expect(mapWmoCodeToTags(53), equals(['Rain']));
      });

      test('code 55 → [Rain]', () {
        expect(mapWmoCodeToTags(55), equals(['Rain']));
      });

      test('code 56 (freezing drizzle) → [Rain, Cold]', () {
        expect(mapWmoCodeToTags(56), equals(['Rain', 'Cold']));
      });

      test('code 57 (freezing drizzle dense) → [Rain, Cold]', () {
        expect(mapWmoCodeToTags(57), equals(['Rain', 'Cold']));
      });
    });

    group('Rain (61–67)', () {
      test('code 61 → [Rain]', () {
        expect(mapWmoCodeToTags(61), equals(['Rain']));
      });

      test('code 63 → [Rain]', () {
        expect(mapWmoCodeToTags(63), equals(['Rain']));
      });

      test('code 65 → [Rain]', () {
        expect(mapWmoCodeToTags(65), equals(['Rain']));
      });

      test('code 66 (freezing rain) → [Rain, Cold]', () {
        expect(mapWmoCodeToTags(66), equals(['Rain', 'Cold']));
      });

      test('code 67 (freezing rain heavy) → [Rain, Cold]', () {
        expect(mapWmoCodeToTags(67), equals(['Rain', 'Cold']));
      });
    });

    group('Snow (71–77)', () {
      test('code 71 → [Snow, Cold]', () {
        expect(mapWmoCodeToTags(71), equals(['Snow', 'Cold']));
      });

      test('code 73 → [Snow, Cold]', () {
        expect(mapWmoCodeToTags(73), equals(['Snow', 'Cold']));
      });

      test('code 75 → [Snow, Cold]', () {
        expect(mapWmoCodeToTags(75), equals(['Snow', 'Cold']));
      });

      test('code 77 (snow grains) → [Snow, Cold]', () {
        expect(mapWmoCodeToTags(77), equals(['Snow', 'Cold']));
      });
    });

    group('Rain showers (80–82)', () {
      test('code 80 → [Rain]', () {
        expect(mapWmoCodeToTags(80), equals(['Rain']));
      });

      test('code 81 → [Rain]', () {
        expect(mapWmoCodeToTags(81), equals(['Rain']));
      });

      test('code 82 → [Rain]', () {
        expect(mapWmoCodeToTags(82), equals(['Rain']));
      });
    });

    group('Snow showers (85–86)', () {
      test('code 85 → [Snow, Cold]', () {
        expect(mapWmoCodeToTags(85), equals(['Snow', 'Cold']));
      });

      test('code 86 → [Snow, Cold]', () {
        expect(mapWmoCodeToTags(86), equals(['Snow', 'Cold']));
      });
    });

    group('Thunderstorm (95–99)', () {
      test('code 95 → [Rain, Windy]', () {
        expect(mapWmoCodeToTags(95), equals(['Rain', 'Windy']));
      });

      test('code 96 (thunderstorm with hail) → [Rain, Windy]', () {
        expect(mapWmoCodeToTags(96), equals(['Rain', 'Windy']));
      });

      test('code 99 (thunderstorm heavy hail) → [Rain, Windy]', () {
        expect(mapWmoCodeToTags(99), equals(['Rain', 'Windy']));
      });
    });

    group('Unknown / future codes', () {
      test('unknown code 100 → [Cloudy] (fallback)', () {
        expect(mapWmoCodeToTags(100), equals(['Cloudy']));
      });

      test('unknown code -1 → [Cloudy] (fallback)', () {
        expect(mapWmoCodeToTags(-1), equals(['Cloudy']));
      });
    });

    group('Return value isolation', () {
      test('each call returns a new list instance (no shared state)', () {
        final first = mapWmoCodeToTags(0);
        final second = mapWmoCodeToTags(0);
        expect(identical(first, second), isFalse);
      });
    });
  });
}
