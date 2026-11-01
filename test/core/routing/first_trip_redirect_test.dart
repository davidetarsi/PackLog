import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/routing/app_router.dart';
import 'package:pack_log/features/tour/model/onboarding_state.dart';

void main() {
  const target = '/new-trip?ai=1&first=1';

  group('firstTripRedirect', () {
    test('firstTrip su / → "Dove vai?"', () {
      expect(
        firstTripRedirect(step: OnboardingStep.firstTrip, location: '/'),
        target,
      );
    });

    test('firstTrip da altre rotte della shell → "Dove vai?"', () {
      for (final location in ['/houses/h1', '/profile', '/settings']) {
        expect(
          firstTripRedirect(step: OnboardingStep.firstTrip, location: location),
          target,
          reason: location,
        );
      }
    });

    test('firstTrip su new-trip, trips e onboarding → nessun redirect', () {
      for (final location in [
        '/new-trip',
        '/trips',
        '/trips/x/edit-items',
        '/trips/x',
        '/onboarding',
        '/onboarding-ai-intro',
        '/login',
      ]) {
        expect(
          firstTripRedirect(step: OnboardingStep.firstTrip, location: location),
          isNull,
          reason: location,
        );
      }
    });

    test('con done nessun redirect', () {
      expect(
        firstTripRedirect(step: OnboardingStep.done, location: '/'),
        isNull,
      );
    });

    test(
      'con aiIntro (o senza stato) la strada di oggi: nessun redirect qui',
      () {
        expect(
          firstTripRedirect(step: OnboardingStep.aiIntro, location: '/'),
          isNull,
        );
        expect(firstTripRedirect(step: null, location: '/'), isNull);
      },
    );
  });
}
