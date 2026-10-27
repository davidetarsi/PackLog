import 'package:flutter/material.dart';
import '../model/item_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_opacity.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/surface_colors.dart';

enum CategoryPillState { inactive, inferred, forced }

class CategoryPill extends StatelessWidget {
  final ItemCategory category;
  final CategoryPillState pillState;
  final VoidCallback onTap;

  const CategoryPill({
    super.key,
    required this.category,
    required this.pillState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColor = colorScheme.primary;

    final Color backgroundColor;
    final Color foregroundColor;
    final Color borderColor;

    switch (pillState) {
      case CategoryPillState.inactive:
        // In chiaro il bianco delle card, staccato dalla pagina grigia.
        backgroundColor = Theme.of(context).brightness == Brightness.light
            ? context.groupSurface
            : colorScheme.surfaceContainerLow;
        foregroundColor = colorScheme.onSurfaceVariant;
        borderColor = Colors.transparent;
      // Proposta dall'app: solo il contorno, si legge come un suggerimento.
      case CategoryPillState.inferred:
        backgroundColor = Colors.transparent;
        foregroundColor = categoryColor;
        borderColor = categoryColor.withValues(alpha: AppOpacity.mutedBorder);
      // Scelta: fondo tenue, mai pieno. L'arancio pieno resta all'azione
      // principale dello schermo (regola "un solo arancio").
      case CategoryPillState.forced:
        backgroundColor = categoryColor.withValues(alpha: AppOpacity.selected);
        foregroundColor = categoryColor;
        borderColor = categoryColor;
    }

    // Icona sopra e nome intero sotto, come le voci della barra di
    // navigazione: con la pagina "aggiungi" lo spazio c'è e le iniziali
    // (V, T, E, ?) non servono più.
    return Semantics(
      button: true,
      selected: pillState == CategoryPillState.forced,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: EdgeInsets.symmetric(horizontal: context.spacingXs),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: borderColor,
              width: AppConstants.selectedBorderWidth,
            ),
            borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                category.icon,
                size: context.iconSizeSm,
                color: foregroundColor,
              ),
              SizedBox(height: context.spacingXxs),
              // scaleDown: con caratteri di sistema grandi o in inglese
              // ("Electronics") il nome si stringe invece di sforare.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  category.displayName,
                  maxLines: 1,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: foregroundColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
