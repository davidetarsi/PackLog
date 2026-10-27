import 'package:flutter/material.dart';
import 'package:inspire_blur/inspire_blur.dart';

import '../constants/app_constants.dart';
import '../theme/app_motion.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';

/// Effetto sul bordo in fondo allo schermo, dietro i bottoni, la barra delle
/// tab e il piè dei fogli: lo "scroll edge effect" morbido di Liquid Glass.
/// Niente fascia con un bordo: il contenuto che scorre sotto si sfoca e
/// sfuma nel colore di fondo sempre di più verso il bordo. L'effetto parte un
/// po' sopra i controlli ([rise]), così non si vede dove comincia.
///
/// La sfocatura cresce in modo continuo grazie a uno shader (inspire_blur):
/// con i BackdropFilter a strati si vedevano i gradini. Gli shader non girano
/// nei test, dove resta visibile solo la sfumatura di colore.
///
/// Il [ColoredBox] trasparente intercetta i tocchi nell'area dei controlli:
/// lo spazio attorno a loro non è cliccabile verso il contenuto sotto.
class DsGlassBand extends StatelessWidget {
  const DsGlassBand({super.key, required this.child});

  /// I controlli, già con il loro padding e la safe area.
  final Widget child;

  /// Spazio fra il bordo alto dell'area dei controlli e i controlli.
  static double topGap(BuildContext context) => context.spacingXs;

  /// Quanto sopra l'area dei controlli comincia la sfumatura.
  static double rise(BuildContext context) => context.spacingXl;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surface;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          top: -rise(context),
          child: IgnorePointer(
            child: Stack(
              key: const Key('ds_glass_band_edge'),
              fit: StackFit.expand,
              children: [
                Inspire.backdropBlur(
                  config: InspireBlurConfig.bottomToTop(
                    sigma: AppConstants.ctaBlurSigma,
                    fadeCurve: AppMotion.linear,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withAlpha(0),
                        color.withValues(alpha: AppOpacity.edgeTint),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ColoredBox(color: Colors.transparent, child: child),
      ],
    );
  }
}
