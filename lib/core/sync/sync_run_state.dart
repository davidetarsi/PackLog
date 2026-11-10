/// Stato operativo volatile della sincronizzazione; non rappresenta i record.
sealed class SyncRunState {
  const SyncRunState();
}

final class SyncSignedOut extends SyncRunState {
  const SyncSignedOut();
}

final class SyncIdle extends SyncRunState {
  const SyncIdle();
}

final class SyncSwitchingSession extends SyncRunState {
  const SyncSwitchingSession();
}

final class SyncOffline extends SyncRunState {
  const SyncOffline();
}

enum SyncOperationKind { pull, push }

final class SyncRunning extends SyncRunState {
  const SyncRunning({
    required this.operation,
    required this.operationId,
    required this.sessionEpoch,
  });

  final SyncOperationKind operation;
  final int operationId;
  final int sessionEpoch;
}

enum SyncFailureCode { network, service, unknown }

final class SyncFailed extends SyncRunState {
  const SyncFailed(this.code);

  final SyncFailureCode code;
}
