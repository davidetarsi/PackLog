import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/quantity_stepper.dart';
import '../../../../items/model/item_model.dart';
import '../../../model/trip_model.dart';

/// Pillola neutra della valigia: bagagli e casa. Se scelta ha sfondo
/// trasparente, bordo e testo `onSurface`; altrimenti bordo `outlineVariant`.
/// L'icona resta la sua, senza spunta. Niente arancio: lo porta solo "Fatto".
class PackPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;

  /// `null` rende la pillola inerte (il selettore con una casa sola).
  final VoidCallback? onTap;

  const PackPill({
    super.key,
    required this.label,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
        side: BorderSide(color: selected ? cs.onSurface : cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacingMd,
            vertical: context.spacingSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: context.iconSizeSm,
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
              ),
              SizedBox(width: context.spacingXs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge?.copyWith(
                  color: selected ? cs.onSurface : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riga di un oggetto della casa mostrata: casella, nome e, se l'oggetto è
/// scelto e ha più di un pezzo disponibile, lo stepper (minimo 1, massimo il
/// disponibile in casa). Il tocco sulla riga spunta o toglie l'oggetto; con lo
/// stepper visibile vale solo sull'area di casella e nome.
///
/// Con [packedOnly] è la riga della valigia generata: niente casella, il nome
/// tocca [onOpen] (la scheda), sotto il nome "Da indossare in partenza" se
/// [inDeparture], a destra × che chiama [onRemove]. Lo stepper scende a 0 e
/// a 0 chiama [onRemove]. [item] è `null` se l'oggetto non c'è più nella
/// casa: resta la riga, col nome della voce del viaggio, senza stepper.
class PackItemRow extends StatelessWidget {
  /// L'oggetto della casa; `null` solo in [packedOnly], se è stato cancellato.
  final ItemModel? item;

  /// La voce del viaggio se l'oggetto è scelto; `null` altrimenti.
  final TripItem? selected;

  /// Manuale: spunta o toglie l'oggetto.
  final VoidCallback? onToggle;

  /// Manuale: nuova quantità (sempre almeno 1).
  final ValueChanged<int>? onQuantityChanged;

  /// Riga della valigia generata: niente casella, × e tocco sul nome.
  final bool packedOnly;

  /// Da indossare in partenza (solo [packedOnly]).
  final bool inDeparture;

  /// Toglie dalla valigia (× e stepper a 0). Solo [packedOnly].
  final VoidCallback? onRemove;

  /// Apre la scheda dell'oggetto; `null` rende il nome inerte.
  final VoidCallback? onOpen;

  const PackItemRow({
    super.key,
    this.item,
    required this.selected,
    this.onToggle,
    this.onQuantityChanged,
    this.packedOnly = false,
    this.inDeparture = false,
    this.onRemove,
    this.onOpen,
  }) : assert(packedOnly || item != null),
       assert(packedOnly || (onToggle != null && onQuantityChanged != null)),
       assert(!packedOnly || selected != null);

  @override
  Widget build(BuildContext context) {
    if (packedOnly) return _packedRow(context);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final item = this.item!;
    final chosen = selected;
    final available = item.quantity ?? 1;

    final label = Row(
      children: [
        Checkbox(value: chosen != null, onChanged: (_) => onToggle!()),
        SizedBox(width: context.spacingXs),
        Expanded(
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.bodyLarge?.copyWith(
              color: chosen != null ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );

    final showStepper = chosen != null && available > 1;
    final padding = EdgeInsets.symmetric(
      horizontal: context.spacingSm,
      vertical: context.spacingXs,
    );

    // Senza stepper tutta la riga spunta. Con lo stepper spunta solo l'area di
    // casella e nome: un tocco accanto ai pulsanti non deve togliere l'oggetto
    // e perdere la quantità.
    if (!showStepper) {
      return InkWell(
        onTap: onToggle,
        child: Padding(padding: padding, child: label),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: InkWell(onTap: onToggle, child: label),
          ),
          QuantityStepper(
            value: chosen.quantity,
            minValue: 1,
            maxValue: available,
            accentColor: cs.onSurface,
            onChanged: onQuantityChanged!,
          ),
        ],
      ),
    );
  }

  Widget _packedRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final chosen = selected!;
    final item = this.item;
    final available = item?.quantity ?? 1;
    final showStepper = item != null && available > 1;

    return Padding(
      padding: EdgeInsets.only(
        left: context.spacingSm,
        right: context.spacingXs,
        top: context.spacingXs,
        bottom: context.spacingXs,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.spacingXs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item?.name ?? chosen.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                    ),
                    if (inDeparture)
                      Text(
                        'trips.pack.ai.in_departure'.tr(),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (showStepper)
            QuantityStepper(
              value: chosen.quantity,
              minValue: 0,
              maxValue: available,
              accentColor: cs.onSurface,
              onChanged: (quantity) {
                if (quantity <= 0) {
                  onRemove?.call();
                } else {
                  onQuantityChanged?.call(quantity);
                }
              },
            ),
          IconButton(
            key: Key('pack_remove_${chosen.id}'),
            tooltip: 'trips.pack.ai.remove'.tr(),
            icon: Icon(Icons.close, color: cs.onSurfaceVariant),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Riga "+ Aggiungi «nome» in Casa": crea dalla ricerca un oggetto che nella
/// casa non c'è. Il nome cercato è in grassetto.
class PackAddRow extends StatelessWidget {
  /// Nome cercato.
  final String name;
  final String houseName;
  final VoidCallback onTap;

  const PackAddRow({
    super.key,
    required this.name,
    required this.houseName,
    required this.onTap,
  });

  /// Segnaposto del nome nella frase tradotta: si spezza lì, così il
  /// grassetto cade sul nome anche se le stesse lettere sono altrove.
  static const _nameMark = '\u0000';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final parts = 'trips.pack.add_item'
        .tr(args: [_nameMark, houseName])
        .split(_nameMark);
    final text = TextSpan(
      children: [
        TextSpan(text: parts.first),
        TextSpan(text: name, style: tt.bodyLarge?.strong),
        TextSpan(text: parts.skip(1).join()),
      ],
    );

    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.spacingMd),
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: context.iconSizeMd,
                color: cs.onSurface,
              ),
              SizedBox(width: context.spacingMd),
              Expanded(child: Text.rich(text, style: tt.bodyLarge)),
              Icon(
                Icons.chevron_right,
                size: context.iconSizeMd,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
