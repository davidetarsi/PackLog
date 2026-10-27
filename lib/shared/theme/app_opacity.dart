/// Opacità condivise dai componenti: un solo valore per ogni ruolo.
abstract final class AppOpacity {
  /// Velo dell'elemento scelto (pillola, filtro, categoria, icona).
  static const double selected = 0.18;

  /// Testo e icone spenti (convenzione Material).
  static const double disabled = 0.38;

  /// Superficie di una card o di una riga premuta.
  static const double pressed = 0.08;

  /// Ombra di cards, barre e cartoline.
  static const double shadow = 0.12;

  /// Contorno attenuato di bottoni rotondi, barre e pillole "dedotte".
  static const double mutedBorder = 0.5;

  /// Vetro della barra galleggiante: quanto è opaca la superficie.
  static const double navGlass = 0.78;

  /// Colore del testo selezionato (velo sul testo, non sullo sfondo).
  static const double textSelection = 0.24;

  /// Colore di fondo al bordo dello schermo nell'effetto in fondo
  /// (DsGlassBand): il contenuto si intuisce appena.
  static const double edgeTint = 0.85;
}
