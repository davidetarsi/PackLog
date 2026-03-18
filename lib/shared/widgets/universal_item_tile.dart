import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Universal layout engine per tutte le tile di oggetti nell'app.
/// 
/// Questo widget fornisce un layout unificato e riutilizzabile per:
/// - `ItemCard` (casa): icon categoria + nome + badge + quantity
/// - `InTransitItemCard` (in transito): background speciale + shipping info
/// - `BulkItemRow` (bulk creation): TextField inline + stepper + delete
/// - Trip item selector: icon + nome + checkbox/stepper
/// 
/// **Pattern**: Composition over Inheritance (Wrapper Pattern)
/// Le card specifiche wrappano questo widget, passando la loro logica
/// nei vari slot, preservando il loro stato e comportamento.
/// 
/// Esempio:
/// ```dart
/// UniversalItemTile(
///   leading: Icon(Icons.category),
///   title: Text('Item Name'),
///   subtitle: Text('Description'),
///   trailing: QuantityBadge(quantity: 3),
///   onTap: () => showDetails(),
/// )
/// ```
class UniversalItemTile extends StatelessWidget {
  /// Widget leading (icona categoria, checkbox, etc)
  final Widget? leading;

  /// Widget title (nome item come Text o TextField)
  final Widget title;

  /// Widget subtitle opzionale (descrizione, shipping info, etc)
  final Widget? subtitle;

  /// Widget trailing (badge, stepper, menu, etc)
  final Widget? trailing;

  /// Se true, mostra overlay per status "in transito"
  final bool showInTransitOverlay;

  /// Callback al tap sulla tile (opzionale)
  final VoidCallback? onTap;

  /// Colore background custom (default: theme surface)
  final Color? backgroundColor;

  /// Colore bordo custom (default: nessuno)
  final Color? borderColor;

  /// Larghezza bordo (default: 1.0)
  final double? borderWidth;

  /// Se true usa ListTile, altrimenti Row personalizzata (per TextField)
  final bool useListTile;

  /// Padding interno custom (default: theme spacing)
  final EdgeInsets? contentPadding;

  /// Margin esterno (default: bottom spacingSm)
  final EdgeInsets? margin;

  const UniversalItemTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showInTransitOverlay = false,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.useListTile = true,
    this.contentPadding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final cardChild = useListTile
        ? _buildListTileLayout(context)
        : _buildCustomRowLayout(context);

    Widget tile = Card(
      margin: margin ?? EdgeInsets.only(bottom: context.spacingSm),
      color: backgroundColor,
      shape: borderColor != null
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
              side: BorderSide(
                color: borderColor!,
                width: borderWidth ?? 1.0,
              ),
            )
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
            ),
      child: cardChild,
    );

    // Aggiungi overlay se richiesto
    if (showInTransitOverlay) {
      tile = Stack(
        children: [
          tile,
          Positioned(
            top: 8,
            right: 8,
            child: Icon(
              Icons.local_shipping,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
        ],
      );
    }

    return tile;
  }

  /// Layout standard usando ListTile (ItemCard, InTransitItemCard)
  Widget _buildListTileLayout(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      contentPadding: contentPadding,
    );
  }

  /// Layout personalizzato usando Row (BulkItemRow, TripItemSelector)
  Widget _buildCustomRowLayout(BuildContext context) {
    return Padding(
      padding: contentPadding ??
          EdgeInsets.symmetric(
            horizontal: context.spacingMd,
            vertical: context.spacingSm,
          ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: context.spacingSm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (subtitle != null) ...[
                  SizedBox(height: context.spacingXs),
                  subtitle!,
                ],
              ],
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
}
