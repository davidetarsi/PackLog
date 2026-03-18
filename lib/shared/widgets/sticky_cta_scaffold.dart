import 'package:flutter/material.dart';
import 'package:stuff_tracker_2/shared/theme/app_spacing.dart';

/// Scaffold standardizzato con CTA (Call-To-Action) sticky in basso.
/// 
/// Fornisce un layout per wizard e form complessi dove:
/// - Il body è scrollabile
/// - Il CTA (bottoni/actions) rimane fisso in basso
/// - Lo Scaffold gestisce automaticamente il padding del body (niente sovrapposizioni!)
/// - SafeArea gestisce correttamente iOS Home Indicator e Android Nav Bar
class StickyCtaScaffold extends StatelessWidget {
  /// AppBar opzionale
  final PreferredSizeWidget? appBar;

  /// Contenuto scrollabile principale
  final Widget body;

  /// CTA sticky in basso (bottoni, form controls)
  final Widget bottomContent;

  /// Colore di background del CTA (default: surface)
  final Color? ctaBackgroundColor;

  /// Se true, aggiunge un'ombra sopra il CTA per separarlo visivamente
  final bool showCtaShadow;

  /// Padding interno del contenitore CTA. 
  /// Se null, applica il padding standard: top 16, bottom 8, orizzontale 16.
  final EdgeInsetsGeometry? ctaPadding;

  const StickyCtaScaffold({
    super.key,
    this.appBar,
    required this.body,
    required this.bottomContent,
    this.ctaBackgroundColor,
    this.showCtaShadow = true,
    this.ctaPadding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: appBar,
      body: body, // Il framework calcola in automatico lo spazio per non andare sotto il CTA
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ctaBackgroundColor ?? colorScheme.surface,
          boxShadow: showCtaShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ]
              : null,
        ),
        child: SafeArea(
          child: Padding(
            padding: ctaPadding ?? EdgeInsets.only(
              left: context.spacingMd,
              right: context.spacingMd,
              top: context.spacingMd,
              bottom: context.spacingSm, // <-- Questo abbassa i bottoni e riduce lo spessore della banda
            ),
            child: bottomContent,
          ),
        ),
      ),
    );
  }
}