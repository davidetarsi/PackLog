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
        foregroundColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForCategory(category), size: 16, color: foregroundColor),
            const SizedBox(width: 6),
            Text(
              _labelForCategory(category),
              style: TextStyle(
                fontSize: context.fontSizeXs,
                fontWeight: FontWeight
                    .w600, // 14px selected → w500 base + 1 livello selezionato
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForCategory(ItemCategory category) {
    return switch (category) {
      ItemCategory.vestiti => Icons.checkroom,
      ItemCategory.toiletries => Icons.soap,
      ItemCategory.elettronica => Icons.devices,
      ItemCategory.varie => Icons.category,
    };
  }

  static String _labelForCategory(ItemCategory category) {
    return switch (category) {
      ItemCategory.vestiti => 'V',
      ItemCategory.toiletries => 'T',
      ItemCategory.elettronica => 'E',
      ItemCategory.varie => '?',
    };
  }
}
