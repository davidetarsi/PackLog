import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'item_enrichment_provider.g.dart';

/// Gli oggetti la cui scheda è in arrivo da `item-metadata`: la richiesta dal
/// nome è partita e la risposta non è ancora arrivata. Vive per tutta la
/// sessione, così la scheda può chiudersi e riaprirsi mentre aspetta.
@Riverpod(keepAlive: true)
class ItemEnrichment extends _$ItemEnrichment {
  @override
  Set<String> build() => const <String>{};

  /// Segna [itemId] come in attesa della scheda.
  void start(String itemId) {
    if (state.contains(itemId)) return;
    state = {...state, itemId};
  }

  /// Toglie [itemId] dalle richieste in corso.
  void finish(String itemId) {
    if (!state.contains(itemId)) return;
    state = {...state}..remove(itemId);
  }
}
