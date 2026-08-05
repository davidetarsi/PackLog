import 'package:flutter/material.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/theme/cta_reserved_space.dart';

/// Scaffold standardizzato con CTA (Call-To-Action) flottante in basso.
///
/// Fornisce un layout per wizard e form complessi dove:
/// - Il body è scrollabile e arriva fino in fondo allo schermo (`extendBody`)
/// - Il CTA (bottoni/actions) resta fisso in basso, sopra il body che scorre
///   sotto — stesso pattern della nav bar flottante di [MainShell]
/// - Con `ctaBackgroundColor` non impostato (default trasparente) il body
///   scrollato resta visibile nell'area attorno ai bottoni; quell'area non è
///   comunque cliccabile verso il contenuto sotto (vedi commento nel `build`)
/// - SafeArea gestisce correttamente iOS Home Indicator e Android Nav Bar
///
/// L'ultimo contenuto del body può finire visivamente sotto l'area CTA quando
/// si scorre fino in fondo. Per evitare che l'ultimo elemento di una lista
/// resti permanentemente coperto (e quindi non cliccabile), l'altezza della
/// CTA viene esposta ai discendenti di `body` tramite `context.ctaReservedHeight`
/// ([CtaReservedSpaceScope]): le schermate con una scrollable la sommano al
/// proprio padding/spacer finale, così l'ultimo elemento può essere scrollato
/// sopra la CTA invece di restarci sotto per sempre (stesso concetto della
/// "riga vuota" in append che Telegram mette in fondo alla lista chat).
///
/// L'altezza è calcolata staticamente (safe-area + `ctaPadding` di default +
/// altezza standard del pill button) perché tutte le schermate tranne una
/// usano una `UniversalActionBar` a riga singola della stessa altezza. Per
/// una CTA più alta (es. righe impilate) passa `ctaHeightOverride`.
class StickyCtaScaffold extends StatelessWidget {
  /// AppBar opzionale
  final PreferredSizeWidget? appBar;

  /// Contenuto scrollabile principale
  final Widget body;

  /// CTA sticky in basso (bottoni, form controls). Se null, non viene mostrata
  /// nessuna barra e il body occupa tutto lo spazio disponibile.
  final Widget? bottomContent;

  /// Colore di background dell'area CTA (default: trasparente — i bottoni
  /// "galleggiano" sopra il body che scorre sotto, come la nav bar flottante
  /// di [MainShell]). Passare un colore esplicito solo se serve un'area CTA
  /// opaca invece che flottante.
  final Color? ctaBackgroundColor;

  /// Padding interno del contenitore CTA.
  /// Se null, applica il padding standard: top 16, bottom 8, orizzontale 16.
  final EdgeInsetsGeometry? ctaPadding;

  /// Override dell'altezza riservata (`context.ctaReservedHeight`) per CTA
  /// più alte dello standard a riga singola (es. righe impilate). Se null,
  /// usa l'altezza standard calcolata da [_standardCtaHeight].
  final double? ctaHeightOverride;

  const StickyCtaScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomContent,
    this.ctaBackgroundColor,
    this.ctaPadding,
    this.ctaHeightOverride,
  });

  /// Altezza standard di una CTA a riga singola: safe-area + `ctaPadding`
  /// di default (top spacingMd, bottom spacingSm) + altezza del pill button
  /// (`responsive(56)`, la stessa usata dalla pill di [MainShell]).
  ///
  /// Pubblico e statico così una schermata con una CTA più alta (righe
  /// impilate) può comporre il proprio `ctaHeightOverride` a partire da
  /// questo valore invece di duplicare la formula.
  static double standardHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom +
      context.spacingMd +
      context.spacingSm +
      context.responsive(56);

  @override
  Widget build(BuildContext context) {
    final reservedHeight = bottomContent == null
        ? 0.0
        : (ctaHeightOverride ?? standardHeight(context));

    return Scaffold(
      appBar: appBar,
      // Il body scorre FINO in fondo, anche sotto l'area CTA (che di default
      // è trasparente): stesso pattern di MainShell per la nav bar flottante.
      // Senza extendBody, il framework riserverebbe automaticamente spazio
      // per il CTA e il body non arriverebbe mai a mostrarsi dietro di esso
      // — rendendo un ctaBackgroundColor trasparente indistinguibile dallo
      // sfondo pieno del Scaffold (nulla da "rivelare" sotto).
      extendBody: true,
      body: CtaReservedSpaceScope(height: reservedHeight, child: body),
      bottomNavigationBar: bottomContent == null
          ? null
          // Container con `color` (anche trasparente) intercetta comunque
          // i tap in tutta la sua area — Flutter non esclude l'hit-test in
          // base all'opacità del paint. Lo spazio attorno ai bottoni resta
          // quindi "non cliccabile" verso il contenuto sotto, per design,
          // senza bisogno di IgnorePointer/AbsorbPointer.
          //
          // Niente BoxShadow qui: su un Container trasparente una BoxShadow
          // dipinge una copia sfumata dell'INTERA sagoma rettangolare dietro
          // di sé — per un rettangolo alto quanto tutta l'area CTA, quel
          // riempimento resta a piena opacità fuori dai pochi px di bordo
          // sfumato, tingendo di nero un'area che dovrebbe restare trasparente.
          : Container(
              color: ctaBackgroundColor ?? Colors.transparent,
              child: SafeArea(
                child: Padding(
                  padding:
                      ctaPadding ??
                      EdgeInsets.only(
                        left: context.spacingMd,
                        right: context.spacingMd,
                        top: context.spacingMd,
                        bottom: context.spacingSm,
                      ),
                  child: bottomContent,
                ),
              ),
            ),
    );
  }
}
