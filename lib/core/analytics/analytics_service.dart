import 'package:amplitude_flutter/amplitude.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'analytics_service.g.dart';

class AppAnalyticsService {
  final Amplitude _amplitude;

  AppAnalyticsService(this._amplitude);

  void identifyUser(String userId) {
    try {
      _amplitude.setUserId(userId);
    } catch (e) {
      debugPrint('[Analytics] identifyUser failed: $e');
    }
  }

  void clearUser() {
    try {
      _amplitude.setUserId(null);
    } catch (e) {
      debugPrint('[Analytics] clearUser failed: $e');
    }
  }

  Future<void> logEvent(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    try {
      await _amplitude.logEvent(eventName, eventProperties: properties);
    } catch (e) {
      debugPrint('[Analytics] logEvent "$eventName" failed: $e');
    }
  }
}

@Riverpod(keepAlive: true)
AppAnalyticsService analyticsService(Ref ref) {
  return AppAnalyticsService(Amplitude.getInstance());
}
