import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';

/// Lo spegnimento attorno al posto aperto: con [active] il figlio scende a
/// [AppOpacity.disabled], non riceve tocchi (non si apre né si scorre via
/// nulla) e un tocco sopra chiama [onTapOutside], che richiude il posto.
///
/// L'opacità si muove con [AppMotion]; con le animazioni di sistema
/// disattivate cambia subito. Va messo anche quando non è attivo, così
/// accendersi e spegnersi si muovono nei due sensi.
class SlotFocus extends StatelessWidget {
  const SlotFocus({
    super.key,
    required this.active,
    required this.child,
    required this.onTapOutside,
  });

  final bool active;
  final Widget child;
  final VoidCallback onTapOutside;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: active ? onTapOutside : null,
      child: AbsorbPointer(
        absorbing: active,
        child: AnimatedOpacity(
          opacity: active ? AppOpacity.disabled : 1,
          duration: still ? Duration.zero : AppMotion.medium,
          curve: AppMotion.standard,
          child: child,
        ),
      ),
    );
  }
}
