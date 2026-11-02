import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';

/// Lo spazio in fondo alla lista con un posto aperto: alto come la vista, per
/// portare in cima anche l'ultimo gruppo.
///
/// All'apertura è intera subito; alla chiusura si restringe con
/// [AppMotion.medium] invece di sparire: se il gruppo aperto era l'ultimo, la
/// pagina non salta. Con le animazioni di sistema spente sparisce subito.
class SlotEndSpacer extends StatelessWidget {
  const SlotEndSpacer(this.open, this.height, {super.key});

  final bool open;
  final double height;

  /// Quanto dura il restringimento (zero con le animazioni spente).
  static Duration settle(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : AppMotion.medium;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: const Key('slot_end_spacer'),
      // All'apertura serve subito intera: la card sale in cima con lo scroll.
      duration: open ? Duration.zero : settle(context),
      curve: AppMotion.standard,
      height: open ? height : 0,
    );
  }
}
