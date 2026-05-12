import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/item_model.dart';
import '../providers/item_selection_provider.dart';
import '../../../shared/widgets/widgets.dart';

class ItemCard extends ConsumerWidget {
  final ItemModel item;
  final String houseId;
  final int quantityOnTrip;

  const ItemCard({
    super.key,
    required this.item,
    required this.houseId,
    required this.quantityOnTrip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final totalQuantity = item.quantity ?? 1;
    final availableQuantity = totalQuantity - quantityOnTrip;
    final isFullyOnTrip = quantityOnTrip > 0 && availableQuantity == 0;
    final hasAnyOnTrip = quantityOnTrip > 0;

    // Osserva lo stato della selezione multipla
    final selectionState = ref.watch(itemSelectionNotifierProvider);
    final isSelectionActive = selectionState.isActive;
    final isSelected = selectionState.selectedIds.contains(item.id);

    // Costruisci subtitle dinamico (solo in modalità normale)
    Widget? subtitle;
    if (!isSelectionActive) {
      if (hasAnyOnTrip) {
        if (isFullyOnTrip) {
          subtitle = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flight_takeoff, size: 12, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                'common.in_transit'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        } else {
          subtitle = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$availableQuantity ${'common.here'.tr()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                ' • ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(Icons.flight_takeoff, size: 12, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                '$quantityOnTrip ${'common.in_transit'.tr().toLowerCase()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }
      } else if (item.description != null) {
        subtitle = Text(
          item.description!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
      }
    }

    // In modalità selezione il leading diventa un Checkbox; altrimenti assente
    // così il titolo si posiziona automaticamente a sinistra.
    final Widget? leading = isSelectionActive
        ? Checkbox(
            value: isSelected,
            onChanged: (_) => ref
                .read(itemSelectionNotifierProvider.notifier)
                .toggleItem(item.id),
            activeColor: colorScheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
        : null;

    // Il colore di sfondo segnala visivamente la selezione.
    final Color? bgColor = isSelected
        ? colorScheme.primary.withValues(alpha: 0.08)
        : null;

    return UniversalItemTile(
      backgroundColor: bgColor,
      leading: leading,
      title: Text(
        item.name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle,
      trailing: isSelectionActive
          ? null
          : Text(
              'x$totalQuantity',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
      // In selection mode: tap tutta la card per selezionare/deselezionare.
      // In normal mode: tap apre l'edit sheet (disabilitato se tutto in viaggio).
      onTap: isSelectionActive
          ? () => ref
                .read(itemSelectionNotifierProvider.notifier)
                .toggleItem(item.id)
          : null,
          /* isFullyOnTrip
              ? null
              : () => _onEdit(context), */
      // Long press attiva la selezione multipla dal primo item premuto.
      // Disabilitato se in selezione o se l'item è in viaggio.
      onLongPress: isSelectionActive || hasAnyOnTrip
          ? null
          : () {
              ref
                  .read(itemSelectionNotifierProvider.notifier)
                  .toggleMode();
              ref
                  .read(itemSelectionNotifierProvider.notifier)
                  .toggleItem(item.id);
            },
    );
  }

}