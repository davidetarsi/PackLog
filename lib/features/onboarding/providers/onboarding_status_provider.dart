import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_status_provider.g.dart';

const String _onboardingCompletedKey = 'onboarding_completed';

@Riverpod(keepAlive: true)
class OnboardingStatus extends _$OnboardingStatus {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    state = const AsyncData(true);
  }
}
