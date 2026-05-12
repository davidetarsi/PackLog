import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';

class MockAnalyticsService extends Mock implements AppAnalyticsService {}

List<Override> mockAnalyticsOverrides() {
  final mock = MockAnalyticsService();
  when(() => mock.identifyUser(any())).thenReturn(null);
  when(() => mock.clearUser()).thenReturn(null);
  return [analyticsServiceProvider.overrideWithValue(mock)];
}
