import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/item_model.dart';
import '../providers/item_selection_provider.dart';
import '../../../shared/widgets/widgets.dart';
import 'add_edit_item_screen.dart';
import '../../../shared/theme/app_spacing.dart';

class ItemCard extends ConsumerWidget {
  final ItemModel item;
  final String houseId;
  final int quantityOnTrip;

  /// Chiamato in modalità normale appena prima di aprire la scheda
  /// dell'oggetto (la ricerca lo usa per l'evento del risultato aperto).
  final VoidCallback? onOpened;

  /// Chiamato quando la scheda aperta da questa riga si chiude.
  final VoidCallback? onSheetClosed;

  /// `false` dove la selezione multipla non deve partire (la pagina
  /// "aggiungi" della casa): il long press non fa nulla.
  final bool allowSelection;

  const ItemCard({
    super.key,
    required this.item,
    required this.houseId,
    required this.quantityOnTrip,
    this.onOpened,
    this.onSheetClosed,
    this.allowSelection = true,
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
          // Grigia: "in viaggio" è uno stato dell'oggetto, non un'azione né
          // una scelta. L'arancione resta a ciò su cui si può agire.
          subtitle = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flight_takeoff,
                size: Theme.of(context).textTheme.bodySmall?.fontSize,
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: context.spacingXs),
              Text(
                'common.in_transit'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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
              Icon(
                Icons.flight_takeoff,
                size: Theme.of(context).textTheme.bodySmall?.fontSize,
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: context.spacingXs),
              Text(
                '$quantityOnTrip ${'common.in_transit'.tr().toLowerCase()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }
      } else if (item.description != null) {
        subtitle = Text(
          item.description!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle,
      trailing: isSelectionActive
          ? null
          : DsQuantityBadge(current: totalQuantity),
      // In selection mode: tap tutta la card per selezionare/deselezionare.
      // In normal mode: tap apre l'edit sheet.
      onTap: isSelectionActive
          ? () => ref
                .read(itemSelectionNotifierProvider.notifier)
                .toggleItem(item.id)
          : () {
              onOpened?.call();
              showAddEditItemSheet(
                context,
                houseId: item.houseId,
                itemId: item.id,
              ).then((_) => onSheetClosed?.call());
            },
      // Long press attiva la selezione multipla dal primo item premuto.
      // Disabilitato se in selezione, se l'item è in viaggio o se la
      // selezione non è permessa qui.
      onLongPress: isSelectionActive || hasAnyOnTrip || !allowSelection
          ? null
          : () {
              ref.read(itemSelectionNotifierProvider.notifier).toggleMode();
              ref
                  .read(itemSelectionNotifierProvider.notifier)
                  .toggleItem(item.id);
            },
    );
  }
}
