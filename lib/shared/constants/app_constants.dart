// Regola border radius (DS Phase 1):
// - Token noti (cardBorderRadius, pillBorderRadius, …) → BorderRadius.circular(AppConstants.X) raw.
//   Scalare con responsiveBorderRadius su token noti è impercettibile e aggiunge complessità.
// - Valori contestuali/magici (es. raggi derivati da un'altra misura) → context.responsiveBorderRadius(X).
class AppConstants {
  static const String housesKey = 'houses';
  static const String itemsKey = 'items';
  static const String tripsKey = 'trips';

  // ── UI Layout Tokens ────────────────────────────────────────────────────────

  /// Gutter orizzontale standard di pagina.
  /// Fonte unica: usare per ogni padding left/right a livello di schermata.
  /// Equivale ad AppSpacing.md (= 16.0). Valore duplicato deliberatamente
  /// per evitare dipendenza circolare tra app_constants e app_spacing.
  static const double screenHorizontalGutter = 16.0;

  /// Altezza della floating tab bar (senza safe area).
  /// Bumpata a 60 in Fase 3 per accomodare label 12px + icona 22px senza overflow.
  static const double tabBarHeight = 60.0;

  // ── Border Radius ────────────────────────────────────────────────────────────

  /// Border radius for cards (16.0)
  static const double cardBorderRadius = 16.0;

  /// Border radius for pill-shaped elements (fully rounded: 30.0)
  static const double pillBorderRadius = 30.0;

  /// Border radius for input fields (TextFormField, Dropdown, etc.: 12.0)
  static const double inputBorderRadius = 12.0;

  /// Border radius for badges and small UI elements (8.0)
  static const double badgeBorderRadius = 8.0;

  /// Border radius for dialogs and modals (20.0)
  static const double modalBorderRadius = 20.0;

  // ── Spacing ──────────────────────────────────────────────────────────────────

  /// Padding inferiore per le bottom sheet (evita sovrapposizione con elementi sotto)
  static const double bottomSheetBottomPadding = 24.0;

  /// Altezza fissa riservata per i tab contenuto filtri (AppPillTab standard).
  static const double pillTabDefault = 36.0;

  /// Altezza fissa per tab filtri compatti (raro).
  static const double pillTabCompact = 32.0;

  /// Altezza della riga delle 4 categorie (pillole con icona e nome), come
  /// gli elementi della barra in basso della casa.
  static const double categoryRowHeight = 50.0;

  /// Sfocatura del contenuto che scorre sotto un bottone galleggiante in fondo
  /// alla pagina (StickyCtaScaffold), e quanto lo copre il velo dello sfondo.
  static const double ctaBlurSigma = 16.0;
  static const double ctaScrimOpacity = 0.72;

  /// Altezza del bottone principale in fondo (DsButton) e dei bottoni che gli
  /// stanno accanto o al suo posto (es. "Avanti" del foglio AI).
  static const double ctaHeight = 56.0;

  /// Bordo più spesso del solito, per un contorno che deve farsi notare
  /// (es. il numero degli avvisi, "Prepara con AI").
  static const double emphasisBorderWidth = 2.0;

  /// Bordo tratteggiato (es. "Uguale a …"): lunghezza di un tratto e spazio
  /// tra due tratti.
  static const double dashLength = 4.0;
  static const double dashGap = 3.0;

  /// Altezza dei segmenti di avanzamento (es. le tappe del foglio AI).
  static const double progressSegmentHeight = 4.0;

  // ── AI Import ────────────────────────────────────────────────────────────────

  /// Width of score label column in AI result cards.
  static const double aiScoreLabelWidth = 76.0;
}
