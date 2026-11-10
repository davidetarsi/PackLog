import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/sync/sync_session.dart';

void main() {
  test('session replacement drains commits already in progress', () async {
    final barrier = SyncLocalWriteBarrier()..beginSwitch(1);
    final ownerA = barrier.createContext(1, 'A');
    barrier.activate(ownerA);
    final writeStarted = Completer<void>();
    final finishWrite = Completer<void>();
    final write = barrier.commit(ownerA, () async {
      writeStarted.complete();
      await finishWrite.future;
    });
    await writeStarted.future;

    barrier.beginSwitch(2);
    var replacementReady = false;
    final drain = barrier.drainLocalWrites().then((_) {
      replacementReady = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(replacementReady, isFalse);

    finishWrite.complete();
    await Future.wait([write, drain]);
    expect(replacementReady, isTrue);
  });

  test('same user context from a different barrier is obsolete', () async {
    final first = SyncLocalWriteBarrier()..beginSwitch(1);
    first.activate(first.createContext(1, 'A'));
    final stale = first.capture('A')!;
    final second = SyncLocalWriteBarrier()..beginSwitch(1);
    second.activate(second.createContext(1, 'A'));

    expect(first.isCurrent(stale), isTrue);
    expect(second.isCurrent(stale), isFalse);
    await expectLater(
      second.commit(stale, () async {}),
      throwsA(isA<SyncSessionInvalid>()),
    );
  });
}
