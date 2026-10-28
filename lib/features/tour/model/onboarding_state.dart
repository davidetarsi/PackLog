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

/// Passi del tour dopo il login.
///
/// Persistiti per **indice** (`SharedPrefsOnboardingRepository`): l'ordine
/// non si cambia e i valori non si tolgono, si aggiungono solo in fondo.
///
/// Il tour attuale è di tre tip: [houseDetailTooltip] → [createTripTooltip] →
/// [tripCreationTooltip]. [houseTooltip], [defaultHouseTooltip] e
/// [moveItemsTooltip] sono del tour precedente: restano solo per leggere lo
/// stato salvato da una build vecchia, che [OnboardingStepLegacy.current]
/// riporta sul tour attuale.
enum OnboardingStep {
  aiIntro,
  houseTooltip,
  defaultHouseTooltip,
  moveItemsTooltip,
  createTripTooltip,
  tripCreationTooltip,
  done,

  /// Dentro la casa creata dalla prova AI: "tocca il nome per darle nome e
  /// luogo".
  houseDetailTooltip,
}

extension OnboardingStepLegacy on OnboardingStep {
  /// Il passo del tour attuale da mostrare per uno stato salvato. I tip del
  /// tour precedente (crea una casa, apri la casa di prova, sposta gli
  /// oggetti) non esistono più: chi era lì riprende dal tip su Crea.
  OnboardingStep get current => switch (this) {
    OnboardingStep.houseTooltip ||
    OnboardingStep.defaultHouseTooltip ||
    OnboardingStep.moveItemsTooltip => OnboardingStep.createTripTooltip,
    _ => this,
  };
}

/// Quanti tip ha il tour: il totale del contatore "1 / 3" nelle schede.
const kTourLength = 3;

/// Numero d'ordine 1-based dei tip del tour guidato, per analytics e per il
/// contatore delle schede.
///
/// Chi salta l'AI intro chiude l'intero tour, quindi non vede nessun tip.
/// I numeri del tour precedente (1–5) non sono confrontabili con questi.
extension OnboardingStepTourIndex on OnboardingStep {
  int? get tourStepIndex => switch (this) {
    OnboardingStep.houseDetailTooltip => 1,
    OnboardingStep.createTripTooltip => 2,
    OnboardingStep.tripCreationTooltip => 3,
    OnboardingStep.aiIntro ||
    OnboardingStep.houseTooltip ||
    OnboardingStep.defaultHouseTooltip ||
    OnboardingStep.moveItemsTooltip ||
    OnboardingStep.done => null,
  };
}
