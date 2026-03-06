import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:stuff_tracker_2/features/items/model/item_model.dart';
import 'package:stuff_tracker_2/features/items/view/item_card.dart';
import 'package:stuff_tracker_2/features/items/view/item_category.dart';
import 'package:stuff_tracker_2/shared/theme/app_spacing.dart';

/// Sezione collassabile per categoria
class ItemCategorySection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: EdgeInsets.symmetric(horizontal: context.spacingSm),
            childrenPadding: EdgeInsets.zero,
            leading: CategoryIcon(category: category, size: context.iconSizeLg),
            title: Text(
              category.displayName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.fontSizeMd),
            ),
            subtitle: Text('common.items_count'.tr(args: [items.length.toString()]), style: TextStyle(fontSize: context.fontSizeXs)),
            children: items.map((item) {
              return ItemCard(
                item: item,
                houseId: houseId,
                quantityOnTrip: itemQuantitiesOnTrip[item.id] ?? 0,
              );
            }).toList(),
          ),
        ),
        SizedBox(height: context.spacingSm),
      ],
    );
  }
}