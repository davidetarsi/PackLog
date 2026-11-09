import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/helpers/design_system.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_group_header.dart';
import '../../../../items/model/item_model.dart';
import '../../../../../shared/widgets/ds_checkbox.dart';
import '../../../../../shared/widgets/ds_icon_button.dart';
import '../../../model/trip_model.dart';
import '../pack/pack_inventory_search.dart';
import 'flight_target.dart';

/// Valigia vuota: niente oggetti (e niente posti).
class EmptySuitcase extends StatelessWidget {
  const EmptySuitcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.spacingLg),
      child: DsEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'trips.no_items_in_list'.tr(),
      ),
    );
  }
}

/// Gli oggetti di un gruppo, uno per riga, da spuntare.
class ItemsCard extends StatelessWidget {
  final List<TripItem> items;
  final ValueChanged<TripItem>? onRemoveItem;
  final ValueChanged<TripItem> onToggleItem;
  final bool checklistEnabled;
  final ValueChanged<TripItem>? onOpenItem;
  final bool showRemove;

  /// La chiave della riga di un oggetto (per farlo volare fin qui).
  final GlobalKey Function(String itemId)? rowKey;

  /// Gli oggetti in volo verso questo gruppo: la loro riga si vede quando
  /// atterrano.
  final ValueListenable<Set<String>>? flying;

  const ItemsCard({
    super.key,
    required this.items,
    this.onRemoveItem,
    required this.onToggleItem,
    this.checklistEnabled = true,
    this.onOpenItem,
    this.showRemove = true,
    this.rowKey,
    this.flying,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final item in items)
            FlightTarget(
              key: rowKey?.call(item.id),
              hidden: flying,
              itemId: item.id,
              child: PackedRow(
                item: item,
                onRemove: !showRemove || onRemoveItem == null
                    ? null
                    : () => onRemoveItem!(item),
                onOpen: onOpenItem == null ? null : () => onOpenItem!(item),
                onToggle: checklistEnabled ? () => onToggleItem(item) : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// Riga di un oggetto da mettere in valigia: casella, nome e quantità. Una
/// volta dentro il nome si spegne e si barra; tutta la riga spunta.
class PackedRow extends StatelessWidget {
  final TripItem item;
  final VoidCallback? onToggle;
  final VoidCallback? onRemove;
  final VoidCallback? onOpen;

  const PackedRow({
    super.key,
    required this.item,
    required this.onToggle,
    this.onRemove,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final packed = item.isChecked;
    final itemName = Text(
      item.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tt.bodyLarge?.copyWith(
        color: packed ? context.textTertiary : cs.onSurface,
        decoration: packed ? TextDecoration.lineThrough : null,
      ),
    );

    return InkWell(
      key: Key('trip_item_${item.id}'),
      onTap: onOpen ?? onToggle,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingSm,
          vertical: context.spacingXs,
        ),
        child: Row(
          children: [
            if (onToggle != null)
              DsCheckbox(value: packed, onChanged: (_) => onToggle!()),
            SizedBox(width: context.spacingXs),
            if (onRemove != null)
              DsIconButton(
                key: Key('trip_item_remove_${item.id}'),
                icon: Icons.close,
                tooltip: 'trips.pack.ai.remove'.tr(),
                onPressed: onRemove,
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.spacingXs),
                child: itemName,
              ),
            ),
            if (item.quantity > 1)
              Padding(
                padding: EdgeInsets.only(right: context.spacingSm),
                child: Text(
                  '×${item.quantity}',
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Gli oggetti della valigia per categoria, uguale per ogni valigia: con una
/// proposta AI sta sotto i posti, senza è tutta la lista. Con [houseId] c'è
/// anche la ricerca nella casa della proposta; senza, nessuna ricerca.
class SuitcaseItemsSection extends StatelessWidget {
  final TripModel trip;
  final String? houseId;
  final bool checklistEnabled;
  final Future<void> Function(ItemModel item, int copies) onAddInventory;
  final ValueChanged<TripItem>? onRemoveItem;
  final ValueChanged<TripItem> onToggleItem;
  final ValueChanged<TripItem>? onOpenItem;
  final GlobalKey Function(String itemId) rowKey;
  final ValueListenable<Set<String>> flying;

  const SuitcaseItemsSection({
    super.key,
    required this.trip,
    this.houseId,
    required this.checklistEnabled,
    required this.onAddInventory,
    required this.onRemoveItem,
    required this.onToggleItem,
    required this.onOpenItem,
    required this.rowKey,
    required this.flying,
  });

  @override
  Widget build(BuildContext context) {
    if (trip.items.isEmpty && houseId == null) return const EmptySuitcase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (houseId != null) ...[
          PackInventorySearch(
            houseId: houseId!,
            excludedItemIds: trip.items.map((item) => item.id).toSet(),
            onAdd: onAddInventory,
          ),
          SizedBox(height: context.spacingMd),
        ],
        for (final category in ItemCategory.values)
          if (trip.items.any((item) => item.category == category)) ...[
            DsGroupHeader(
              label: category.displayName,
              count: trip.items.where((i) => i.category == category).length,
            ),
            ItemsCard(
              items: trip.items.where((i) => i.category == category).toList(),
              checklistEnabled: checklistEnabled,
              onRemoveItem: onRemoveItem,
              onToggleItem: onToggleItem,
              onOpenItem: onOpenItem,
              showRemove: !checklistEnabled,
              rowKey: rowKey,
              flying: flying,
            ),
          ],
      ],
    );
  }
}
