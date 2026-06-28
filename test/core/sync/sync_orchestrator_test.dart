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

    when(
      () => mockConnectivity.onConnectivityChanged,
    ).thenAnswer((_) => connectivityController.stream);
    when(
      () => mockConnectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => mockService.processQueue()).thenAnswer((_) async {});
    when(() => mockService.resetAllSyncRetries()).thenAnswer((_) async => 0);
    when(() => mockService.countPendingChanges()).thenAnswer((_) async => 0);
    when(() => mockService.fullPull(any())).thenAnswer((_) async {});
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

    test(
      'fires onProcessQueueComplete after successful processQueue',
      () async {
        var callbackCalls = 0;
        final orchestrator = makeOrchestrator()
          ..onProcessQueueComplete = () => callbackCalls++;
        orchestrator.init();

        connectivityController.add([ConnectivityResult.wifi]);
        await Future<void>.delayed(Duration.zero);

        expect(callbackCalls, 1);
        verify(() => mockService.processQueue()).called(1);

        orchestrator.dispose();
      },
    );

    test('fires onProcessQueueComplete even if processQueue throws', () async {
      when(() => mockService.processQueue()).thenAnswer((_) async {
        throw Exception('sync failed');
      });
      when(
        () => mockMonitoring.captureException(
          any(),
          stackTrace: any(named: 'stackTrace'),
          tags: any(named: 'tags'),
        ),
      ).thenReturn(null);

      var callbackCalls = 0;
      final orchestrator = makeOrchestrator()
        ..onProcessQueueComplete = () => callbackCalls++;
      orchestrator.init();

      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      // Callback must fire so the UI counter refreshes and reflects pending
      // changes that remain after a failed push attempt.
      expect(callbackCalls, 1);

      orchestrator.dispose();
    });

    test('fires onSyncStarted before processQueue on requestSync', () async {
      final order = <String>[];

      when(() => mockService.processQueue()).thenAnswer((_) async {
        order.add('processing');
      });

      final orchestrator = makeOrchestrator();
      orchestrator.onSyncStarted = () => order.add('started');
      orchestrator.onProcessQueueComplete = () => order.add('complete');
      orchestrator.init();

      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      expect(order, ['started', 'processing', 'complete']);

      orchestrator.dispose();
    });

    test('does NOT fire onSyncStarted when mutex skips the sync', () async {
      final completer = Completer<void>();
      when(() => mockService.processQueue()).thenAnswer((_) async {
        await completer.future;
      });

      var startedCalls = 0;
      final orchestrator = makeOrchestrator();
      orchestrator.onSyncStarted = () => startedCalls++;
      orchestrator.init();

      // First sync: starts (mutex acquired).
      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(startedCalls, 1);

      // Second event while still syncing: skipped by mutex.
      connectivityController.add([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);
      expect(
        startedCalls,
        1,
        reason: 'skipped sync must not fire onSyncStarted',
      );

      completer.complete();
      await Future<void>.delayed(Duration.zero);

      orchestrator.dispose();
    });

    test('fullPull auto-flushes pending records when count > 0', () async {
      when(() => mockService.countPendingChanges()).thenAnswer((_) async => 3);

      var pushCalls = 0;
      when(() => mockService.processQueue()).thenAnswer((_) async {
        pushCalls++;
      });

      var pushCompleteCalls = 0;
      final orchestrator = makeOrchestrator()
        ..onProcessQueueComplete = () => pushCompleteCalls++;
      orchestrator.init();

      orchestrator.requestFullPull('user-123');
      await Future<void>.delayed(Duration.zero);

      verify(() => mockService.fullPull('user-123')).called(1);
      verify(() => mockService.countPendingChanges()).called(1);
      expect(pushCalls, 1, reason: 'processQueue must run after fullPull');
      expect(
        pushCompleteCalls,
        1,
        reason: 'onProcessQueueComplete must fire so the UI counter refreshes',
      );

      orchestrator.dispose();
    });

    test(
      'fullPull does NOT auto-flush when there are no pending records',
      () async {
        when(
          () => mockService.countPendingChanges(),
        ).thenAnswer((_) async => 0);

        var pushCalls = 0;
        when(() => mockService.processQueue()).thenAnswer((_) async {
          pushCalls++;
        });

        var pushCompleteCalls = 0;
        final orchestrator = makeOrchestrator()
          ..onProcessQueueComplete = () => pushCompleteCalls++;
        orchestrator.init();

        orchestrator.requestFullPull('user-123');
        await Future<void>.delayed(Duration.zero);

        verify(() => mockService.fullPull('user-123')).called(1);
        verify(() => mockService.countPendingChanges()).called(1);
        expect(pushCalls, 0, reason: 'no pending → no processQueue');
        expect(
          pushCompleteCalls,
          0,
          reason:
              'no push attempt → no onProcessQueueComplete fire (counter was already accurate)',
        );

        orchestrator.dispose();
      },
    );

    test(
      'auto-flush still releases mutex even if processQueue throws',
      () async {
        when(
          () => mockService.countPendingChanges(),
        ).thenAnswer((_) async => 1);
        when(() => mockService.processQueue()).thenAnswer((_) async {
          throw Exception('push failed');
        });
        when(
          () => mockMonitoring.captureException(
            any(),
            stackTrace: any(named: 'stackTrace'),
            tags: any(named: 'tags'),
          ),
        ).thenReturn(null);

        var pushCompleteCalls = 0;
        final orchestrator = makeOrchestrator()
          ..onProcessQueueComplete = () => pushCompleteCalls++;
        orchestrator.init();

        orchestrator.requestFullPull('user-123');
        await Future<void>.delayed(Duration.zero);

        expect(
          pushCompleteCalls,
          1,
          reason: 'callback must fire even when push fails',
        );

        // After failure, a new sync should still be allowed (mutex released).
        connectivityController.add([ConnectivityResult.wifi]);
        await Future<void>.delayed(Duration.zero);
        // processQueue called: once from auto-flush + once from connectivity.
        verify(() => mockService.processQueue()).called(2);

        orchestrator.dispose();
      },
    );

    test(
      'does not fire onProcessQueueComplete when sync is skipped by mutex',
      () async {
        final completer = Completer<void>();
        when(() => mockService.processQueue()).thenAnswer((_) async {
          await completer.future;
        });

        var callbackCalls = 0;
        final orchestrator = makeOrchestrator()
          ..onProcessQueueComplete = () => callbackCalls++;
        orchestrator.init();

        // First sync starts and stays in-flight.
        connectivityController.add([ConnectivityResult.wifi]);
        await Future<void>.delayed(Duration.zero);

        // Second event arrives while still syncing → mutex skips.
        connectivityController.add([ConnectivityResult.mobile]);
        await Future<void>.delayed(Duration.zero);

        // No callback yet (sync still in-flight).
        expect(callbackCalls, 0);

        // Complete the first sync.
        completer.complete();
        await Future<void>.delayed(Duration.zero);

        // Only the in-flight sync ran → exactly one callback.
        expect(callbackCalls, 1);

        orchestrator.dispose();
      },
    );
  });
}
