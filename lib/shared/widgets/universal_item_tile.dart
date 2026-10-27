import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'ds_divider.dart';

/// Universal layout engine per tutte le tile di oggetti nell'app.
///
/// Questo widget fornisce un layout unificato e riutilizzabile per:
/// - `ItemCard` (casa): icon categoria + nome + badge + quantity
/// - `InTransitItemCard` (in transito): background speciale + shipping info
/// - Trip item selector: icon + nome + checkbox/stepper
///
/// La riga è sempre piatta, con un divisore inferiore: niente Card né bordo.
/// Una Card per ogni item, in una lista fitta, produce rettangoli staccati
/// senza informazione, e lascia al nome dell'oggetto l'unico accento.
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

  /// Colore di sfondo della riga (default: trasparente)
  final Color? backgroundColor;

  /// Se true usa ListTile, altrimenti Row personalizzata (per TextField)
  final bool useListTile;

  /// Padding interno custom (default: theme spacing)
  final EdgeInsets? contentPadding;

  /// Margine esterno della riga (default: nessuno)
  final EdgeInsets? margin;

  /// Rientro del divisore per le righe piatte.
  final EdgeInsets dividerInsets;

  /// L'ultima riga di un gruppo può non avere divisore.
  final bool showDivider;

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
    this.useListTile = true,
    this.contentPadding,
    this.margin,
    this.dividerInsets = EdgeInsets.zero,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = useListTile
        ? _buildListTileLayout(context)
        : _buildCustomRowLayout(context);

    // Il divisore sta fuori dal Material perché l'ink dell'InkWell non lo
    // copra durante il tap.
    Widget tile = Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: backgroundColor ?? Colors.transparent,
            child: content,
          ),
          if (showDivider) Padding(padding: dividerInsets, child: DsDivider()),
        ],
      ),
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
              size: context.iconSizeMd,
              color: colorScheme.primary,
            ),
          ),
        ],
      );
    }

    return tile;
  }

  /// Altezza minima di una riga piatta.
  ///
  /// 56 è l'altezza Material di una voce di lista a una riga; 48 — il valore
  /// precedente — è il minimo per il target di tocco, non una misura di
  /// comfort. Con le righe ormai prive di card e sfondo, quegli 8px in più
  /// sono l'unica cosa che separa una voce dall'altra.
  static const double _flatRowMinHeight = 56;

  /// Layout standard usando ListTile (ItemCard, InTransitItemCard)
  Widget _buildListTileLayout(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: leading,
      title: title,
      // Qualche pixel fra titolo e sottotitolo: senza, il dato primario e lo
      // stato si leggono come un blocco unico invece che come due livelli.
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: EdgeInsets.only(top: context.spacingXxs),
              child: subtitle,
            ),
      trailing: trailing,
      // Un minimo esplicito tiene uniformi le righe con e senza subtitle:
      // senza, la lista prende un ritmo irregolare quando il sottotitolo
      // compare solo su alcuni item.
      minTileHeight: _flatRowMinHeight,
      // Il padding verticale non può essere 0: con le card era il loro margine
      // a dare respiro, ma su una riga piatta uno zero qui significa che una
      // riga a due linee non ha alcuno spazio interno — e finisce per essere
      // più stretta di una a una linea, che il minimo spinge comunque a 56.
      contentPadding:
          contentPadding ??
          EdgeInsets.symmetric(
            horizontal: context.spacingMd,
            vertical: context.spacingSm,
          ),
    );
  }

  /// Layout personalizzato usando Row (TripItemSelector)
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
    // partire dalla stessa altezza.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _flatRowMinHeight),
      child: Align(alignment: Alignment.centerLeft, child: row),
    );
  }
}
