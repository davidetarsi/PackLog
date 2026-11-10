import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_run_state.dart';
import 'package:pack_log/core/sync/sync_service.dart';

class _Service extends Mock implements SyncService {}

class _Connectivity extends Mock implements Connectivity {}

class _Monitoring extends Mock implements AppMonitoringService {}

void main() {
  late _Service service;
  late _Connectivity connectivity;
  late _Monitoring monitoring;
  late StreamController<List<ConnectivityResult>> changes;
  var network = true;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    network = true;
    service = _Service();
    connectivity = _Connectivity();
    monitoring = _Monitoring();
    changes = StreamController<List<ConnectivityResult>>.broadcast();
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => changes.stream);
    when(() => connectivity.checkConnectivity()).thenAnswer(
      (_) async =>
          network ? [ConnectivityResult.wifi] : [ConnectivityResult.none],
    );
    when(() => service.processQueue()).thenAnswer((_) async {});
    when(() => service.resetAllSyncRetries()).thenAnswer((_) async => 0);
    when(() => service.countPendingChanges()).thenAnswer((_) async => 0);
    when(() => service.fullPull(any())).thenAnswer((_) async {});
    when(
      () => monitoring.logBreadcrumb(
        any(),
        category: any(named: 'category'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => monitoring.captureException(
        any(),
        stackTrace: any(named: 'stackTrace'),
        tags: any(named: 'tags'),
      ),
    ).thenReturn(null);
  });

  tearDown(() => changes.close());

  SyncOrchestrator create() =>
      SyncOrchestrator(service, monitoring, connectivity: connectivity);

  test('pull failure ends running without success trigger', () async {
    final gate = Completer<void>();
    when(() => service.fullPull('u')).thenAnswer((_) => gate.future);
    var successes = 0;
    final orchestrator = create()..onFullPullComplete = () => successes++;
    orchestrator.requestFullPull('u');
    await Future<void>.delayed(Duration.zero);
    gate.completeError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    expect(orchestrator.state, isA<SyncFailed>());
    expect(successes, 0);
    orchestrator.dispose();
  });

  test('offline request does not start', () async {
    network = false;
    final orchestrator = create();
    orchestrator.requestFullPull('u');
    await Future<void>.delayed(Duration.zero);
    expect(orchestrator.state, isA<SyncOffline>());
    verifyNever(() => service.fullPull(any()));
    verifyNever(() => service.processQueue());
    orchestrator.dispose();
  });

  test('connectivity check failure remains failed, not offline', () async {
    when(() => connectivity.checkConnectivity()).thenThrow(StateError('probe'));
    final orchestrator = create();
    orchestrator.requestSync();
    await Future<void>.delayed(Duration.zero);
    expect(orchestrator.state, isA<SyncFailed>());
    verifyNever(() => service.processQueue());
    orchestrator.dispose();
  });

  test('state stream subscribes before its initial snapshot', () async {
    final started = Completer<SyncRunning>();
    final seen = <SyncRunState>[];
    final orchestrator = create();
    final subscription = orchestrator.states.listen((state) {
      seen.add(state);
      if (state case final SyncRunning running) started.complete(running);
    });

    orchestrator.requestSync();
    await started.future;
    expect(seen.first, isA<SyncIdle>());
    expect(seen[1], isA<SyncRunning>());

    await subscription.cancel();
    orchestrator.dispose();
  });

  test('mutation during push schedules one followup', () async {
    final first = Completer<void>();
    final started = Completer<void>();
    var pushes = 0;
    when(() => service.processQueue()).thenAnswer((_) async {
      pushes++;
      if (pushes == 1) {
        started.complete();
        await first.future;
      }
    });
    final orchestrator = create();
    orchestrator.requestSync();
    await started.future;
    orchestrator.requestSync();
    orchestrator.requestSync();
    await Future<void>.delayed(Duration.zero);
    first.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(pushes, 2);
    orchestrator.dispose();
  });

  test('many triggers coalesce and failure does not spin', () async {
    final first = Completer<void>();
    final started = Completer<void>();
    var pushes = 0;
    when(() => service.processQueue()).thenAnswer((_) async {
      pushes++;
      if (pushes == 1) {
        started.complete();
        await first.future;
      }
      if (pushes == 2) throw StateError('failed');
    });
    final orchestrator = create();
    orchestrator.requestSync();
    await started.future;
    for (var i = 0; i < 10; i++) {
      orchestrator.requestSync();
    }
    first.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(pushes, 2);
    expect(orchestrator.state, isA<SyncFailed>());
    orchestrator.dispose();
  });

  test('forced retry intent survives coalescing', () async {
    final first = Completer<void>();
    final started = Completer<void>();
    var pushes = 0;
    when(() => service.processQueue()).thenAnswer((_) async {
      pushes++;
      if (pushes == 1) {
        started.complete();
        await first.future;
      }
    });
    final orchestrator = create();
    orchestrator.requestSync();
    await started.future;
    orchestrator.requestForcedSync();
    first.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    verify(() => service.resetAllSyncRetries()).called(1);
    expect(pushes, 2);
    orchestrator.dispose();
  });

  test(
    'pull takes priority over pending push and keeps forced reset',
    () async {
      final pushStarted = Completer<void>();
      final allRequestsChecked = Completer<void>();
      final firstPush = Completer<void>();
      var checks = 0;
      when(() => connectivity.checkConnectivity()).thenAnswer((_) async {
        checks++;
        if (checks == 4) allRequestsChecked.complete();
        return [ConnectivityResult.wifi];
      });
      final order = <String>[];
      var pushes = 0;
      when(() => service.processQueue()).thenAnswer((_) async {
        pushes++;
        order.add('push$pushes');
        if (pushes == 1) {
          pushStarted.complete();
          await firstPush.future;
        }
      });
      when(() => service.fullPull('u')).thenAnswer((_) async {
        order.add('pull');
      });

      final orchestrator = create();
      orchestrator.requestSync();
      await pushStarted.future;
      orchestrator.requestForcedSync();
      orchestrator.requestSync();
      orchestrator.requestFullPull('u');
      await allRequestsChecked.future;
      firstPush.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(order, ['push1', 'pull', 'push2']);
      verify(() => service.resetAllSyncRetries()).called(1);
      orchestrator.dispose();
    },
  );
}
