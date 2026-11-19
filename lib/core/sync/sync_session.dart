import 'dart:async';

class SyncSessionContext {
  const SyncSessionContext._(this.epoch, this.userId, this.ownerToken);

  final int epoch;
  final String userId;
  final Object ownerToken;
}

class SyncSessionInvalid implements Exception {
  const SyncSessionInvalid();
}

/// Serializes local sync commits against account replacement. Network work is
/// intentionally outside this barrier so an obsolete response cannot hold up
/// the next account.
class SyncLocalWriteBarrier {
  final Object _ownerToken = Object();
  int _epoch = 0;
  String? _userId;
  bool _switching = true;
  bool _disposed = false;
  Future<void> _tail = Future<void>.value();
  int _activeWrites = 0;
  Completer<void>? _activeWritesDone;

  String? get userId => _userId;
  int get activeLocalWrites => _activeWrites;

  SyncSessionContext createContext(int epoch, String userId) =>
      SyncSessionContext._(epoch, userId, _ownerToken);

  SyncSessionContext? capture(String? userId) {
    if (_switching || _disposed || userId == null || userId != _userId) {
      throw const SyncSessionInvalid();
    }
    return createContext(_epoch, userId);
  }

  bool isCurrent(SyncSessionContext context) =>
      !_disposed &&
      !_switching &&
      identical(context.ownerToken, _ownerToken) &&
      context.epoch == _epoch &&
      context.userId == _userId;

  void beginSwitch(int epoch) {
    _epoch = epoch;
    _userId = null;
    _switching = true;
  }

  void activate(SyncSessionContext context) {
    if (_disposed ||
        !identical(context.ownerToken, _ownerToken) ||
        context.epoch != _epoch) {
      return;
    }
    _userId = context.userId;
    _switching = false;
  }

  void signOut(int epoch) {
    _epoch = epoch;
    _userId = null;
    _switching = false;
  }

  void dispose() {
    _disposed = true;
    _switching = true;
    _userId = null;
  }

  Future<void> drainLocalWrites() async {
    final active = _activeWritesDone;
    if (_activeWrites > 0 && active != null) await active.future;
  }

  Future<T> commit<T>(SyncSessionContext context, Future<T> Function() write) {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    return () async {
      await previous;
      try {
        if (!isCurrent(context)) throw const SyncSessionInvalid();
        if (_activeWrites++ == 0) _activeWritesDone = Completer<void>();
        try {
          return await write();
        } finally {
          if (--_activeWrites == 0) {
            _activeWritesDone?.complete();
            _activeWritesDone = null;
          }
        }
      } finally {
        release.complete();
      }
    }();
  }
}
