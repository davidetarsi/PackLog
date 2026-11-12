import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/sync/sync_session.dart';
import '../../../core/sync/sync_provider.dart';

part 'item_enrichment_provider.g.dart';

/// Gli oggetti la cui scheda è in arrivo da `item-metadata`: la richiesta dal
/// nome è partita e la risposta non è ancora arrivata. Vive per tutta la
/// sessione, così la scheda può chiudersi e riaprirsi mentre aspetta.
@Riverpod(keepAlive: true)
class ItemEnrichment extends _$ItemEnrichment {
  final Map<String, SyncSessionContext> _owners = {};
  @override
  Set<String> build() {
    ref.listen(syncRunStateProvider, (_, _) {
      final orchestrator = ref.read(syncOrchestratorProvider);
      final stale = _owners.entries
          .where(
            (entry) => !orchestrator.isLocalWriteContextCurrent(entry.value),
          )
          .map((entry) => entry.key)
          .toSet();
      _owners.removeWhere((id, _) => stale.contains(id));
      if (stale.isNotEmpty) state = {...state}..removeAll(stale);
    });
    return const <String>{};
  }

  /// Segna [itemId] come in attesa della scheda.
  void start(String itemId, SyncSessionContext context) {
    _owners[itemId] = context;
    if (!state.contains(itemId)) state = {...state, itemId};
  }

  /// Toglie [itemId] dalle richieste in corso.
  void finish(String itemId, SyncSessionContext context) {
    if (!identical(_owners[itemId], context)) return;
    _owners.remove(itemId);
    if (!state.contains(itemId)) return;
    state = {...state}..remove(itemId);
  }
}
