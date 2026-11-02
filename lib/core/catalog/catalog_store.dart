import 'package:flutter/foundation.dart';

import 'catalog.dart';

/// Il catalogo dell'app per il resto del codice. Le funzioni di etichetta sono
/// chiamate senza `ref`, per questo è uno stato globale. Si imposta prima di
/// [runApp] e si sostituisce quando arriva un catalogo nuovo.
class CatalogStore {
  CatalogStore._();

  static Catalog current = Catalog.vuoto;

  /// La lingua delle etichette: `it` oppure, per tutto il resto, `en`.
  static String languageCode = 'it';

  /// Cresce a ogni catalogo nuovo o cambio di lingua: pillole ed etichette si
  /// ricostruiscono (vedi `catalogRevisionProvider`).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void set(Catalog nuovo) {
    current = nuovo;
    revision.value++;
  }

  static void setLanguage(String codice) {
    if (languageCode == codice) return;
    languageCode = codice;
    revision.value++;
  }
}
