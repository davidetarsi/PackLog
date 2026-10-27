import 'package:flutter/material.dart';
import 'package:inspire_blur/inspire_blur.dart';

import '../constants/app_constants.dart';
import '../theme/app_motion.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';

/// Effetto sul bordo in fondo allo schermo, dietro i bottoni, la barra delle
/// tab e il piè dei fogli: lo "scroll edge effect" morbido di Liquid Glass.
/// Niente fascia con un bordo: il contenuto che scorre sotto si sfoca e
/// sfuma nel colore di fondo sempre di più verso il bordo. L'effetto parte
/// appena sopra i controlli, a [topGap].
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

  /// Spazio fra il bordo alto dell'area dei controlli e i controlli: è da lì
  /// che parte la sfumatura.
  static double topGap(BuildContext context) => context.spacingXs;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surface;
    return Stack(
      children: [
        Positioned.fill(
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
