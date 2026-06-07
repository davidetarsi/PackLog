import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/onboarding_state.dart';
import 'i_onboarding_repository.dart';

part 'shared_prefs_onboarding_repository.g.dart';

@Riverpod(keepAlive: true)
IOnboardingRepository onboardingRepository(Ref ref) {
  return SharedPrefsOnboardingRepository();
}

class SharedPrefsOnboardingRepository implements IOnboardingRepository {
  static const _stepKey = 'onboarding_step_v2';
  static const _skippedAiKey = 'onboarding_skipped_ai';
  static const _hasExistingHousesKey = 'onboarding_has_existing_houses';
  static const _defaultHouseIdKey = 'onboarding_default_house_id';

  @override
  Future<OnboardingStep> loadStep() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_stepKey) ?? 0;
    return OnboardingStep
        .values[index.clamp(0, OnboardingStep.values.length - 1)];
  }

  @override
  Future<void> saveStep(OnboardingStep step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepKey, step.index);
  }

  @override
  Future<bool> loadSkippedAi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_skippedAiKey) ?? false;
  }

  @override
  Future<void> saveSkippedAi(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skippedAiKey, value);
  }

  @override
  Future<bool> loadHasExistingHouses() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasExistingHousesKey) ?? false;
  }

  @override
  Future<void> saveHasExistingHouses(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasExistingHousesKey, value);
  }

  @override
  Future<String?> loadDefaultHouseId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultHouseIdKey);
  }

  @override
  Future<void> saveDefaultHouseId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_defaultHouseIdKey);
    } else {
      await prefs.setString(_defaultHouseIdKey, id);
    }
  }
}
