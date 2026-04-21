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
    return Icon(category.icon, size: size ?? context.iconSizeMd);
  }
}