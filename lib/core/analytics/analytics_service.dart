import 'package:amplitude_flutter/amplitude.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/config/app_config.dart';

part 'analytics_service.g.dart';

class AppAnalyticsService {
  final Amplitude? _amplitude;

  AppAnalyticsService(this._amplitude);

  void identifyUser(String userId) {
    final amp = _amplitude;
    if (amp == null) return;
    try {
      amp.setUserId(userId);
    } catch (e) {
      debugPrint('[Analytics] identifyUser failed: $e');
    }
  }

  void clearUser() {
    final amp = _amplitude;
    if (amp == null) return;
    try {
      amp.setUserId(null);
    } catch (e) {
      debugPrint('[Analytics] clearUser failed: $e');
    }
  }

  Future<void> logEvent(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    final amp = _amplitude;
    if (amp == null) return;
    try {
      await amp.logEvent(eventName, eventProperties: properties);
    } catch (e) {
      debugPrint('[Analytics] logEvent "$eventName" failed: $e');
    }
  }
}

@Riverpod(keepAlive: true)
AppAnalyticsService analyticsService(Ref ref) {
  if (AppConfig.amplitudeApiKey == 'MISSING_AMPLITUDE_API_KEY') {
    return AppAnalyticsService(null);
  }
  return AppAnalyticsService(Amplitude.getInstance());
}
