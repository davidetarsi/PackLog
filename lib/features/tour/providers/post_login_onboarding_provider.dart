import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'post_login_onboarding_provider.g.dart';

enum OnboardingStep {
  aiIntro,
  houseTooltip,
  defaultHouseTooltip,
  moveItemsTooltip,
  createTripTooltip,
  tripCreationTooltip,
  done,
}

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

@Riverpod(keepAlive: true)
class PostLoginOnboarding extends _$PostLoginOnboarding {
  @override
  Future<OnboardingState> build() async => const OnboardingState();
}
