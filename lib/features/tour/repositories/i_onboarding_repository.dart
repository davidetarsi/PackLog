import '../providers/post_login_onboarding_provider.dart';

abstract class IOnboardingRepository {
  Future<OnboardingStep> loadStep();
  Future<void> saveStep(OnboardingStep step);
  Future<bool> loadSkippedAi();
  Future<void> saveSkippedAi(bool value);
  Future<bool> loadHasExistingHouses();
  Future<void> saveHasExistingHouses(bool value);
  Future<String?> loadDefaultHouseId();
  Future<void> saveDefaultHouseId(String? id);
}
