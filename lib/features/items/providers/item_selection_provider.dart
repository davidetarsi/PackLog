import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'item_selection_provider.g.dart';

/// Stato immutabile della selezione multipla di item in una casa.
///
/// ## Perché una classe manuale invece di Freezed?
///
/// Lo stato è abbastanza semplice (2 campi) e non richiede serializzazione JSON.
/// Una classe manuale con `copyWith` è sufficiente e non genera codice extra.
///
/// ## Reactivity Contract di Riverpod
///
/// **CRITICO**: `selectedIds` è un `Set<String>`. Riverpod confronta gli stati
/// con `==`. Poiché `Set` non è immutabile per default, è **obbligatorio**
/// passare sempre un **nuovo** `Set` in `copyWith` — mai mutare quello esistente.
/// Tutti i metodi di [ItemSelectionNotifier] rispettano questo contratto.
class ItemSelectionState {
  /// Indica se la modalità selezione multipla è attiva.
  final bool isActive;

  /// Set degli ID degli item attualmente selezionati.
  ///
  /// Sempre un'istanza nuova dopo ogni modifica per garantire la reattività
  /// di Riverpod (shallow equality check su `state`).
  final Set<String> selectedIds;

  const ItemSelectionState({
    this.isActive = false,
    this.selectedIds = const {},
  });

  ItemSelectionState copyWith({
    bool? isActive,
    Set<String>? selectedIds,
  }) =>
      ItemSelectionState(
        isActive: isActive ?? this.isActive,
        selectedIds: selectedIds ?? this.selectedIds,
      );

  /// Numero di item selezionati.
  int get selectionCount => selectedIds.length;

  /// True se almeno un item è selezionato.
  bool get hasSelection => selectedIds.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemSelectionState &&
          runtimeType == other.runtimeType &&
          isActive == other.isActive &&
          _setsEqual(selectedIds, other.selectedIds);

  @override
  int get hashCode => Object.hash(isActive, Object.hashAll(selectedIds));

  static bool _setsEqual(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.every(b.contains);
  }

  @override
  String toString() =>
      'ItemSelectionState(isActive: $isActive, count: $selectionCount)';
}

/// Notifier per la gestione della selezione multipla di item.
///
/// È un provider **globale** (non family): la selezione è unica nell'app
/// perché solo una schermata alla volta mostra una lista di item modificabile.
/// Lo stato viene sempre azzerato chiamando [clear] quando la schermata
/// viene smontata o l'utente esce dalla modalità selezione.
///
/// ## Pattern di uso
///
/// ```dart
/// // Attiva la selezione dal long press sul primo item
/// ref.read(itemSelectionProvider.notifier).toggleMode();
/// ref.read(itemSelectionProvider.notifier).toggleItem(item.id);
///
/// // Nella UI
/// final selectionState = ref.watch(itemSelectionProvider);
/// if (selectionState.isActive) { ... }
/// ```
@riverpod
class ItemSelectionNotifier extends _$ItemSelectionNotifier {
  @override
  ItemSelectionState build() => const ItemSelectionState();

  /// Attiva o disattiva la modalità selezione multipla.
  ///
  /// Quando viene **disattivata**, i [ItemSelectionState.selectedIds] vengono
  /// svuotati automaticamente per evitare selezioni "fantasma" alla riapertura.
  void toggleMode() {
    if (state.isActive) {
      // Disattivazione: reset completo
      state = const ItemSelectionState();
    } else {
      state = state.copyWith(isActive: true);
    }
  }

  /// Aggiunge o rimuove [id] dalla selezione.
  ///
  /// Crea sempre un **nuovo** [Set] per soddisfare il contratto di reattività
  /// di Riverpod: il confronto shallow di `state` rileva il cambiamento solo
  /// se `selectedIds` è un'istanza diversa.
  void toggleItem(String id) {
    final current = state.selectedIds;
    final updated = Set<String>.from(current);

    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }

    state = state.copyWith(selectedIds: updated);
  }

  /// Azzera la selezione e disattiva la modalità multi-select.
  ///
  /// Chiamare da [dispose] delle schermate che usano la selezione, oppure
  /// quando l'utente naviga via, per evitare stati stale.
  void clear() => state = const ItemSelectionState();

  /// Seleziona tutti gli item forniti aggiungendoli al set corrente.
  ///
  /// Gli ID già presenti non vengono duplicati (Set semantics).
  void selectAll(List<String> ids) {
    final updated = Set<String>.from(state.selectedIds)..addAll(ids);
    state = state.copyWith(selectedIds: updated);
  }

  /// Deseleziona tutti gli item mantenendo la modalità attiva.
  ///
  /// Utile per il pulsante "Deseleziona tutto" nella action bar.
  void deselectAll() {
    state = state.copyWith(selectedIds: const {});
  }
}
