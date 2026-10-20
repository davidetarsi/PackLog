import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/quantity_stepper.dart';
import '../../../../items/model/item_model.dart';
import '../../../model/trip_model.dart';

/// Titolo di una sezione della valigia: "Bagagli", "Cosa porti".
class PackSectionTitle extends StatelessWidget {
  final String text;

  const PackSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: context.spacingLg,
        bottom: context.spacingSm,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Pillola neutra della valigia: bagagli e casa. Se scelta prende la superficie
/// `surfaceContainerHigh`, il contorno `onSurface` e la spunta; altrimenti
/// contorno `outlineVariant` e l'icona. Niente arancio: lo porta solo "Fatto".
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
      color: selected ? cs.surfaceContainerHigh : Colors.transparent,
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
                selected ? Icons.check : icon,
                size: context.iconSizeSm,
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
              ),
              SizedBox(width: context.spacingXs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge,
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
/// disponibile in casa). Il tocco sulla riga spunta o toglie l'oggetto.
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

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingSm,
          vertical: context.spacingXs,
        ),
        child: Row(
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
            if (chosen != null && available > 1)
              QuantityStepper(
                value: chosen.quantity,
                minValue: 1,
                maxValue: available,
                accentColor: cs.onSurface,
                onChanged: onQuantityChanged,
              ),
          ],
        ),
      ),
    );
  }
}
