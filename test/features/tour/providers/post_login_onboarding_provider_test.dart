import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/features/tour/model/onboarding_state.dart';
import 'package:pack_log/features/tour/providers/post_login_onboarding_provider.dart';
import 'package:pack_log/features/tour/repositories/i_onboarding_repository.dart';
import 'package:pack_log/features/tour/repositories/shared_prefs_onboarding_repository.dart';

class MockOnboardingRepository extends Mock implements IOnboardingRepository {}

class MockAnalyticsService extends Mock implements AppAnalyticsService {}

MockAnalyticsService _makeAnalytics() {
  final a = MockAnalyticsService();
  when(
    () => a.logEvent(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  return a;
}

ProviderContainer makeContainer({
  IOnboardingRepository? repo,
  AppAnalyticsService? analytics,
}) {
  final r = repo ?? MockOnboardingRepository();
  return ProviderContainer(
    overrides: [
      onboardingRepositoryProvider.overrideWithValue(r),
      analyticsServiceProvider.overrideWithValue(analytics ?? _makeAnalytics()),
    ],
  );
}

void _setupDefaultMock(
  MockOnboardingRepository repo, {
  OnboardingStep step = OnboardingStep.aiIntro,
  bool skippedAi = false,
  bool hasExistingHouses = false,
  String? defaultHouseId,
}) {
  when(() => repo.loadStep()).thenAnswer((_) async => step);
  when(() => repo.loadSkippedAi()).thenAnswer((_) async => skippedAi);
  when(
    () => repo.loadHasExistingHouses(),
  ).thenAnswer((_) async => hasExistingHouses);
  when(() => repo.loadDefaultHouseId()).thenAnswer((_) async => defaultHouseId);
  when(() => repo.saveStep(any())).thenAnswer((_) async {});
  when(() => repo.saveSkippedAi(any())).thenAnswer((_) async {});
  when(() => repo.saveHasExistingHouses(any())).thenAnswer((_) async {});
  when(() => repo.saveDefaultHouseId(any())).thenAnswer((_) async {});
}

void main() {
  setUpAll(() {
    registerFallbackValue(OnboardingStep.aiIntro);
  });

  group('PostLoginOnboarding', () {
    test('build() loads state from repository', () async {
      final repo = MockOnboardingRepository();
      _setupDefaultMock(
        repo,
        step: OnboardingStep.houseTooltip,
        skippedAi: true,
        defaultHouseId: 'house-1',
      );
      final container = makeContainer(repo: repo);
      addTearDown(container.dispose);

      final result = await container.read(postLoginOnboardingProvider.future);
      expect(result.step, OnboardingStep.houseTooltip);
      expect(result.skippedAi, isTrue);
      expect(result.defaultHouseId, 'house-1');
    });

    // "Salta" sulla AI intro chiude l'INTERO tour, non solo la demo AI:
    // l'utente che preme Salta non vuole essere guidato oltre. Il flag
    // skippedAi resta salvato per distinguere questa uscita dal completamento
    // naturale (analytics) e per lo stato legacy — vedi il test su _nextStep.
    test('skipAi() ends the whole tour (step=done)', () async {
      final repo = MockOnboardingRepository();
      _setupDefaultMock(repo);
      final container = makeContainer(repo: repo);
      addTearDown(container.dispose);

      await container.read(postLoginOnboardingProvider.future);
      await container.read(postLoginOnboardingProvider.notifier).skipAi();

      final state = container.read(postLoginOnboardingProvider).valueOrNull!;
      expect(state.step, OnboardingStep.done);
      expect(state.skippedAi, isTrue);
      verify(() => repo.saveStep(OnboardingStep.done)).called(1);
      verify(() => repo.saveSkippedAi(true)).called(1);
    });

    test(
      'completeAi() advances to houseTooltip when hasExistingHouses=false',
      () async {
        final repo = MockOnboardingRepository();
        _setupDefaultMock(repo);
        final container = makeContainer(repo: repo);
        addTearDown(container.dispose);

        await container.read(postLoginOnboardingProvider.future);
        await container
            .read(postLoginOnboardingProvider.notifier)
            .completeAi('new-house-id');

        final state = container.read(postLoginOnboardingProvider).valueOrNull!;
        expect(state.step, OnboardingStep.houseTooltip);
        expect(state.defaultHouseId, 'new-house-id');
      },
    );

    test('completeAi() goes to done when hasExistingHouses=true', () async {
      final repo = MockOnboardingRepository();
      _setupDefaultMock(repo, hasExistingHouses: true);
      final container = makeContainer(repo: repo);
      addTearDown(container.dispose);

      await container.read(postLoginOnboardingProvider.future);
      await container
          .read(postLoginOnboardingProvider.notifier)
          .completeAi('any-house');

      final state = container.read(postLoginOnboardingProvider).valueOrNull!;
      expect(state.step, OnboardingStep.done);
    });

    test(
      'advance() skippedAi=false: houseTooltip -> defaultHouseTooltip',
      () async {
        final repo = MockOnboardingRepository();
        _setupDefaultMock(repo, step: OnboardingStep.houseTooltip);
        final container = makeContainer(repo: repo);
        addTearDown(container.dispose);

        await container.read(postLoginOnboardingProvider.future);
        await container.read(postLoginOnboardingProvider.notifier).advance();

        expect(
          container.read(postLoginOnboardingProvider).valueOrNull?.step,
          OnboardingStep.defaultHouseTooltip,
        );
      },
    );

    test(
      'advance() skippedAi=true: houseTooltip -> createTripTooltip',
      () async {
        final repo = MockOnboardingRepository();
        _setupDefaultMock(
          repo,
          step: OnboardingStep.houseTooltip,
          skippedAi: true,
        );
        final container = makeContainer(repo: repo);
        addTearDown(container.dispose);

        await container.read(postLoginOnboardingProvider.future);
        await container.read(postLoginOnboardingProvider.notifier).advance();

        expect(
          container.read(postLoginOnboardingProvider).valueOrNull?.step,
          OnboardingStep.createTripTooltip,
        );
      },
    );

    test(
      'advance() full chain without skip: houseTooltip -> done (5 advances)',
      () async {
        final repo = MockOnboardingRepository();
        _setupDefaultMock(repo, step: OnboardingStep.houseTooltip);
        final container = makeContainer(repo: repo);
        addTearDown(container.dispose);

        await container.read(postLoginOnboardingProvider.future);
        final notifier = container.read(postLoginOnboardingProvider.notifier);

        for (var i = 0; i < 5; i++) {
          await notifier.advance();
        }

        expect(
          container.read(postLoginOnboardingProvider).valueOrNull?.step,
          OnboardingStep.done,
        );
      },
    );

    group('tour_completed', () {
      test('emitted once when advance() reaches done, with context', () async {
        final repo = MockOnboardingRepository();
        _setupDefaultMock(repo, step: OnboardingStep.tripCreationTooltip);
        final analytics = _makeAnalytics();
        final container = makeContainer(repo: repo, analytics: analytics);
        addTearDown(container.dispose);

        await container.read(postLoginOnboardingProvider.future);
        await container.read(postLoginOnboardingProvider.notifier).advance();

        verify(
          () => analytics.logEvent(
            'tour_completed',
            properties: {'skipped_ai': false, 'last_step_index': 5},
          ),
        ).called(1);
      });

      test('not emitted on the intermediate steps of the tour', () async {
        final repo = MockOnboardingRepository();
        _setupDefaultMock(repo, step: OnboardingStep.houseTooltip);
        final analytics = _makeAnalytics();
        final container = makeContainer(repo: repo, analytics: analytics);
        addTearDown(container.dispose);

        await container.read(postLoginOnboardingProvider.future);
        await container.read(postLoginOnboardingProvider.notifier).advance();

        verifyNever(
          () => analytics.logEvent(
            'tour_completed',
            properties: any(named: 'properties'),
          ),
        );
      });

      // Le due strade verso `done` che NON sono completamenti hanno già il
      // proprio evento di abbandono: contarle qui renderebbe il funnel cieco
      // alla differenza fra chi finisce e chi molla.
      test('not emitted by markDone() (abbandono da un tip)', () async {
        final repo = MockOnboardingRepository();
        _setupDefaultMock(repo, step: OnboardingStep.moveItemsTooltip);
        final analytics = _makeAnalytics();
        final container = makeContainer(repo: repo, analytics: analytics);
        addTearDown(container.dispose);

        await container.read(postLoginOnboardingProvider.future);
        await container.read(postLoginOnboardingProvider.notifier).markDone();

        verifyNever(
          () => analytics.logEvent(
            'tour_completed',
            properties: any(named: 'properties'),
          ),
        );
      });

      test('not emitted by skipAi()', () async {
        final repo = MockOnboardingRepository();
        _setupDefaultMock(repo, step: OnboardingStep.aiIntro);
        final analytics = _makeAnalytics();
        final container = makeContainer(repo: repo, analytics: analytics);
        addTearDown(container.dispose);

        await container.read(postLoginOnboardingProvider.future);
        await container.read(postLoginOnboardingProvider.notifier).skipAi();

        verifyNever(
          () => analytics.logEvent(
            'tour_completed',
            properties: any(named: 'properties'),
          ),
        );
      });
    });

    test('markDone() sets step to done regardless of current step', () async {
      final repo = MockOnboardingRepository();
      _setupDefaultMock(repo, step: OnboardingStep.createTripTooltip);
      final container = makeContainer(repo: repo);
      addTearDown(container.dispose);

      await container.read(postLoginOnboardingProvider.future);
      await container.read(postLoginOnboardingProvider.notifier).markDone();

      expect(
        container.read(postLoginOnboardingProvider).valueOrNull?.step,
        OnboardingStep.done,
      );
    });

    test(
      'reset(hasExistingHouses: false) returns to aiIntro with skippedAi=false',
      () async {
        final repo = MockOnboardingRepository();
        _setupDefaultMock(repo, step: OnboardingStep.done);
        final container = makeContainer(repo: repo);
        addTearDown(container.dispose);

        await container.read(postLoginOnboardingProvider.future);
        await container
            .read(postLoginOnboardingProvider.notifier)
            .reset(hasExistingHouses: false);

        final state = container.read(postLoginOnboardingProvider).valueOrNull!;
        expect(state.step, OnboardingStep.aiIntro);
        expect(state.skippedAi, isFalse);
        expect(state.hasExistingHouses, isFalse);
        expect(state.defaultHouseId, isNull);
      },
    );

    test(
      'reset(hasExistingHouses: true) sets hasExistingHouses=true',
      () async {
        final repo = MockOnboardingRepository();
        _setupDefaultMock(repo, step: OnboardingStep.done);
        final container = makeContainer(repo: repo);
        addTearDown(container.dispose);

        await container.read(postLoginOnboardingProvider.future);
        await container
            .read(postLoginOnboardingProvider.notifier)
            .reset(hasExistingHouses: true);

        final state = container.read(postLoginOnboardingProvider).valueOrNull!;
        expect(state.step, OnboardingStep.aiIntro);
        expect(state.hasExistingHouses, isTrue);
      },
    );
  });
}
