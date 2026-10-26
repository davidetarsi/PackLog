import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Pillola di scelta compatta: bordo e testo, niente icone.
///
/// La faccia è alta [AppConstants.pillTabCompact], ma l'area di tocco è almeno
/// [kMinInteractiveDimension]. Scelta: bordo e testo onSurface, e nel tema
/// chiaro anche lo sfondo surfaceContainerHigh. Non scelta: bordo
/// outlineVariant, testo onSurfaceVariant, senza sfondo.
///
/// Lo stato di selezione lo decide il chiamante (vedi [DsChoiceGroup]).
class DsChoicePill extends StatelessWidget {
  final String label;
  final bool selected;

  /// `null` = pillola disabilitata.
  final VoidCallback? onTap;

  const DsChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final radius = BorderRadius.circular(AppConstants.pillBorderRadius);

    return Semantics(
      button: true,
      selected: selected,
      child: SizedBox(
        height: kMinInteractiveDimension,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Center(
              widthFactor: 1,
              child: Container(
                key: const Key('ds_choice_pill_face'),
                height: AppConstants.pillTabCompact,
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacingSm + context.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: selected && isLight ? cs.surfaceContainerHigh : null,
                  borderRadius: radius,
                  border: Border.all(
                    color: selected ? cs.onSurface : cs.outlineVariant,
                  ),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
