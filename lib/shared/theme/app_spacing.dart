import 'package:flutter/material.dart';

/// Classe per gestire spaziature e dimensioni responsive.
/// Usa questi valori invece di numeri magici per mantenere proporzioni consistenti.
class AppSpacing {
  // === Spaziature base ===
  // Micro-spazi di 1-2 px tra elementi già vicini.
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  // Tra sm e md: pillole e righe con più testo.
  static const double smPlus = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  // === Dimensioni icone base ===
  // Icona accanto a testo piccolo (badge, riga compatta).
  static const double iconXs = 12;
  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 48;
  static const double iconHero = 64;
  // Illustrazione grande (login, onboarding).
  static const double iconDisplay = 80;

  // === Font size base ===
  // Floor: fontXxs = 12px. Mai scendere sotto.
  //
  // La fonte di verità per la tipografia è il `textTheme` in app_theme.dart:
  // preferisci `Theme.of(context).textTheme.<slot>` a questi token grezzi.
  // I token restano per i casi che nessuno slot copre (icone, emoji hero) e
  // sono i valori su cui il textTheme è costruito.
  //
  // Regola size → weight allineata al textTheme:
  //   headline/title → w600 | label → w500 (w600 sui badge a 12px) | body → w400
  // Sostituisce la regola "DS Fase 3" (18–22px → w700, 14–16px → w500): il w700
  // sui titoli a 20px era una delle cause del peso visivo che stiamo togliendo.
  static const double fontXxs =
      12; // Floor assoluto: badge, micro-label, timestamp
  static const double fontXs = 14;
  static const double fontSm = 16;
  static const double fontMd = 18;
  static const double fontLg = 20;
  static const double fontXl = 22;
  static const double fontTitle = 24;
  static const double fontHeading = 28;
  static const double fontDisplay = 32; // Display / emoji hero size

  // === Padding predefiniti ===

  /// Padding semantico per card eroiche/isolate (una per schermata o in liste poco fitte).
  /// Casi d'uso: HouseCard, TemplateCard, card date TripInfoForm.
  static const EdgeInsets cardPaddingHero = EdgeInsets.all(md); // 16

  /// Padding semantico per item ad alta frequenza in lista (UniversalItemTile, ListTile).
  static const EdgeInsets cardPaddingDense = EdgeInsets.all(sm); // 8

  // Regola di scelta:
  // • Hero  (16): card "grande" o card in lista poco fitta.
  // • Dense  (8): item in lista ad alta frequenza.
  // Il valore 12 (spacingSm + 4) è eliminato. Ogni caso va mappato su Hero o Dense.
}

/// Extension per calcolare valori responsive basati sulla larghezza dello schermo.
/// Mantiene le proporzioni degli elementi al variare delle dimensioni del dispositivo.
extension ResponsiveSpacing on BuildContext {
  /// Larghezza dello schermo
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Altezza dello schermo
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Fattore di scala basato sulla larghezza (1.0 per schermo da 375px)
  double get scaleFactor {
    const baseWidth = 375.0;
    const minScale = 0.85;
    const maxScale = 1.3;
    final scale = screenWidth / baseWidth;
    return scale.clamp(minScale, maxScale);
  }

  /// Fattore di scala per font. Costante 1.0: i token font NON scalano con la
  /// larghezza dello schermo.
  ///
  /// Perché è stato disattivato (era `clamp(0.9, 1.15)` su `screenWidth/375`):
  /// 1. **Accessibilità**: il floor a 0.9 *rimpiccioliva* il testo sui telefoni
  ///    stretti (≤ 337dp), cioè proprio dove leggere è più difficile. La scala
  ///    per larghezza può al più ingrandire, mai ridurre.
  /// 2. **Coerenza con il textTheme**: `ThemeData` si costruisce senza
  ///    `BuildContext`, quindi `textTheme` non può essere scalato. Tenere i
  ///    getter `fontSize*` scalati avrebbe fatto divergere i due binari fino
  ///    all'8% a seconda del device — lo stesso doppio binario che il
  ///    textTheme esplicito serve a eliminare.
  /// 3. La dimensione del testo è una preferenza dell'utente, non del device:
  ///    ci pensa già `MediaQuery.textScaler` (mai sovrascritto in questa app).
  ///
  /// I token in [AppSpacing] valgono quindi esattamente il numero che dichiarano.
  double get fontScaleFactor => 1.0;

  // === Spaziature responsive ===

  double get spacingXxs => AppSpacing.xxs * scaleFactor;
  double get spacingXs => AppSpacing.xs * scaleFactor;
  double get spacingSm => AppSpacing.sm * scaleFactor;
  double get spacingSmPlus => AppSpacing.smPlus * scaleFactor;
  double get spacingMd => AppSpacing.md * scaleFactor;
  double get spacingLg => AppSpacing.lg * scaleFactor;
  double get spacingXl => AppSpacing.xl * scaleFactor;

  // === Icone responsive ===

  double get iconSizeXs => AppSpacing.iconXs * scaleFactor;
  double get iconSizeSm => AppSpacing.iconSm * scaleFactor;
  double get iconSizeMd => AppSpacing.iconMd * scaleFactor;
  double get iconSizeLg => AppSpacing.iconLg * scaleFactor;
  double get iconSizeXl => AppSpacing.iconXl * scaleFactor;
  double get iconSizeHero => AppSpacing.iconHero * scaleFactor;
  double get iconSizeDisplay => AppSpacing.iconDisplay * scaleFactor;

  // === Font responsive ===

  double get fontSizeXs => AppSpacing.fontXs * fontScaleFactor;

  // === Padding responsive ===

  /// Padding semantico responsive per card eroiche/isolate.
  /// Corrisponde ad AppSpacing.cardPaddingHero scalato al device.
  EdgeInsets get cardPaddingHero => EdgeInsets.all(spacingMd);

  /// Padding semantico responsive per item ad alta frequenza in lista.
  /// Corrisponde ad AppSpacing.cardPaddingDense scalato al device.
  EdgeInsets get cardPaddingDense => EdgeInsets.all(spacingSm);

  // === BorderRadius responsive ===

  BorderRadius responsiveBorderRadius(double radius) =>
      BorderRadius.circular(radius * scaleFactor);

  // === Utility per valori arbitrari ===

  /// Scala un valore arbitrario in base alla larghezza dello schermo
  double responsive(double value) => value * scaleFactor;

  /// Scala un valore arbitrario per i font
  double responsiveFont(double value) => value * fontScaleFactor;
}

/// Widget helper per creare gap verticali responsive
class ResponsiveGap extends StatelessWidget {
  final double height;

  const ResponsiveGap(this.height, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: context.responsive(height));
  }
}

/// Widget helper per creare gap orizzontali responsive
class ResponsiveHGap extends StatelessWidget {
  final double width;

  const ResponsiveHGap(this.width, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: context.responsive(width));
  }
}
