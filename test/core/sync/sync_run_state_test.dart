import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/sync/sync_run_state.dart';

void main() {
  test('running states identify operation and session epoch', () {
    const state = SyncRunning(
      operation: SyncOperationKind.pull,
      operationId: 7,
      sessionEpoch: 2,
    );

    expect(state.operation, SyncOperationKind.pull);
    expect(state.operationId, 7);
    expect(state.sessionEpoch, 2);
  });

  test('failure exposes a classified code without a raw message', () {
    const state = SyncFailed(SyncFailureCode.network);
    expect(state.code, SyncFailureCode.network);
    expect(state.toString(), isNot(contains('email')));
  });
}
