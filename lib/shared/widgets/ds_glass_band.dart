import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Fascia di vetro in fondo allo schermo, dietro i bottoni e la barra delle
/// tab: il contenuto che scorre sotto si vede sfocato, senza velo, così si
/// capisce che la pagina continua senza che il testo disturbi i controlli.
/// È l'unica fascia in fondo dell'app.
///
/// Il [ColoredBox] trasparente intercetta i tocchi in tutta l'area: lo spazio
/// attorno ai controlli non è cliccabile verso il contenuto sotto.
class DsGlassBand extends StatelessWidget {
  const DsGlassBand({super.key, required this.child});

  /// I controlli, già con il loro padding e la safe area.
  final Widget child;

  /// Spazio fra il bordo alto della fascia e i controlli: basso, così sotto
  /// la sfocatura passa poco contenuto, ma non zero, così una card o una
  /// scritta non finisce esattamente sul bordo del bottone.
  static double topGap(BuildContext context) => context.spacingXs;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppConstants.ctaBlurSigma,
          sigmaY: AppConstants.ctaBlurSigma,
        ),
        child: ColoredBox(color: Colors.transparent, child: child),
      ),
    );
  }
}
