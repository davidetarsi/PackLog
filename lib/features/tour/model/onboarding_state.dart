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
      defaultHouseId: clearDefaultHouseId
          ? null
          : (defaultHouseId ?? this.defaultHouseId),
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

/// Numero d'ordine 1-based dei tip del tour guidato, per analytics.
///
/// Permette di segmentare/ordinare il funnel per numero di step invece che
/// per nome. Chi salta l'AI intro non vede mai gli step 2 e 3 (vedi
/// `_nextStep` in `post_login_onboarding_provider.dart`): i numeri restano
/// comunque corretti, è solo che quella distribuzione risulterà vuota per
/// quegli utenti — un dato legittimo, non un buco nella numerazione.
extension OnboardingStepTourIndex on OnboardingStep {
  int? get tourStepIndex => switch (this) {
    OnboardingStep.houseTooltip => 1,
    OnboardingStep.defaultHouseTooltip => 2,
    OnboardingStep.moveItemsTooltip => 3,
    OnboardingStep.createTripTooltip => 4,
    OnboardingStep.tripCreationTooltip => 5,
    OnboardingStep.aiIntro || OnboardingStep.done => null,
  };
}
