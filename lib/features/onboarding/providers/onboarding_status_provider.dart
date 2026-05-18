import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_status_provider.g.dart';

const String _onboardingCompletedKey = 'onboarding_completed';

/// Tracks whether the user has completed the onboarding flow.
@Riverpod(keepAlive: true)
class OnboardingStatus extends _$OnboardingStatus {
  @override
  Future<bool> build() => _loadStatus();

  Future<bool> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingCompletedKey) ?? false;
    } catch (e) {
      debugPrint('[OnboardingStatus] Error loading status: $e');
      return false;
    }
  }

  /// Persists the onboarding completion flag and updates provider state.
  Future<void> markCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
      state = const AsyncData(true);
    } catch (e) {
      debugPrint('[OnboardingStatus] Error marking completed: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
