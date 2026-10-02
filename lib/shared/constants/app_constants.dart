// Regola border radius (DS Phase 1):
// - Token noti (cardBorderRadius, pillBorderRadius, …) → BorderRadius.circular(AppConstants.X) raw.
//   Scalare con responsiveBorderRadius su token noti è impercettibile e aggiunge complessità.
// - Valori contestuali/magici (es. cardBorderRadius + 4) → context.responsiveBorderRadius(X).
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

  // ── AI Import ────────────────────────────────────────────────────────────────

  /// Width of score label column in AI result cards.
  static const double aiScoreLabelWidth = 76.0;
}
