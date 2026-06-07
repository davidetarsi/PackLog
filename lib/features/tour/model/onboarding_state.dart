/// Onboarding state model — kept in its own file so both the repository
/// interface and the provider can import it without circular dependencies.
class OnboardingState {
  final OnboardingStep step;
  final bool skippedAi;
  final bool hasExistingHouses;
  final String? defaultHouseId;

  const OnboardingState({
    this.step = OnboardingStep.aiIntro,
    this.skippedAi = false,
    this.hasExistingHouses = false,
    this.defaultHouseId,
  });

  OnboardingState copyWith({
    OnboardingStep? step,
    bool? skippedAi,
    bool? hasExistingHouses,
    String? defaultHouseId,
    bool clearDefaultHouseId = false,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      skippedAi: skippedAi ?? this.skippedAi,
      hasExistingHouses: hasExistingHouses ?? this.hasExistingHouses,
      defaultHouseId:
          clearDefaultHouseId ? null : (defaultHouseId ?? this.defaultHouseId),
    );
  }
}

enum OnboardingStep {
  aiIntro,
  houseTooltip,
  defaultHouseTooltip,
  moveItemsTooltip,
  createTripTooltip,
  tripCreationTooltip,
  done,
}
