import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_service.dart';

class MockSyncService extends Mock implements SyncService {}

class MockConnectivity extends Mock implements Connectivity {}

class MockMonitoringService extends Mock implements AppMonitoringService {}

void main() {
  late MockSyncService mockService;
  late MockConnectivity mockConnectivity;
  late MockMonitoringService mockMonitoring;
  late StreamController<List<ConnectivityResult>> connectivityController;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockService = MockSyncService();
    mockConnectivity = MockConnectivity();
    mockMonitoring = MockMonitoringService();
    connectivityController =
        StreamController<List<ConnectivityResult>>.broadcast();

    when(() => mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityController.stream);
    when(() => mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => mockService.processQueue()).thenAnswer((_) async {});
    when(
      () => mockMonitoring.logBreadcrumb(
        any(),
        category: any(named: 'category'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
  });

  tearDown(() {
    connectivityController.close();
  });

  SyncOrchestrator makeOrchestrator() => SyncOrchestrator(
        mockService,
        mockMonitoring,
        connectivity: mockConnectivity,
      );

  group('SyncOrchestrator', () {
    test('triggers sync on connectivity change with network', () async {
      final orchestrator = makeOrchestrator();
      orchestrator.init();

      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      verify(() => mockService.processQueue()).called(1);

      orchestrator.dispose();
    });

    test('does not trigger sync when connectivity is none', () async {
      final orchestrator = makeOrchestrator();
      orchestrator.init();

      connectivityController.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockService.processQueue());

      orchestrator.dispose();
    });

    test('mutex prevents concurrent sync', () async {
      final completer = Completer<void>();
      var callCount = 0;

      when(() => mockService.processQueue()).thenAnswer((_) async {
        callCount++;
        await completer.future;
      });

      final orchestrator = makeOrchestrator();
      orchestrator.init();

      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      connectivityController.add([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);

      expect(callCount, equals(1));

      completer.complete();
      await Future<void>.delayed(Duration.zero);

      orchestrator.dispose();
    });

    test('mutex releases after processQueue completes', () async {
      final orchestrator = makeOrchestrator();
      orchestrator.init();

      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      verify(() => mockService.processQueue()).called(2);

      orchestrator.dispose();
    });

    test('mutex releases even if processQueue throws', () async {
      var calls = 0;
      when(() => mockService.processQueue()).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('sync failed');
      });

      final orchestrator = makeOrchestrator();
      orchestrator.init();

      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      verify(() => mockService.processQueue()).called(2);

      orchestrator.dispose();
    });

    test('logs breadcrumb with trigger on sync attempt', () async {
      final orchestrator = makeOrchestrator();
      orchestrator.init();

      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockMonitoring.logBreadcrumb(
          any(that: contains('connectivity_restored')),
          category: 'sync',
          data: any(named: 'data'),
        ),
      ).called(1);

      orchestrator.dispose();
    });
  });
}
