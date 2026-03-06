import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:stuff_tracker_2/features/items/view/item_category.dart';
import 'package:stuff_tracker_2/features/trips/model/trip_model.dart';
import 'package:stuff_tracker_2/shared/theme/app_spacing.dart';

/// Card specifica per oggetti in transito
class InTransitItemCard extends StatelessWidget {
  final TripItem item;
  final String originHouseName;

  const InTransitItemCard({
    super.key,
    required this.item,
    required this.originHouseName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: EdgeInsets.only(bottom: context.spacingSm),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: ListTile(
        leading: CategoryIcon(category: item.category),
        title: Text(
          item.name,
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500, fontSize: 16),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.local_shipping, size: 14, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              '${'common.from'.tr()} $originHouseName',
              style: TextStyle(color: colorScheme.primary, fontSize: 14),
            ),
          ],
        ),
        trailing: Text(
          'x${item.quantity}',
          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontSize: 16),
        ),
      ),
    );
  }
}