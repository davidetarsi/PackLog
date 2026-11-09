import '../model/ai_packing.dart';

/// Quanti pezzi di ogni oggetto entrano nella valigia quando si adotta la
/// proposta [result]: la regola unica usata dalla pagina che la salva e
/// dall'analytics che misura quanto l'utente se ne allontana.
///
/// - Proposta e kit sullo stesso oggetto: il massimo delle copie, mai la
///   somma. Sempre almeno 1.
/// - Con [available] (id → pezzi in casa; null = nessuna quantità salvata,
///   cioè 1): un oggetto assente si salta e i pezzi non superano quelli in
///   casa. Senza, l'armadio non è noto: niente tetto e niente salti.
Map<String, int> adoptedQuantities(
  AiPackingResult result, {
  Map<String, int?>? available,
}) {
  final quantities = <String, int>{};
  void put(String id, int wanted) {
    if (available != null && !available.containsKey(id)) return;
    final current = quantities[id] ?? 0;
    var quantity = wanted > current ? wanted : current;
    if (quantity < 1) quantity = 1;
    if (available != null) {
      final pieces = available[id] ?? 1;
      final cap = pieces < 1 ? 1 : pieces;
      if (quantity > cap) quantity = cap;
    }
    quantities[id] = quantity;
  }

  for (final proposed in result.proposal) {
    put(proposed.itemId, proposed.quantity);
  }
  for (final added in result.kitAdded) {
    put(added.itemId, added.copies);
  }
  return quantities;
}
