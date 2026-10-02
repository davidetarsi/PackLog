import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pack_log/features/items/view/in_transit_item_card.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';

/// Sezione "In Transito"
class InTransitSection extends StatelessWidget {
  final List<TripItem> items;
  final List<HouseModel> houses;

  const InTransitSection({
    super.key,
    required this.items,
    required this.houses,
  });

  /// Nome della casa di provenienza di un item, o il fallback tradotto.
  String _originName(TripItem item) {
    final match = houses.where((h) => h.id == item.originHouseId);
    return match.isNotEmpty
        ? match.first.displayName
        : 'common.unknown_house'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Quando i temporanei vengono tutti dalla stessa casa — che è il caso
    // normale — la provenienza sale nell'header invece di ripetersi identica
    // su ogni riga. Con provenienze miste non è riassumibile e resta per riga.
    final origins = items.map(_originName).toSet();
    final sharedOrigin = origins.length == 1 ? origins.first : null;

    final count = 'common.items_count'.tr(args: [items.length.toString()]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: EdgeInsets.symmetric(horizontal: context.spacingSm),
            childrenPadding: EdgeInsets.zero,
            // Grigia come le icone di categoria: "temporaneo" è uno stato, non
            // qualcosa su cui agire.
            leading: Icon(
              Icons.local_shipping,
              color: colorScheme.onSurfaceVariant,
              size: context.iconSizeMd,
            ),
            title: Text(
              'common.temporaries'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500, // titleMedium ≈ 16px → w500
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              sharedOrigin == null
                  ? count
                  : '$count · ${'common.from'.tr()} $sharedOrigin',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            children: items
                .map(
                  (item) => InTransitItemCard(
                    item: item,
                    originHouseName: _originName(item),
                    showOrigin: sharedOrigin == null,
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(height: context.spacingSm),
      ],
    );
  }
}
