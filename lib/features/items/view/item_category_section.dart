import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/view/item_card.dart';
import 'package:pack_log/shared/widgets/category_section_header.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';

/// Sezione collassabile per categoria — basata su [SliverMainAxisGroup].
///
/// Ritorna un raggruppamento di Sliver per essere inserito direttamente
/// nel [slivers] di un [CustomScrollView], eliminando il `shrinkWrap: true`
/// che forzava il calcolo sincrono di tutti i figli (Raster Jank).
///
/// Il [SliverList.builder] interno istanzia le [ItemCard] in modo pigro:
/// ogni card è costruita solo quando entra nel viewport.
class ItemCategorySection extends StatefulWidget {
  final ItemCategory category;
  final List<ItemModel> items;
  final String houseId;
  final Map<String, int> itemQuantitiesOnTrip;

  const ItemCategorySection({
    super.key,
    required this.category,
    required this.items,
    required this.houseId,
    required this.itemQuantitiesOnTrip,
  });

  @override
  State<ItemCategorySection> createState() => _ItemCategorySectionState();
}

class _ItemCategorySectionState extends State<ItemCategorySection> {
  /// Controlla la visibilità degli item della sezione.
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverMainAxisGroup(
      slivers: [
        // ── Header con toggle expand/collapse ────────────────────────────────
        // Usa InkWell invece di ExpansionTile: ExpansionTile forza Flutter a
        // misurare tutti i figli in altezza per l'animazione, anche con
        // shrinkWrap. InkWell + setState elimina questo overhead.
        SliverToBoxAdapter(
          child: InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: CategorySectionHeader(
              category: widget.category,
              iconSize: context.iconSizeLg,
              horizontalPadding: context.spacingSm,
              // Raddoppiato: senza stacco il titolo di gruppo si incollava
              // alla prima riga, mentre tutte le altre sono separate da un
              // divisore. Si somma al padding verticale della riga sotto.
              verticalPadding: context.spacingSm,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'common.items_count'.tr(
                      args: [widget.items.length.toString()],
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(width: context.spacingXs),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: context.iconSizeMd,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Items (lazy, istanziati solo quando entrano nel viewport) ─────────
        // SliverList.builder non usa shrinkWrap, quindi non misura tutti gli
        // item in anticipo: le ItemCard sono costruite one-by-one on demand.
        if (_isExpanded)
          SliverList.builder(
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return ItemCard(
                item: item,
                houseId: widget.houseId,
                quantityOnTrip: widget.itemQuantitiesOnTrip[item.id] ?? 0,
              );
            },
          ),

        // ── Spaziatura inferiore tra sezioni ─────────────────────────────────
        SliverToBoxAdapter(child: SizedBox(height: context.spacingSm)),
      ],
    );
  }
}
