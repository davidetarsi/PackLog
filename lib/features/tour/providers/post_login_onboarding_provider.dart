import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/onboarding_state.dart';
import '../repositories/shared_prefs_onboarding_repository.dart';

part 'post_login_onboarding_provider.g.dart';

@Riverpod(keepAlive: true)
class PostLoginOnboarding extends _$PostLoginOnboarding {
  @override
  Future<OnboardingState> build() async {
    final repo = ref.read(onboardingRepositoryProvider);
    final step = await repo.loadStep();
    final skippedAi = await repo.loadSkippedAi();
    final hasExistingHouses = await repo.loadHasExistingHouses();
    final defaultHouseId = await repo.loadDefaultHouseId();
    return OnboardingState(
      step: step,
      skippedAi: skippedAi,
      hasExistingHouses: hasExistingHouses,
      defaultHouseId: defaultHouseId,
    );
  }

  Future<void> completeAi(String defaultHouseId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final repo = ref.read(onboardingRepositoryProvider);
    if (current.hasExistingHouses) {
      await repo.saveStep(OnboardingStep.done);
      state = AsyncData(current.copyWith(step: OnboardingStep.done));
    } else {
      await repo.saveStep(OnboardingStep.houseTooltip);
      await repo.saveDefaultHouseId(defaultHouseId);
      state = AsyncData(current.copyWith(
        step: OnboardingStep.houseTooltip,
        defaultHouseId: defaultHouseId,
      ));
    }
  }

  Future<void> skipAi() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final repo = ref.read(onboardingRepositoryProvider);
    await repo.saveStep(OnboardingStep.houseTooltip);
    await repo.saveSkippedAi(true);
    state = AsyncData(current.copyWith(
      step: OnboardingStep.houseTooltip,
      skippedAi: true,
    ));
  }

  Future<void> advance() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = _nextStep(current);
    final repo = ref.read(onboardingRepositoryProvider);
    await repo.saveStep(next);
    state = AsyncData(current.copyWith(step: next));
  }

  Future<void> markDone() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final repo = ref.read(onboardingRepositoryProvider);
    await repo.saveStep(OnboardingStep.done);
    state = AsyncData(current.copyWith(step: OnboardingStep.done));
  }

  Future<void> reset({required bool hasExistingHouses}) async {
    final repo = ref.read(onboardingRepositoryProvider);
    await repo.saveStep(OnboardingStep.aiIntro);
    await repo.saveSkippedAi(false);
    await repo.saveHasExistingHouses(hasExistingHouses);
    await repo.saveDefaultHouseId(null);
    state = AsyncData(
      OnboardingState(hasExistingHouses: hasExistingHouses),
    );
  }

  static OnboardingStep _nextStep(OnboardingState s) {
    return switch (s.step) {
      OnboardingStep.houseTooltip => s.skippedAi
          ? OnboardingStep.createTripTooltip
          : OnboardingStep.defaultHouseTooltip,
      OnboardingStep.defaultHouseTooltip => OnboardingStep.moveItemsTooltip,
      OnboardingStep.moveItemsTooltip => OnboardingStep.createTripTooltip,
      OnboardingStep.createTripTooltip => OnboardingStep.tripCreationTooltip,
      OnboardingStep.tripCreationTooltip => OnboardingStep.done,
      _ => OnboardingStep.done,
    };
  }
}
