import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/domain/packing_blueprint_engine.dart';

void main() {
  group('PackingBlueprintEngine - calculateBaseQuotas', () {
    group('underwear_and_socks = days + 1', () {
      test('1 day trip → 2', () {
        final q = PackingBlueprintEngine(tripDurationDays: 1).calculateBaseQuotas();
        expect(q['underwear_and_socks'], equals(2));
      });

      test('7 day trip → 8', () {
        final q = PackingBlueprintEngine(tripDurationDays: 7).calculateBaseQuotas();
        expect(q['underwear_and_socks'], equals(8));
      });

      test('0 day trip → 1', () {
        final q = PackingBlueprintEngine(tripDurationDays: 0).calculateBaseQuotas();
        expect(q['underwear_and_socks'], equals(1));
      });
    });

    group('tops = (days / 1.5).ceil()', () {
      test('3 days → ceil(2.0) = 2', () {
        final q = PackingBlueprintEngine(tripDurationDays: 3).calculateBaseQuotas();
        expect(q['tops'], equals(2));
      });

      test('4 days → ceil(2.67) = 3', () {
        final q = PackingBlueprintEngine(tripDurationDays: 4).calculateBaseQuotas();
        expect(q['tops'], equals(3));
      });

      test('7 days → ceil(4.67) = 5', () {
        final q = PackingBlueprintEngine(tripDurationDays: 7).calculateBaseQuotas();
        expect(q['tops'], equals(5));
      });
    });

    group('bottoms = (days / 2.5).ceil()', () {
      test('2 days → ceil(0.8) = 1', () {
        final q = PackingBlueprintEngine(tripDurationDays: 2).calculateBaseQuotas();
        expect(q['bottoms'], equals(1));
      });

      test('5 days → ceil(2.0) = 2', () {
        final q = PackingBlueprintEngine(tripDurationDays: 5).calculateBaseQuotas();
        expect(q['bottoms'], equals(2));
      });

      test('7 days → ceil(2.8) = 3', () {
        final q = PackingBlueprintEngine(tripDurationDays: 7).calculateBaseQuotas();
        expect(q['bottoms'], equals(3));
      });
    });

    group('outerwear: 1 if < 4 days, else 2', () {
      test('3 days → 1', () {
        final q = PackingBlueprintEngine(tripDurationDays: 3).calculateBaseQuotas();
        expect(q['outerwear'], equals(1));
      });

      test('4 days → 2 (threshold)', () {
        final q = PackingBlueprintEngine(tripDurationDays: 4).calculateBaseQuotas();
        expect(q['outerwear'], equals(2));
      });

      test('10 days → 2', () {
        final q = PackingBlueprintEngine(tripDurationDays: 10).calculateBaseQuotas();
        expect(q['outerwear'], equals(2));
      });
    });

    group('shoes: 1 if < 4 days, else 2', () {
      test('1 day → 1', () {
        final q = PackingBlueprintEngine(tripDurationDays: 1).calculateBaseQuotas();
        expect(q['shoes'], equals(1));
      });

      test('4 days → 2', () {
        final q = PackingBlueprintEngine(tripDurationDays: 4).calculateBaseQuotas();
        expect(q['shoes'], equals(2));
      });
    });

    group('totalItemCount', () {
      test('sums all quota values', () {
        final engine = PackingBlueprintEngine(tripDurationDays: 3);
        final quotas = engine.calculateBaseQuotas();
        final expected = quotas.values.fold(0, (s, v) => s + v);
        expect(engine.totalItemCount, equals(expected));
      });

      test('3-day trip totalItemCount matches manual sum', () {
        // days=3: underwear=4, tops=2, bottoms=2, outerwear=1, shoes=1 → 10
        final engine = PackingBlueprintEngine(tripDurationDays: 3);
        expect(engine.totalItemCount, equals(10));
      });
    });

    group('keys are always present', () {
      test('all 5 keys are returned for any duration', () {
        final q = PackingBlueprintEngine(tripDurationDays: 5).calculateBaseQuotas();
        expect(q.keys, containsAll([
          'underwear_and_socks',
          'tops',
          'bottoms',
          'outerwear',
          'shoes',
        ]));
      });
    });
  });
}
