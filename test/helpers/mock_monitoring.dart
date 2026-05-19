import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';

class MockMonitoringService extends Mock implements AppMonitoringService {}

List<Override> mockMonitoringOverrides() {
  final mock = MockMonitoringService();
  when(() => mock.identifyUser(any())).thenReturn(null);
  when(() => mock.clearUser()).thenReturn(null);
  return [monitoringServiceProvider.overrideWithValue(mock)];
}
