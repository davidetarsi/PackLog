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
class PackItemRow extends StatelessWidget {
  final ItemModel item;

  /// La voce del viaggio se l'oggetto è scelto; `null` altrimenti.
  final TripItem? selected;
  final VoidCallback onToggle;
  final ValueChanged<int> onQuantityChanged;

  const PackItemRow({
    super.key,
    required this.item,
    required this.selected,
    required this.onToggle,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final chosen = selected;
    final available = item.quantity ?? 1;

    final label = Row(
      children: [
        Checkbox(value: chosen != null, onChanged: (_) => onToggle()),
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
            onChanged: onQuantityChanged,
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
        TextSpan(
          text: name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
