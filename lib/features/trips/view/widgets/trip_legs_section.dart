import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/theme.dart';
import '../../model/trip_leg.dart';
import 'trip_leg_sheet.dart';

/// Sezione "Altre tappe" del form viaggio.
///
/// Di default mostra solo il bottone di aggiunta: le tappe sono un caso
/// minoritario e non devono occupare spazio a chi non le usa.
class TripLegsSection extends StatelessWidget {
  final List<TripLeg> legs;
  final ValueChanged<List<TripLeg>> onChanged;

  const TripLegsSection({
    super.key,
    required this.legs,
    required this.onChanged,
  });

  Future<void> _add(BuildContext context) async {
    final leg = await showTripLegSheet(context);
    if (leg == null) return;
    onChanged([...legs, leg]);
  }

  Future<void> _edit(BuildContext context, TripLeg leg) async {
    final updated = await showTripLegSheet(context, initial: leg);
    if (updated == null) return;
    onChanged([
      for (final l in legs)
        if (l.id == leg.id) updated else l,
    ]);
  }

  void _remove(TripLeg leg) {
    onChanged(legs.where((l) => l.id != leg.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'trips.legs_title'.tr(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.spacingSm),
        for (final leg in legs) ...[
          // Key univoca per figlio diretto della Column (per-leg): la key
          // condivisa 'trip_leg_row' richiesta dai test vive più in basso,
          // sulla radice di _LegRow, dove non è tra fratelli dello stesso
          // MultiChildRenderObjectElement e quindi non collide.
          _LegRow(
            key: ValueKey('trip_leg_row_${leg.id}'),
            leg: leg,
            onTap: () => _edit(context, leg),
            onRemove: () => _remove(leg),
          ),
          SizedBox(height: context.spacingSm),
        ],
        TextButton.icon(
          key: const Key('trip_legs_add'),
          onPressed: () => _add(context),
          icon: const Icon(Icons.add, size: 18),
          label: Text('trips.leg_add'.tr()),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: context.spacingXs),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

class _LegRow extends StatelessWidget {
  final TripLeg leg;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _LegRow({
    super.key,
    required this.leg,
    required this.onTap,
    required this.onRemove,
  });

  String? get _datesLabel {
    if (leg.from == null && leg.to == null) return null;
    final format = DateFormat('d MMM');
    if (leg.to == null) return format.format(leg.from!);
    if (leg.from == null) return format.format(leg.to!);
    return '${format.format(leg.from!)} – ${format.format(leg.to!)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dates = _datesLabel;
    // Token noto (cardBorderRadius): raw, non responsiveBorderRadius (DS
    // Phase 1, vedi commento in app_constants.dart).
    final radius = BorderRadius.circular(AppConstants.cardBorderRadius);

    return InkWell(
      key: const Key('trip_leg_row'),
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMd,
          vertical: context.spacingSm,
        ),
        child: Row(
          children: [
            // Icona-etichetta, non azione: grigia come le altre del form.
            Icon(
              Icons.place_outlined,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: context.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leg.locationDisplayName,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (dates != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      dates,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              key: Key('trip_leg_remove_${leg.id}'),
              onPressed: onRemove,
              icon: Icon(
                Icons.close,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
