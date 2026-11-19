import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_run_state.dart';
import 'package:pack_log/core/sync/sync_session.dart';

/// Mock runtime con owner autenticato pronto e write fence locale reale.
class PreparedSyncOrchestrator extends Mock implements SyncOrchestrator {
  PreparedSyncOrchestrator({this.userId = 'test-user', this.ready = true}) {
    if (userId != null && ready) {
      _barrier.activate(_barrier.createContext(_epoch, userId!));
    }
  }

  String? userId;
  bool ready;
  int _epoch = 0;
  final _barrier = SyncLocalWriteBarrier();
  final _stateEvents = StreamController<SyncRunState>.broadcast(sync: true);
  SyncRunState _state = const SyncIdle();

  @override
  String? get currentUserId => userId;
  @override
  int get sessionEpoch => _epoch;
  @override
  bool get sessionReady => ready;
  @override
  Stream<SyncRunState> get states => Stream<SyncRunState>.multi((sink) {
    final subscription = _stateEvents.stream.listen(sink.add);
    sink.add(_state);
    sink.onCancel = subscription.cancel;
  }, isBroadcast: true);
  @override
  SyncSessionContext? captureLocalWriteContext() =>
      ready && userId != null ? _barrier.capture(userId) : null;
  @override
  bool isLocalWriteContextCurrent(SyncSessionContext context) =>
      ready && _barrier.isCurrent(context);
  @override
  Future<T> commitLocalWrite<T>(
    SyncSessionContext context,
    Future<T> Function() write,
  ) => _barrier.commit(context, write);

  @override
  Future<void> replaceSession(
    String? nextUserId, {
    required Future<bool> Function() prepareLocalData,
  }) async {
    final epoch = ++_epoch;
    ready = false;
    userId = nextUserId;
    _barrier.beginSwitch(epoch);
    _publish(const SyncSwitchingSession());
    await _barrier.drainLocalWrites();
    await prepareLocalData();
    if (nextUserId == null) {
      _barrier.signOut(epoch);
      _publish(const SyncSignedOut());
      return;
    }
    _barrier.activate(_barrier.createContext(epoch, nextUserId));
    ready = true;
    _publish(const SyncIdle());
  }

  void _publish(SyncRunState state) {
    _state = state;
    _stateEvents.add(state);
  }
}
