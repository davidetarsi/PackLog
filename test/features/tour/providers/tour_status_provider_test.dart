import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/tour/providers/tour_status_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TourStatus', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('build() returns false when tour_completed not set', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(tourStatusProvider.future);
      expect(result, isFalse);
    });

    test('build() returns true when tour_completed is true', () async {
      SharedPreferences.setMockInitialValues({'tour_completed': true});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(tourStatusProvider.future);
      expect(result, isTrue);
    });

    test('markCompleted() sets state to AsyncData(true)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tourStatusProvider.future);
      expect(container.read(tourStatusProvider).valueOrNull, isFalse);

      await container.read(tourStatusProvider.notifier).markCompleted();
      expect(container.read(tourStatusProvider).valueOrNull, isTrue);
    });

    test('markCompleted() persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tourStatusProvider.future);
      await container.read(tourStatusProvider.notifier).markCompleted();

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      final result = await container2.read(tourStatusProvider.future);
      expect(result, isTrue);
    });

    test('resetTour() sets state to AsyncData(false)', () async {
      SharedPreferences.setMockInitialValues({'tour_completed': true});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tourStatusProvider.future);
      await container.read(tourStatusProvider.notifier).resetTour();

      expect(container.read(tourStatusProvider).valueOrNull, isFalse);
    });

    test('resetTour() removes key from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'tour_completed': true});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tourStatusProvider.future);
      await container.read(tourStatusProvider.notifier).resetTour();

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      final result = await container2.read(tourStatusProvider.future);
      expect(result, isFalse);
    });
  });
}
