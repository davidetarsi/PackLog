import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import '../theme/surface_colors.dart';
import 'ds_dashed_box.dart';

/// Pillola di scelta compatta: bordo e testo, niente icone.
///
/// La faccia è alta [AppConstants.pillTabCompact], ma l'area di tocco è almeno
/// [kMinInteractiveDimension]. Scelta: bordo e testo onSurface, e nel tema
/// chiaro anche lo sfondo surfaceContainerHigh. Non scelta: bordo
/// outlineVariant, testo onSurfaceVariant; nel tema chiaro sullo sfondo
/// bianco delle card, che la stacca dalla pagina grigia.
///
/// Lo stato di selezione lo decide il chiamante (vedi [DsChoiceGroup]).
/// Con [dashed] il bordo è tratteggiato: un valore proposto dall'AI e da
/// controllare, senza aggiungere colore.
class DsChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dashed;

  /// `null` = pillola disabilitata.
  final VoidCallback? onTap;

  const DsChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dashed = false,
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
              child: _maybeDashed(
                color: selected ? cs.onSurface : cs.outlineVariant,
                child: Container(
                  key: const Key('ds_choice_pill_face'),
                  height: AppConstants.pillTabCompact,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacingSmPlus,
                  ),
                  decoration: BoxDecoration(
                    color: !isLight
                        ? null
                        : selected
                        ? cs.surfaceContainerHigh
                        : context.groupSurface,
                    borderRadius: radius,
                    border: dashed
                        ? null
                        : Border.all(
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
      ),
    );
  }

  Widget _maybeDashed({required Color color, required Widget child}) => dashed
      ? DsDashedBox(
          key: const Key('ds_choice_pill_dashed'),
          radius: AppConstants.pillBorderRadius,
          color: color,
          child: child,
        )
      : child;
}
