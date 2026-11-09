import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/analytics/core_analytics_service.dart';
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
      step: step.current,
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
      // Il router porta dentro la casa appena creata, dove scatta il primo
      // tip: darle un nome e un luogo veri.
      await repo.saveStep(OnboardingStep.houseDetailTooltip);
      await repo.saveDefaultHouseId(defaultHouseId);
      state = AsyncData(
        current.copyWith(
          step: OnboardingStep.houseDetailTooltip,
          defaultHouseId: defaultHouseId,
        ),
      );
    }
  }

  /// Chiude il passo "Dove vai?": la X, il salvataggio del passo 1 o la prima
  /// valigia generata. Agisce solo dal passo `firstTrip`: da `done` e da
  /// qualunque passo del tour (chi sta rifacendo il tour, un tip di casa o
  /// viaggio) non scrive nulla e il tour continua.
  Future<void> completeFirstTrip() async {
    final current = await future;
    if (current.step != OnboardingStep.firstTrip) return;
    final repo = ref.read(onboardingRepositoryProvider);
    await repo.saveStep(OnboardingStep.done);
    state = AsyncData(current.copyWith(step: OnboardingStep.done));
  }

  /// "Salta" sulla AI intro chiude l'INTERO tour, non solo la demo AI.
  ///
  /// Chi preme Salta sta dicendo "non voglio essere guidato", non "saltiamo
  /// solo questa prova": proseguire con i tip su casa e viaggio veniva
  /// percepito come un tour che non si lascia chiudere. Resta comunque
  /// disponibile "Ripeti il tour" dal Profilo.
  ///
  /// `skippedAi` continua a essere persistito per distinguere questa uscita
  /// dal completamento naturale (analytics).
  Future<void> skipAi() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final repo = ref.read(onboardingRepositoryProvider);
    await repo.saveStep(OnboardingStep.done);
    await repo.saveSkippedAi(true);
    state = AsyncData(
      current.copyWith(step: OnboardingStep.done, skippedAi: true),
    );
  }

  Future<void> advance() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = _nextStep(current);
    final repo = ref.read(onboardingRepositoryProvider);
    await repo.saveStep(next);
    state = AsyncData(current.copyWith(step: next));

    // Evento terminale del funnel del tour. Sta qui e non in [markDone] perché
    // solo `advance()` rappresenta un completamento *naturale*: le altre due
    // strade verso `done` sono abbandoni, e hanno già il proprio evento
    // (`ai_onboarding_skipped` da [skipAi], `onboarding_closed` dal tip che ha
    // chiamato [markDone]). Emetterlo anche lì renderebbe indistinguibile chi
    // ha finito il tour da chi lo ha chiuso al primo tip.
    if (next == OnboardingStep.done) {
      ref
          .read(coreAnalyticsServiceProvider)
          .trackTourCompleted(
            skippedAi: current.skippedAi,
            lastStepIndex: current.step.tourStepIndex,
          );
    }
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
    state = AsyncData(OnboardingState(hasExistingHouses: hasExistingHouses));
  }

  static OnboardingStep _nextStep(OnboardingState s) {
    return switch (s.step.current) {
      OnboardingStep.houseDetailTooltip => OnboardingStep.createTripTooltip,
      OnboardingStep.createTripTooltip => OnboardingStep.tripCreationTooltip,
      _ => OnboardingStep.done,
    };
  }
}
