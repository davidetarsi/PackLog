import 'catalog_store.dart';

// Le scelte del catalogo per le pillole: quali voci si propongono, quali si
// mostrano con la loro etichetta. Valgono per tutti i domini (usi, stile, colori,
// tipi dei capi, attività e alloggi del viaggio).

/// Se la voce [id] del [dominio] si propone nelle scelte. Una voce che il catalogo
/// non conosce si tratta come attiva, com'era prima del catalogo.
bool voceAttiva(String dominio, String id) =>
    CatalogStore.current.find(dominio, id)?.active ?? true;

/// Gli identificativi di un dominio nell'ordine del catalogo; con [activeOnly]
/// false compaiono anche le voci disattivate.
List<String> vociDi(String dominio, {bool activeOnly = true}) => [
  for (final voce in CatalogStore.current.domain(
    dominio,
    activeOnly: activeOnly,
  ))
    voce.id,
];

/// Le scelte da proporre di [tutte]: quelle attive, più quelle disattivate che il
/// capo o il viaggio usa già ([giaUsate]), che si mostrano con la loro etichetta.
List<String> daProporre(
  List<String> tutte, {
  required Iterable<String> giaUsate,
  required String dominio,
}) => [
  for (final id in tutte)
    if (voceAttiva(dominio, id) || giaUsate.contains(id)) id,
];

/// L'etichetta di una voce nella lingua attiva. Un valore che il catalogo non
/// conosce torna com'è.
String etichettaDi(String dominio, String id) {
  final voce = CatalogStore.current.find(dominio, id);
  return voce == null ? id : voce.label(CatalogStore.languageCode);
}
