import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/notifier/synced_crud_notifier.dart';

/// Notifier di test che usa il mixin. Espone gli hook e i contatori per
/// verificare il comportamento del mixin in isolamento.
class _TestNotifier extends AsyncNotifier<List<int>>
    with SyncedCrudNotifier<int> {
  // Counter per verificare quanti volte gli hook sono stati chiamati.
  int successHookCalls = 0;
  int errorHookCalls = 0;
  Object? lastError;

  // Comportamento configurabile dai test.
  List<int> reloadResult = [1, 2, 3];
  bool failOperation = false;
  bool failReload = false;
  Object? operationError;

  // Cattura l'argomento ricevuto da onMutationSuccess per verificare che sia
  // la lista AGGIORNATA (post-reload), non quella pre-mutazione.
  List<int>? lastSuccessHookArgument;

  @override
  Future<List<int>> build() async => <int>[];

  @override
  void onMutationSuccess(List<int> updated) {
    successHookCalls++;
    lastSuccessHookArgument = updated;
  }

  @override
  void onMutationError(Object error, StackTrace stack) {
    errorHookCalls++;
    lastError = error;
  }

  /// Espone `mutate` ai test (è protected — qui simuliamo una "vera" sottoclasse).
  Future<void> runMutation({
    bool showLoading = false,
    FutureOr<void> Function(List<int> updated)? onSuccess,
    bool rethrowOnError = true,
    bool rethrowOnly = false,
  }) {
    return mutate(
      operation: () async {
        if (failOperation) {
          throw operationError ?? Exception('op failed');
        }
      },
      reload: () async {
        if (failReload) {
          throw Exception('reload failed');
        }
        return reloadResult;
      },
      showLoading: showLoading,
      onSuccess: onSuccess,
      rethrowOnError: rethrowOnError,
      rethrowOnly: rethrowOnly,
    );
  }
}

final _testProvider = AsyncNotifierProvider<_TestNotifier, List<int>>(
  _TestNotifier.new,
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('SyncedCrudNotifier - happy path', () {
    test('updates state to AsyncData with reload result on success', () async {
      await container.read(_testProvider.future);
      final notifier = container.read(_testProvider.notifier);
      notifier.reloadResult = [10, 20, 30];

      await notifier.runMutation();

      final state = container.read(_testProvider);
      expect(state, isA<AsyncData<List<int>>>());
      expect(state.value, equals([10, 20, 30]));
    });

    test('calls onMutationSuccess hook exactly once on success', () async {
      await container.read(_testProvider.future);
      final notifier = container.read(_testProvider.notifier);

      await notifier.runMutation();

      expect(notifier.successHookCalls, equals(1));
      expect(notifier.errorHookCalls, equals(0));
    });

    test('calls onSuccess callback BEFORE onMutationSuccess hook', () async {
      await container.read(_testProvider.future);
      final notifier = container.read(_testProvider.notifier);
      final callOrder = <String>[];

      await notifier.runMutation(onSuccess: (_) => callOrder.add('onSuccess'));

      expect(callOrder, equals(['onSuccess']));
      expect(notifier.successHookCalls, equals(1));
    });

    test('supports async onSuccess callback (FutureOr)', () async {
      await container.read(_testProvider.future);
      final notifier = container.read(_testProvider.notifier);
      var asyncWorkDone = false;

      await notifier.runMutation(
        onSuccess: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          asyncWorkDone = true;
        },
      );

      expect(asyncWorkDone, isTrue);
      expect(notifier.successHookCalls, equals(1));
    });

    test(
      'onSuccess receives the FRESH list (post-reload), not the old state',
      () async {
        await container.read(_testProvider.future);
        final notifier = container.read(_testProvider.notifier);
        notifier.reloadResult = [100, 200, 300];

        List<int>? receivedInOnSuccess;
        await notifier.runMutation(
          onSuccess: (list) {
            receivedInOnSuccess = list;
          },
        );

        // onSuccess deve aver visto la lista fresca passata come argomento,
        // NON la vecchia lista dello state (che era vuota dal build()).
        expect(receivedInOnSuccess, equals([100, 200, 300]));
        // E onMutationSuccess deve aver ricevuto la stessa lista fresca.
        expect(notifier.lastSuccessHookArgument, equals([100, 200, 300]));
      },
    );

    test(
      'onSuccess can read fresh list via argument BEFORE state is updated',
      () async {
        // Questo test prova il bug "phantom state": se onSuccess leggesse
        // state.valueOrNull invece dell'argomento, vedrebbe la lista vecchia.
        await container.read(_testProvider.future); // state = []
        final notifier = container.read(_testProvider.notifier);
        notifier.reloadResult = [42];

        late List<int> stateInsideOnSuccess;
        late List<int> argumentInsideOnSuccess;
        await notifier.runMutation(
          onSuccess: (list) {
            stateInsideOnSuccess =
                container.read(_testProvider).valueOrNull ?? <int>[];
            argumentInsideOnSuccess = list;
          },
        );

        // Lo state durante onSuccess è ancora il vecchio (vuoto).
        expect(stateInsideOnSuccess, equals(<int>[]));
        // Ma l'argomento è quello fresco.
        expect(argumentInsideOnSuccess, equals([42]));
        // E dopo l'await, lo state è aggiornato.
        expect(container.read(_testProvider).value, equals([42]));
      },
    );
  });

  group('SyncedCrudNotifier - error path', () {
    test('updates state to AsyncError when operation fails', () async {
      await container.read(_testProvider.future);
      final notifier = container.read(_testProvider.notifier);
      notifier.failOperation = true;

      await expectLater(notifier.runMutation(), throwsException);

      final state = container.read(_testProvider);
      expect(state, isA<AsyncError<List<int>>>());
    });

    test('calls onMutationError hook with error and stack trace', () async {
      await container.read(_testProvider.future);
      final notifier = container.read(_testProvider.notifier);
      final specificError = StateError('specific');
      notifier.failOperation = true;
      notifier.operationError = specificError;

      await expectLater(notifier.runMutation(), throwsA(equals(specificError)));

      expect(notifier.errorHookCalls, equals(1));
      expect(notifier.lastError, equals(specificError));
      expect(notifier.successHookCalls, equals(0));
    });

    test('does NOT rethrow when rethrowOnError is false', () async {
      await container.read(_testProvider.future);
      final notifier = container.read(_testProvider.notifier);
      notifier.failOperation = true;

      // Non deve lanciare.
      await notifier.runMutation(rethrowOnError: false);

      final state = container.read(_testProvider);
      expect(state, isA<AsyncError<List<int>>>());
      expect(notifier.errorHookCalls, equals(1));
    });

    test('updates state to AsyncError when reload fails', () async {
      await container.read(_testProvider.future);
      final notifier = container.read(_testProvider.notifier);
      notifier.failReload = true;

      await expectLater(notifier.runMutation(), throwsException);

      final state = container.read(_testProvider);
      expect(state, isA<AsyncError<List<int>>>());
      expect(notifier.errorHookCalls, equals(1));
    });
  });

  group('SyncedCrudNotifier - showLoading parameter', () {
    test('sets AsyncLoading intermediate when showLoading=true', () async {
      await container.read(_testProvider.future);
      final notifier = container.read(_testProvider.notifier);

      // Catturiamo gli stati osservati.
      final observedStates = <AsyncValue<List<int>>>[];
      container.listen<AsyncValue<List<int>>>(
        _testProvider,
        (_, next) => observedStates.add(next),
        fireImmediately: false,
      );

      await notifier.runMutation(showLoading: true);

      // Deve aver visto AsyncLoading prima di AsyncData.
      expect(
        observedStates.any((s) => s is AsyncLoading<List<int>>),
        isTrue,
        reason: 'AsyncLoading dovrebbe apparire quando showLoading=true',
      );
      expect(observedStates.last, isA<AsyncData<List<int>>>());
    });

    test(
      'does NOT set AsyncLoading intermediate when showLoading=false (default)',
      () async {
        await container.read(_testProvider.future);
        final notifier = container.read(_testProvider.notifier);

        final observedStates = <AsyncValue<List<int>>>[];
        container.listen<AsyncValue<List<int>>>(
          _testProvider,
          (_, next) => observedStates.add(next),
          fireImmediately: false,
        );

        await notifier.runMutation();

        // Non deve esserci AsyncLoading intermedio.
        expect(
          observedStates.any((s) => s is AsyncLoading<List<int>>),
          isFalse,
          reason: 'Nessun AsyncLoading atteso con showLoading=false (default)',
        );
      },
    );
  });

  group('SyncedCrudNotifier - rethrowOnly parameter', () {
    test(
      'does not set AsyncError state but still rethrows when rethrowOnly=true',
      () async {
        await container.read(_testProvider.future);
        final notifier = container.read(_testProvider.notifier);
        notifier.reloadResult = [1, 2, 3];
        notifier.failOperation = true;

        // Prima impostiamo uno stato dati valido tramite una mutazione riuscita.
        notifier.failOperation = false;
        await notifier.runMutation();
        expect(container.read(_testProvider).value, equals([1, 2, 3]));

        // Ora falliamo con rethrowOnly=true.
        notifier.failOperation = true;
        Object? caught;
        try {
          await notifier.runMutation(rethrowOnly: true);
        } catch (e) {
          caught = e;
        }

        // L'eccezione deve essere stata rilanciata al chiamante.
        expect(caught, isA<Exception>());

        // Lo state deve rimanere AsyncData (non AsyncError).
        final stateAfter = container.read(_testProvider);
        expect(
          stateAfter,
          isA<AsyncData<List<int>>>(),
          reason: 'rethrowOnly=true non deve settare AsyncError',
        );
        expect(stateAfter.value, equals([1, 2, 3]));

        // L'hook onMutationError deve essere stato chiamato.
        expect(notifier.errorHookCalls, equals(1));
        expect(notifier.successHookCalls, equals(1)); // solo dalla prima mutazione
      },
    );

    test(
      'restores previousState (removes AsyncLoading) when showLoading=true and rethrowOnly=true',
      () async {
        await container.read(_testProvider.future);
        final notifier = container.read(_testProvider.notifier);
        notifier.reloadResult = [7, 8, 9];
        notifier.failOperation = false;

        // Imposta uno stato dati valido.
        await notifier.runMutation();
        final dataStateBefore = container.read(_testProvider);
        expect(dataStateBefore.value, equals([7, 8, 9]));

        // Ora fallisce con showLoading=true + rethrowOnly=true.
        notifier.failOperation = true;
        final observedStates = <AsyncValue<List<int>>>[];
        container.listen<AsyncValue<List<int>>>(
          _testProvider,
          (_, next) => observedStates.add(next),
          fireImmediately: false,
        );

        Object? caught;
        try {
          await notifier.runMutation(showLoading: true, rethrowOnly: true);
        } catch (e) {
          caught = e;
        }

        expect(caught, isA<Exception>());

        // Deve aver visto AsyncLoading durante l'operazione.
        expect(
          observedStates.any((s) => s is AsyncLoading<List<int>>),
          isTrue,
          reason: 'AsyncLoading atteso con showLoading=true',
        );

        // Stato finale: ripristinato a AsyncData (non AsyncError, non AsyncLoading).
        expect(
          container.read(_testProvider),
          isA<AsyncData<List<int>>>(),
          reason: 'Lo stato deve essere ripristinato a AsyncData dopo rethrowOnly',
        );
        expect(container.read(_testProvider).value, equals([7, 8, 9]));
      },
    );

    test(
      'rethrowOnly=false still sets AsyncError (regression guard)',
      () async {
        await container.read(_testProvider.future);
        final notifier = container.read(_testProvider.notifier);
        notifier.failOperation = true;

        await expectLater(
          notifier.runMutation(rethrowOnly: false, rethrowOnError: true),
          throwsException,
        );

        expect(container.read(_testProvider), isA<AsyncError<List<int>>>());
      },
    );
  });
}
