import 'package:flutter/material.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';


class CategoryIcon extends StatelessWidget {
  final ItemCategory category;
  final double? size;

  const CategoryIcon({
    super.key,
    required this.category,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final defaultSize = size ?? context.iconSizeMd;
    return switch (category) {
      ItemCategory.vestiti => Icon(Icons.checkroom, size: defaultSize),
      ItemCategory.toiletries => Icon(Icons.spa, size: defaultSize),
      ItemCategory.elettronica => Icon(Icons.devices, size: defaultSize),
      ItemCategory.varie => Icon(Icons.category, size: defaultSize),
    };
  }
}