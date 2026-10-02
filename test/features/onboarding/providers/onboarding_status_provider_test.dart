import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/onboarding/providers/onboarding_status_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OnboardingStatus', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('build() returns false when onboarding_completed not set', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(onboardingStatusProvider.future);
      expect(result, isFalse);
    });

    test('build() returns true when onboarding_completed is true', () async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(onboardingStatusProvider.future);
      expect(result, isTrue);
    });

    test('markCompleted() sets state to AsyncData(true)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Carica stato iniziale
      await container.read(onboardingStatusProvider.future);
      expect(container.read(onboardingStatusProvider).valueOrNull, isFalse);

      // Completa onboarding
      await container.read(onboardingStatusProvider.notifier).markCompleted();

      expect(container.read(onboardingStatusProvider).valueOrNull, isTrue);
    });

    test('markCompleted() persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(onboardingStatusProvider.future);
      await container.read(onboardingStatusProvider.notifier).markCompleted();

      // Nuovo container simula riavvio app
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      final result = await container2.read(onboardingStatusProvider.future);
      expect(result, isTrue);
    });
  });
}
