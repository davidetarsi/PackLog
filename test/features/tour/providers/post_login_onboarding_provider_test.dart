import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/tour/model/onboarding_state.dart';
import 'package:pack_log/features/tour/providers/post_login_onboarding_provider.dart';
import 'package:pack_log/features/tour/repositories/i_onboarding_repository.dart';
import 'package:pack_log/features/tour/repositories/shared_prefs_onboarding_repository.dart';

class MockOnboardingRepository extends Mock implements IOnboardingRepository {}

ProviderContainer makeContainer({IOnboardingRepository? repo}) {
  final r = repo ?? MockOnboardingRepository();
  return ProviderContainer(
    overrides: [
      onboardingRepositoryProvider.overrideWithValue(r),
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
  when(() => repo.loadHasExistingHouses()).thenAnswer((_) async => hasExistingHouses);
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
      _setupDefaultMock(repo,
          step: OnboardingStep.houseTooltip,
          skippedAi: true,
          defaultHouseId: 'house-1');
      final container = makeContainer(repo: repo);
      addTearDown(container.dispose);

      final result = await container.read(postLoginOnboardingProvider.future);
      expect(result.step, OnboardingStep.houseTooltip);
      expect(result.skippedAi, isTrue);
      expect(result.defaultHouseId, 'house-1');
    });

    test('skipAi() advances to houseTooltip with skippedAi=true', () async {
      final repo = MockOnboardingRepository();
      _setupDefaultMock(repo);
      final container = makeContainer(repo: repo);
      addTearDown(container.dispose);

      await container.read(postLoginOnboardingProvider.future);
      await container.read(postLoginOnboardingProvider.notifier).skipAi();

      final state = container.read(postLoginOnboardingProvider).valueOrNull!;
      expect(state.step, OnboardingStep.houseTooltip);
      expect(state.skippedAi, isTrue);
      verify(() => repo.saveStep(OnboardingStep.houseTooltip)).called(1);
      verify(() => repo.saveSkippedAi(true)).called(1);
    });

    test('completeAi() advances to houseTooltip when hasExistingHouses=false', () async {
      final repo = MockOnboardingRepository();
      _setupDefaultMock(repo);
      final container = makeContainer(repo: repo);
      addTearDown(container.dispose);

      await container.read(postLoginOnboardingProvider.future);
      await container.read(postLoginOnboardingProvider.notifier).completeAi('new-house-id');

      final state = container.read(postLoginOnboardingProvider).valueOrNull!;
      expect(state.step, OnboardingStep.houseTooltip);
      expect(state.defaultHouseId, 'new-house-id');
    });

    test('completeAi() goes to done when hasExistingHouses=true', () async {
      final repo = MockOnboardingRepository();
      _setupDefaultMock(repo, hasExistingHouses: true);
      final container = makeContainer(repo: repo);
      addTearDown(container.dispose);

      await container.read(postLoginOnboardingProvider.future);
      await container.read(postLoginOnboardingProvider.notifier).completeAi('any-house');

      final state = container.read(postLoginOnboardingProvider).valueOrNull!;
      expect(state.step, OnboardingStep.done);
    });

    test('advance() skippedAi=false: houseTooltip -> defaultHouseTooltip', () async {
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
    });

    test('advance() skippedAi=true: houseTooltip -> createTripTooltip', () async {
      final repo = MockOnboardingRepository();
      _setupDefaultMock(repo, step: OnboardingStep.houseTooltip, skippedAi: true);
      final container = makeContainer(repo: repo);
      addTearDown(container.dispose);

      await container.read(postLoginOnboardingProvider.future);
      await container.read(postLoginOnboardingProvider.notifier).advance();

      expect(
        container.read(postLoginOnboardingProvider).valueOrNull?.step,
        OnboardingStep.createTripTooltip,
      );
    });

    test('advance() full chain without skip: houseTooltip -> done (5 advances)', () async {
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

    test('reset(hasExistingHouses: false) returns to aiIntro with skippedAi=false', () async {
      final repo = MockOnboardingRepository();
      _setupDefaultMock(repo, step: OnboardingStep.done);
      final container = makeContainer(repo: repo);
      addTearDown(container.dispose);

      await container.read(postLoginOnboardingProvider.future);
      await container.read(postLoginOnboardingProvider.notifier).reset(hasExistingHouses: false);

      final state = container.read(postLoginOnboardingProvider).valueOrNull!;
      expect(state.step, OnboardingStep.aiIntro);
      expect(state.skippedAi, isFalse);
      expect(state.hasExistingHouses, isFalse);
      expect(state.defaultHouseId, isNull);
    });

    test('reset(hasExistingHouses: true) sets hasExistingHouses=true', () async {
      final repo = MockOnboardingRepository();
      _setupDefaultMock(repo, step: OnboardingStep.done);
      final container = makeContainer(repo: repo);
      addTearDown(container.dispose);

      await container.read(postLoginOnboardingProvider.future);
      await container.read(postLoginOnboardingProvider.notifier).reset(hasExistingHouses: true);

      final state = container.read(postLoginOnboardingProvider).valueOrNull!;
      expect(state.step, OnboardingStep.aiIntro);
      expect(state.hasExistingHouses, isTrue);
    });
  });
}
