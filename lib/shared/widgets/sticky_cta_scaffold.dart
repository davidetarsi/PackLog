import 'package:flutter/material.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/theme/cta_reserved_space.dart';
import 'package:pack_log/shared/widgets/ds_glass_band.dart';

/// Scaffold standardizzato con CTA (Call-To-Action) flottante in basso.
///
/// Fornisce un layout per wizard e form complessi dove:
/// - Il body è scrollabile e arriva fino in fondo allo schermo (`extendBody`)
/// - Il CTA (bottoni/actions) resta fisso in basso, sopra il body che scorre
///   sotto
/// - I bottoni stanno su una [DsGlassBand], la stessa fascia di vetro della
///   barra delle tab: il body che scorre sotto si vede sfocato e appena
///   velato. Quell'area non è cliccabile verso il contenuto sotto
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
    this.ctaPadding,
    this.ctaHeightOverride,
  });

  /// Altezza standard di una CTA a riga singola: safe-area + `ctaPadding`
  /// di default (top spacingMd, bottom spacingSm) + altezza del pill button
  /// ([AppConstants.ctaHeight], la stessa usata dalla pill di [MainShell]).
  ///
  /// Pubblico e statico così una schermata con una CTA più alta (righe
  /// impilate) può comporre il proprio `ctaHeightOverride` a partire da
  /// questo valore invece di duplicare la formula.
  static double standardHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom +
      DsGlassBand.topGap(context) +
      context.spacingSm +
      context.responsive(AppConstants.ctaHeight);

  @override
  Widget build(BuildContext context) {
    final reservedHeight = bottomContent == null
        ? 0.0
        : (ctaHeightOverride ?? standardHeight(context));

    return Scaffold(
      appBar: appBar,
      // Il body scorre FINO in fondo, anche sotto l'area CTA (che di default
      // è trasparente). Su questo punto — e solo su questo — l'analogia con
      // MainShell regge: anche lì il contenuto passa sotto la barra.
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
          : _ctaArea(context),
    );
  }

  /// L'area dei bottoni, sulla fascia di vetro comune.
  Widget _ctaArea(BuildContext context) {
    return DsGlassBand(
      child: SafeArea(
        child: Padding(
          padding:
              ctaPadding ??
              EdgeInsets.only(
                left: context.spacingMd,
                right: context.spacingMd,
                top: DsGlassBand.topGap(context),
                bottom: context.spacingSm,
              ),
          child: bottomContent,
        ),
      ),
    );
  }
}
