import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Mixin per notifier Riverpod che gestiscono una lista di entità persistenti
/// seguendo il pattern *load → mutate → reload*.
///
/// Funziona sia con notifier non-family (`AsyncNotifier<List<T>>`) sia con
/// family notifier (`build(Arg arg)`) poiché non impone un vincolo `on` su
/// un tipo specifico: l'accesso a `state` avviene tramite la dichiarazione
/// astratta soddisfatta dalla superclasse generata da riverpod_generator.
///
/// ## Cosa fa
///
/// Fornisce [mutate], che incapsula il pattern ricorrente:
/// 1. (opzionale) mostra `AsyncLoading` intermedio;
/// 2. esegue l'operazione di scrittura;
/// 3. ricarica la lista dal repository;
/// 4. richiama [onSuccess] se passata (può essere async);
/// 5. invoca l'hook [onMutationSuccess] o [onMutationError];
/// 6. propaga l'eccezione al chiamante via rethrow (se `rethrowOnError = true`).
///
/// ## Cosa NON fa
///
/// - Non gestisce optimistic updates: la UI vede la nuova lista solo dopo
///   il reload completo.
/// - Non gestisce cancellazione di mutazioni in flight.
/// - Non gestisce retry automatico.
/// - Non sa nulla di sync orchestrator, analytics, o altri provider:
///   la classe finale lo collega via [onMutationSuccess].
///
/// ## Come usarlo
///
/// La classe finale override [onMutationSuccess] / [onMutationError] per
/// applicare logica app-specifica (sync, analytics, log).
///
/// ```dart
/// @Riverpod(keepAlive: true)
/// class HouseNotifier extends _$HouseNotifier
///     with SyncedCrudNotifier<HouseModel> {
///
///   HouseRepository get _repo => ref.read(houseRepositoryProvider);
///
///   @override
///   Future<List<HouseModel>> build() async {
///     ref.watch(syncTriggerProvider);
///     return _repo.getAllHouses();
///   }
///
///   @override
///   void onMutationSuccess(List<HouseModel> updated) {
///     ref.read(syncOrchestratorProvider).requestSync();
///   }
///
///   Future<void> addHouse(HouseModel model) => mutate(
///     operation: () => _repo.addHouse(model),
///     reload: _repo.getAllHouses,
///     onSuccess: (houses) => ref.read(analyticsProvider)
///         .trackHouseCreated(houseId: model.id, totalHouses: houses.length),
///   );
/// }
/// ```
mixin SyncedCrudNotifier<T> {
  /// Accesso a `state` fornito dalla superclasse generata da riverpod_generator
  /// (`AsyncNotifier<List<T>>` per non-family, `BuildlessAsyncNotifier<List<T>>`
  /// per family). La dichiarazione astratta qui è soddisfatta via ereditarietà.
  @protected
  AsyncValue<List<T>> get state;

  @protected
  set state(AsyncValue<List<T>> newState);

  /// Hook invocato dopo ogni mutazione riuscita.
  ///
  /// [updated] è la lista appena ricaricata dal repository (post-mutazione).
  /// È **la stessa lista** che diventerà il nuovo `state`. Leggere `state`
  /// dentro questo hook restituirebbe ancora i dati pre-mutazione: usa
  /// sempre l'argomento [updated].
  ///
  /// Override per side-effect a livello di entità (es. richiesta sync,
  /// invalidazione di provider correlati, analytics che dipendono dal
  /// nuovo conteggio).
  @protected
  void onMutationSuccess(List<T> updated) {}

  /// Hook invocato dopo ogni mutazione fallita.
  ///
  /// Override per logging custom. Eseguito **prima** che `state` venga
  /// modificato — il chiamante non deve leggere `state` qui per osservare
  /// l'errore. La propagazione al chiamante è gestita dai parametri
  /// `rethrowOnError` e `rethrowOnly` di [mutate].
  @protected
  void onMutationError(Object error, StackTrace stack) {}

  /// Esegue una mutazione persistente seguita da reload della lista.
  ///
  /// - [operation]: l'azione di scrittura (insert/update/delete).
  /// - [reload]: come ricostruire la lista (es. `repo.getAllX`).
  /// - [showLoading]: se `true`, mostra `AsyncLoading` durante l'operazione.
  ///   Default `false` per evitare flash UI. Usalo solo per operazioni
  ///   con attesa percepibile (>500ms tipici).
  /// - [onSuccess]: callback opzionale eseguita dopo il reload riuscito,
  ///   prima di [onMutationSuccess]. Riceve la lista AGGIORNATA come
  ///   argomento. Non leggere `state` dentro questa callback — sarebbe
  ///   ancora la lista pre-mutazione (lo state viene assegnato solo dopo
  ///   `AsyncValue.guard`). Usa sempre l'argomento.
  /// - [rethrowOnError]: se `true` (default), rilancia l'eccezione al
  ///   chiamante dopo aver settato `state = AsyncError`. Il chiamante può
  ///   intercettarla con try/catch per UI dedicata (es. dialog di retry).
  ///   Usa `false` per metodi tipo `refresh()` wired a callback senza
  ///   gestione errore (es. `onRetry` di un ErrorState).
  /// - [rethrowOnly]: se `true`, in caso di errore rilancia l'eccezione
  ///   senza settare `state = AsyncError`. Utile quando il feedback errore
  ///   è gestito dal chiamante (es. `ErrorRetryDialog.executeWithRetry`):
  ///   la lista rimane visibile intatta e non appare il flash di errore.
  ///   Ripristina anche l'eventuale `AsyncLoading` intermedio allo stato
  ///   precedente. Quando `true`, `rethrowOnError` è ignorato.
  @protected
  Future<void> mutate({
    required Future<void> Function() operation,
    required Future<List<T>> Function() reload,
    bool showLoading = false,
    FutureOr<void> Function(List<T> updated)? onSuccess,
    bool rethrowOnError = true,
    bool rethrowOnly = false,
  }) async {
    // Memorizza lo stato valido attuale prima di qualsiasi modifica
    final previousState = state;

    if (showLoading) state = const AsyncLoading();

    List<T>? freshList;
    final result = await AsyncValue.guard<List<T>>(() async {
      await operation();
      final fresh = await reload();
      freshList = fresh;
      if (onSuccess != null) await onSuccess(fresh);
      return fresh;
    });

    if (result.hasError) {
      onMutationError(result.error!, result.stackTrace!);
      if (rethrowOnly) {
        // Dialog-driven error handling: ripristina lo stato precedente (rimuove
        // l'eventuale AsyncLoading), poi rilancia senza settare AsyncError.
        // La lista torna a mostrare i dati intatti; il feedback errore vive nel dialog.
        state = previousState;
        Error.throwWithStackTrace(result.error!, result.stackTrace!);
      } else {
        state = result; // setta AsyncError — path B (state-driven)
        if (rethrowOnError) {
          Error.throwWithStackTrace(result.error!, result.stackTrace!);
        }
      }
    } else {
      state = result;
      if (result.hasValue) {
        // freshList è non-null qui: AsyncValue.guard non sarebbe in stato
        // "hasValue" senza aver completato il blocco senza eccezioni.
        onMutationSuccess(freshList!);
      }
    }
  }
}
