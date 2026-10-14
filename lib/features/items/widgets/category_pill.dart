import 'package:flutter/material.dart';
import '../model/item_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_spacing.dart';

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
        backgroundColor = colorScheme.surfaceContainerLow;
        foregroundColor = colorScheme.onSurfaceVariant;
        borderColor = Colors.transparent;
      case CategoryPillState.inferred:
        backgroundColor = categoryColor.withValues(alpha: 0.1);
        foregroundColor = categoryColor;
        borderColor = categoryColor;
      case CategoryPillState.forced:
        backgroundColor = categoryColor;
        foregroundColor = colorScheme.onPrimary;
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
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: context.spacingXs),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1.5),
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
              SizedBox(height: context.spacingXs / 4),
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
