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
///   trailing: DsQuantityBadge(current: 3),
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

  /// Callback al long press sulla tile (opzionale, es: delete)
  final VoidCallback? onLongPress;

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

  /// Se true (default) la tile è una **riga piatta con divisore inferiore**
  /// invece di una Card con sfondo e margine.
  ///
  /// In una lista fitta la Card ripetuta produce venti rettangoli staccati per
  /// schermata: peso visivo senza informazione. La riga piatta lascia al nome
  /// dell'oggetto l'unico accento.
  ///
  /// **Non si applica** quando il chiamante passa [borderColor]: in quel caso
  /// il bordo è semantico (selezione in `TripItemsSelector`, riquadro in
  /// `BulkItemRow`) e la tile resta un contenitore riquadrato.
  final bool dense;

  const UniversalItemTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showInTransitOverlay = false,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.useListTile = true,
    this.contentPadding,
    this.margin,
    this.dense = true,
  });

  /// La riga piatta vale solo senza bordo esplicito: con [borderColor] il
  /// riquadro porta significato e va preservato.
  bool get _isFlatRow => dense && borderColor == null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final cardChild = useListTile
        ? _buildListTileLayout(context)
        : _buildCustomRowLayout(context);

    Widget tile;

    if (_isFlatRow) {
      // Il divisore sta fuori dal Material perché l'ink dell'InkWell non lo
      // copra durante il tap.
      tile = Padding(
        padding: margin ?? EdgeInsets.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Material(
            color: backgroundColor ?? Colors.transparent,
            child: cardChild,
          ),
        ),
      );
    } else {
      tile = Card(
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: margin ?? EdgeInsets.only(bottom: context.spacingSm),
        color: backgroundColor,
        shape: borderColor != null
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.cardBorderRadius,
                ),
                side: BorderSide(
                  color: borderColor!,
                  width: borderWidth ?? 1.0,
                ),
              )
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.cardBorderRadius,
                ),
              ),
        child: cardChild,
      );
    }

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

  /// Altezza minima di una riga piatta. Sotto i 48 si scende sotto il target
  /// di tocco raccomandato; sopra, la lista torna a respirare troppo.
  static const double _flatRowMinHeight = 48;

  /// Layout standard usando ListTile (ItemCard, InTransitItemCard)
  Widget _buildListTileLayout(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      // Un minimo esplicito tiene uniformi le righe con e senza subtitle:
      // senza, la lista prende un ritmo irregolare quando il sottotitolo
      // compare solo su alcuni item.
      minTileHeight: _isFlatRow ? _flatRowMinHeight : null,
      contentPadding:
          contentPadding ??
          EdgeInsets.symmetric(horizontal: context.spacingMd, vertical: 0),
    );
  }

  /// Layout personalizzato usando Row (BulkItemRow, TripItemSelector)
  Widget _buildCustomRowLayout(BuildContext context) {
    final row = Padding(
      padding:
          contentPadding ??
          EdgeInsets.symmetric(
            horizontal: context.spacingMd,
            vertical: context.spacingXs,
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

    // Stessa ragione del minTileHeight: righe con e senza subtitle devono
    // partire dalla stessa altezza. Vale anche col bordo esplicito, dove il
    // subtitle condizionale del selettore oggetti è la fonte dell'irregolarità.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _flatRowMinHeight),
      child: Align(alignment: Alignment.centerLeft, child: row),
    );
  }
}
