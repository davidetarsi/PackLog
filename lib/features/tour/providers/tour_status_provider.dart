import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'tour_status_provider.g.dart';

const String _tourCompletedKey = 'tour_completed';

@Riverpod(keepAlive: true)
class TourStatus extends _$TourStatus {
  @override
  Future<bool> build() => _loadStatus();

  Future<bool> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_tourCompletedKey) ?? false;
    } catch (e) {
      debugPrint('[TourStatus] Error loading status: $e');
      return false;
    }
  }

  Future<void> markCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tourCompletedKey, true);
      state = const AsyncData(true);
    } catch (e) {
      debugPrint('[TourStatus] Error marking completed: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> resetTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tourCompletedKey);
      state = const AsyncData(false);
    } catch (e) {
      debugPrint('[TourStatus] Error resetting tour: $e');
    }
  }
}
