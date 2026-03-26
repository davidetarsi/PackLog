import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../features/items/model/item_model.dart';
import '../theme/app_spacing.dart';

/// Widget riutilizzabile per l'intestazione di una sezione di categoria.
/// 
/// Mostra un'icona e il nome della categoria, con un trailing widget opzionale
/// (es: badge con conteggio item).
/// 
/// Esempio base:
/// ```dart
/// CategorySectionHeader(
///   category: ItemCategory.vestiti,
/// )
/// ```
/// 
/// Esempio con trailing:
/// ```dart
/// CategorySectionHeader(
///   category: ItemCategory.elettronica,
///   trailing: Text('3 items'),
/// )
/// ```
class CategorySectionHeader extends StatelessWidget {
  /// Categoria da visualizzare
  final ItemCategory category;

  /// Widget opzionale da mostrare a destra (es: badge, count)
  final Widget? trailing;

  /// Dimensione dell'icona (se null, usa la dimensione responsive)
  final double? iconSize;

  /// Colore dell'icona e del testo (se null, usa primary del tema)
  final Color? color;

  /// Padding orizzontale della sezione
  final double? horizontalPadding;

  /// Padding verticale della sezione
  final double? verticalPadding;

  const CategorySectionHeader({
    super.key,
    required this.category,
    this.trailing,
    this.iconSize,
    this.color,
    this.horizontalPadding,
    this.verticalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;
    final effectiveIconSize = iconSize ?? context.responsive(20);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding ?? context.spacingSm,
        vertical: verticalPadding ?? context.spacingXs,
      ),
      child: Row(
        children: [
          Icon(
            _getCategoryIcon(category),
            size: effectiveIconSize,
            color: effectiveColor,
          ),
          SizedBox(width: context.spacingSm),
          Expanded(
            child: Text(
              _getCategoryName(category),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: context.spacingSm),
            trailing!,
          ],
        ],
      ),
    );
  }

  IconData _getCategoryIcon(ItemCategory category) {
    switch (category) {
      case ItemCategory.vestiti:
        return Icons.checkroom;
      case ItemCategory.toiletries:
        return Icons.soap;
      case ItemCategory.elettronica:
        return Icons.devices;
      case ItemCategory.varie:
        return Icons.category;
    }
  }

  String _getCategoryName(ItemCategory category) {
    switch (category) {
      case ItemCategory.vestiti:
        return 'items.category_vestiti'.tr();
      case ItemCategory.toiletries:
        return 'items.category_toiletries'.tr();
      case ItemCategory.elettronica:
        return 'items.category_elettronica'.tr();
      case ItemCategory.varie:
        return 'items.category_varie'.tr();
    }
  }
}
