/// Traduce una spunta della checklist di viaggio negli eventi analytics del
/// funnel "preparazione della valigia".
///
/// **Perché è puro.** Non conosce Riverpod, il database né il sink analytics:
/// riceve la transizione (quanti oggetti erano spuntati prima, quanti dopo) e
/// restituisce gli eventi da emettere. La logica che sbaglia più facilmente —
/// l'attraversamento delle soglie — è così testabile senza container né mock,
/// con test tabellari che girano in millisecondi.
///
/// **Perché non persiste nulla.** Gli eventi sono funzione della transizione,
/// non di un flag: dopo un riavvio dell'app lo stato di partenza è comunque
/// quello vero, letto dal database, quindi i conti restano corretti senza
/// tenere traccia di quali soglie siano già state emesse. L'unico caso di
/// evento ripetuto è chi despunta e rispunta oscillando attorno a una soglia,
/// che è comportamento reale e raro — non vale una tabella in più.
library;

/// Soglie intermedie di completamento, in percentuale.
const List<int> kPackingThresholds = [25, 50, 75];

/// Un evento analytics pronto da inoltrare al sink: nome più proprietà.
class PackingEvent {
  final String name;
  final Map<String, dynamic> properties;

  const PackingEvent(this.name, this.properties);

  @override
  String toString() => 'PackingEvent($name, $properties)';

  @override
  bool operator ==(Object other) =>
      other is PackingEvent &&
      other.name == name &&
      _mapEquals(other.properties, properties);

  @override
  int get hashCode => Object.hash(name, properties.length);

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

/// Calcola gli eventi del funnel della valigia per una singola spunta.
///
/// [checkedBefore] e [checkedAfter] sono i conteggi di oggetti spuntati prima
/// e dopo il tap; [totalItems] è il totale degli oggetti del viaggio.
/// [departureDateTime] può essere `null` (viaggio senza date): in quel caso
/// `days_to_departure` viaggia a `null` invece di essere omesso, così le query
/// non devono distinguere fra chiave assente e data non impostata.
List<PackingEvent> packingEventsFor({
  required String tripId,
  required int checkedBefore,
  required int checkedAfter,
  required int totalItems,
  required DateTime? departureDateTime,
  required DateTime now,
}) {
  // Un viaggio senza oggetti non ha una percentuale: uscire subito è anche
  // l'unica difesa contro la divisione per zero qui sotto.
  if (totalItems <= 0) return const [];

  // Despuntare è correzione, non regressione del funnel: non emette nulla.
  if (checkedAfter <= checkedBefore) return const [];

  final int? daysToDeparture = departureDateTime == null
      ? null
      : _wholeDaysBetween(now, departureDateTime);

  final events = <PackingEvent>[];

  if (checkedBefore == 0) {
    events.add(
      PackingEvent('packing_started', {
        'trip_id': tripId,
        'total_items': totalItems,
        'days_to_departure': daysToDeparture,
      }),
    );
  }

  if (checkedAfter >= totalItems) {
    // Il 100% sopprime le soglie intermedie: su un viaggio da un oggetto un
    // solo tap le attraverserebbe tutte, producendo cinque eventi per un
    // gesto. `packing_completed` dice già tutto quello che direbbero loro.
    events.add(
      PackingEvent('packing_completed', {
        'trip_id': tripId,
        'total_items': totalItems,
        'days_to_departure': daysToDeparture,
      }),
    );
    return events;
  }

  final double percentBefore = checkedBefore * 100 / totalItems;
  final double percentAfter = checkedAfter * 100 / totalItems;

  // Un solo evento anche quando un tap scavalca più soglie (su un viaggio da
  // tre oggetti si passa dal 33% al 66%, superando 25 e 50): interessa il
  // punto più alto raggiunto, non la storia dei salti.
  final crossed = kPackingThresholds
      .where((t) => percentBefore < t && percentAfter >= t)
      .toList();

  if (crossed.isNotEmpty) {
    events.add(
      PackingEvent('packing_progress', {
        'trip_id': tripId,
        'threshold': crossed.last,
        'days_to_departure': daysToDeparture,
      }),
    );
  }

  return events;
}

/// Giorni interi che mancano alla partenza, con segno: negativo se si sta
/// spuntando dopo essere partiti, il che è un dato interessante di per sé.
///
/// Confronta le date a mezzanotte e non gli istanti, altrimenti "domani alle
/// 9" a poche ore di distanza risulterebbe 0 giorni invece di 1.
int _wholeDaysBetween(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  return b.difference(a).inDays;
}
