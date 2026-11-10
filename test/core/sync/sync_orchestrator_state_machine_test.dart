import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_run_state.dart';
import 'package:pack_log/core/sync/sync_service.dart';
import 'package:pack_log/core/sync/sync_session.dart';

class _Service extends Mock implements SyncService {}

class _Connectivity extends Mock implements Connectivity {}

class _Monitoring extends Mock implements AppMonitoringService {}

class _Barrier extends Fake implements SyncLocalWriteBarrier {}

void main() {
  late _Service service;
  late _Connectivity connectivity;
  late _Monitoring monitoring;
  late StreamController<List<ConnectivityResult>> changes;
  var network = true;

  setUpAll(() {
    registerFallbackValue(_Barrier());
  });

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
    when(() => service.bindSessionBarrier(any())).thenReturn(null);
    when(() => service.drainLocalWrites()).thenAnswer((_) async {});
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

  Future<void> activate(SyncOrchestrator orchestrator, String userId) async {
    await orchestrator.replaceSession(
      userId,
      prepareLocalData: () async => false,
    );
  }

  test('pull failure ends running without success trigger', () async {
    final gate = Completer<void>();
    when(() => service.fullPull('u')).thenAnswer((_) => gate.future);
    var successes = 0;
    final orchestrator = create()..onFullPullComplete = () => successes++;
    await activate(orchestrator, 'u');
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
    await activate(orchestrator, 'u');
    await Future<void>.delayed(Duration.zero);
    expect(orchestrator.state, isA<SyncOffline>());
    verifyNever(() => service.fullPull(any()));
    verifyNever(() => service.processQueue());
    orchestrator.dispose();
  });

  test('requestFullPull cannot replace the session owner', () async {
    final orchestrator = create();
    await activate(orchestrator, 'A');
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => service.fullPull('B'));
    verify(() => service.fullPull('A')).called(1);
    orchestrator.dispose();
  });

  test('stale finally cannot finish a new session operation', () async {
    final oldPull = Completer<void>();
    final oldStarted = Completer<void>();
    final newPull = Completer<void>();
    when(() => service.fullPull('A')).thenAnswer((_) {
      oldStarted.complete();
      return oldPull.future;
    });
    when(() => service.fullPull('B')).thenAnswer((_) => newPull.future);

    final orchestrator = create();
    await activate(orchestrator, 'A');
    await oldStarted.future;
    await activate(orchestrator, 'B');
    await Future<void>.delayed(Duration.zero);
    final running = orchestrator.state as SyncRunning;
    expect(running.sessionEpoch, 2);
    oldPull.complete();
    await Future<void>.delayed(Duration.zero);
    expect(orchestrator.state, isA<SyncRunning>());
    newPull.complete();
    await Future<void>.delayed(Duration.zero);
    expect(orchestrator.state, isA<SyncIdle>());
    orchestrator.dispose();
  });

  test('old network request does not block replacement preparation', () async {
    final oldPull = Completer<void>();
    final started = Completer<void>();
    when(() => service.fullPull('A')).thenAnswer((_) {
      started.complete();
      return oldPull.future;
    });
    final orchestrator = create();
    await activate(orchestrator, 'A');
    await started.future;
    var prepared = false;
    await orchestrator.replaceSession(
      'B',
      prepareLocalData: () async {
        prepared = true;
        return false;
      },
    );
    expect(prepared, isTrue);
    oldPull.complete();
    orchestrator.dispose();
  });

  test(
    'stale connectivity probe cannot enqueue work after session change',
    () async {
      final probe = Completer<List<ConnectivityResult>>();
      final probeStarted = Completer<void>();
      var probeCount = 0;
      when(() => connectivity.checkConnectivity()).thenAnswer((_) {
        probeCount++;
        if (probeCount == 2) {
          probeStarted.complete();
          return probe.future;
        }
        return Future.value([ConnectivityResult.wifi]);
      });
      final orchestrator = create();
      await activate(orchestrator, 'A');
      orchestrator.requestSync();
      await probeStarted.future;
      await activate(orchestrator, 'B');
      probe.complete([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => service.processQueue());
      expect(orchestrator.state, isA<SyncIdle>());
      orchestrator.dispose();
    },
  );

  test(
    'preparation failure blocks pushes and retry starts the owner pull',
    () async {
      var attempts = 0;
      final bPullStarted = Completer<void>();
      when(() => service.fullPull('B')).thenAnswer((_) {
        bPullStarted.complete();
        return Future<void>.value();
      });
      final orchestrator = create();
      await activate(orchestrator, 'A');
      await Future<void>.delayed(Duration.zero);

      await orchestrator.replaceSession(
        'B',
        prepareLocalData: () async {
          attempts++;
          if (attempts == 1) throw StateError('preferences unavailable');
          return true;
        },
      );
      expect(orchestrator.state, isA<SyncFailed>());
      expect((orchestrator.state as SyncFailed).isPreparationFailure, isTrue);
      expect(orchestrator.sessionReady, isFalse);
      orchestrator.requestSync();
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => service.processQueue());

      await orchestrator.retrySessionPreparation();
      await bPullStarted.future;
      expect(attempts, 2);
      expect(orchestrator.sessionReady, isTrue);
      verify(() => service.fullPull('B')).called(1);
      orchestrator.dispose();
    },
  );

  test('B to C preparation never activates or publishes B work', () async {
    final prepareB = Completer<bool>();
    final bStarted = Completer<void>();
    final orchestrator = create();
    await activate(orchestrator, 'A');
    final b = orchestrator.replaceSession(
      'B',
      prepareLocalData: () {
        bStarted.complete();
        return prepareB.future;
      },
    );
    await bStarted.future;
    final c = orchestrator.replaceSession(
      'C',
      prepareLocalData: () async => false,
    );
    prepareB.complete(false);
    await Future.wait([b, c]);
    expect(orchestrator.sessionReady, isTrue);
    expect(orchestrator.currentUserId, 'C');
    verifyNever(() => service.fullPull('B'));
    orchestrator.dispose();
  });

  test('dispose ignores late pull completion and success callback', () async {
    final pull = Completer<void>();
    final started = Completer<void>();
    var completed = 0;
    when(() => service.fullPull('A')).thenAnswer((_) {
      started.complete();
      return pull.future;
    });
    final orchestrator = create()..onFullPullComplete = () => completed++;
    await activate(orchestrator, 'A');
    await started.future;
    orchestrator.dispose();
    pull.complete();
    await Future<void>.delayed(Duration.zero);
    expect(completed, 0);
  });

  test('connectivity check failure remains failed, not offline', () async {
    when(() => connectivity.checkConnectivity()).thenThrow(StateError('probe'));
    final orchestrator = create();
    await activate(orchestrator, 'u');
    orchestrator.requestSync();
    await Future<void>.delayed(Duration.zero);
    expect(orchestrator.state, isA<SyncFailed>());
    verifyNever(() => service.processQueue());
    orchestrator.dispose();
  });

  test(
    'state stream emits the authoritative snapshot before changes',
    () async {
      final seen = <SyncRunState>[];
      final orchestrator = create();
      final initial = orchestrator.state;
      final subscription = orchestrator.states.listen(seen.add);
      await activate(orchestrator, 'u');
      await Future<void>.delayed(Duration.zero);
      expect(seen.first, same(initial));
      expect(seen, contains(isA<SyncSwitchingSession>()));
      expect(seen, contains(isA<SyncRunning>()));
      await subscription.cancel();
      orchestrator.dispose();
    },
  );

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
    await activate(orchestrator, 'u');
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
    await activate(orchestrator, 'u');
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
    await activate(orchestrator, 'u');
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
        if (checks == 5) allRequestsChecked.complete();
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
      await activate(orchestrator, 'u');
      orchestrator.requestSync();
      await pushStarted.future;
      orchestrator.requestForcedSync();
      orchestrator.requestSync();
      orchestrator.requestFullPull('u');
      await allRequestsChecked.future;
      firstPush.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(order, ['pull', 'push1', 'pull', 'push2']);
      verify(() => service.resetAllSyncRetries()).called(1);
      orchestrator.dispose();
    },
  );
}
