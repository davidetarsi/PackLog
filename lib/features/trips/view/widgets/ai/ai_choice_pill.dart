import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';

/// Pillola compatta del foglio "Valigia con AI": alta 32 dp, testo
/// `labelLarge`, niente spunta. Scelta = bordo e testo `onSurface`; non scelta
/// = bordo `outlineVariant` e testo `onSurfaceVariant`. Sfondo sempre
/// trasparente. L'area toccabile è alta 48 dp anche se il riquadro è 32.
class AiChoicePill extends StatelessWidget {
  static const double _height = 32;
  static const double _tapHeight = 48;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AiChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = selected ? cs.onSurface : cs.onSurfaceVariant;

    return SizedBox(
      height: _tapHeight,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
          child: Center(
            child: Container(
              key: const ValueKey('ai_choice_pill_face'),
              height: _height,
              padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  AppConstants.pillBorderRadius,
                ),
                border: Border.all(
                  color: selected ? cs.onSurface : cs.outlineVariant,
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge?.copyWith(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
