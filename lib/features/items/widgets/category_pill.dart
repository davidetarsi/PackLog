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

    // Tutti gli stati hanno un fondo pieno: la lista degli oggetti scorre sotto
    // le pillole e non deve vedersi attraverso. In chiaro il bianco delle
    // card, staccato dalla pagina grigia.
    final base = Theme.of(context).brightness == Brightness.light
        ? context.groupSurface
        : colorScheme.surfaceContainerLow;

    switch (pillState) {
      case CategoryPillState.inactive:
        backgroundColor = base;
        foregroundColor = colorScheme.onSurfaceVariant;
        borderColor = Colors.transparent;
      // Proposta dall'app: il contorno la distingue, il fondo è quello delle
      // pillole inattive. Si legge come un suggerimento.
      case CategoryPillState.inferred:
        backgroundColor = base;
        foregroundColor = categoryColor;
        borderColor = categoryColor.withValues(alpha: AppOpacity.mutedBorder);
      // Scelta: velo tenue sopra il fondo pieno, mai arancio pieno. L'arancio
      // pieno resta all'azione principale dello schermo (regola "un solo
      // arancio").
      case CategoryPillState.forced:
        backgroundColor = Color.alphaBlend(
          categoryColor.withValues(alpha: AppOpacity.selected),
          base,
        );
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
