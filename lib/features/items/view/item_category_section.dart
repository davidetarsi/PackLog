import 'package:flutter/material.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/view/item_card.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';
import 'package:pack_log/shared/widgets/ds_group_surface_sliver.dart';

/// Gruppo di una categoria nella lista della casa.
///
/// L'etichetta sta in un [PinnedHeaderSliver]: dentro il
/// [SliverMainAxisGroup] resta fissa in alto finché si scorre il gruppo, così
/// con molti oggetti si sa sempre in quale categoria si è. Toccarla chiude o
/// riapre il gruppo.
///
/// Le righe sono in un [SliverList.builder]: costruite solo quando entrano a
/// schermo.
class ItemCategorySection extends StatefulWidget {
  final ItemCategory category;
  final List<ItemModel> items;
  final String houseId;
  final Map<String, int> itemQuantitiesOnTrip;

  /// Key dell'etichetta (il primo gruppo della lista porta quella del tour).
  final Key? headerKey;

  /// Chiamato quando si apre un oggetto, con il suo indice nel gruppo.
  final void Function(int index)? onItemOpened;

  const ItemCategorySection({
    super.key,
    required this.category,
    required this.items,
    required this.houseId,
    required this.itemQuantitiesOnTrip,
    this.headerKey,
    this.onItemOpened,
  });

  @override
  State<ItemCategorySection> createState() => _ItemCategorySectionState();
}

class _ItemCategorySectionState extends State<ItemCategorySection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final onItemOpened = widget.onItemOpened;
    return SliverMainAxisGroup(
      slivers: [
        PinnedHeaderSliver(
          child: DsGroupHeader(
            key: widget.headerKey,
            label: widget.category.displayName,
            count: widget.items.length,
            prominent: true,
            expanded: _isExpanded,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
        ),
        if (_isExpanded)
          DsGroupSurfaceSliver(
            surfaceKey: ValueKey('house_group_surface_${widget.category.name}'),
            sliver: SliverList.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return ItemCard(
                  item: item,
                  houseId: widget.houseId,
                  quantityOnTrip: widget.itemQuantitiesOnTrip[item.id] ?? 0,
                  onOpened: onItemOpened == null
                      ? null
                      : () => onItemOpened(index),
                  dividerInsets: EdgeInsets.symmetric(
                    horizontal: context.spacingMd,
                  ),
                  showDivider: index < widget.items.length - 1,
                );
              },
            ),
          ),
      ],
    );
  }
}
