import 'package:flutter/material.dart';
import 'package:stuff_tracker_2/features/items/view/in_transit_item_card.dart';
import 'package:stuff_tracker_2/features/trips/model/trip_model.dart';
import 'package:stuff_tracker_2/features/houses/model/house_model.dart';
import 'package:stuff_tracker_2/shared/theme/app_spacing.dart';

/// Sezione "In Transito"
class InTransitSection extends StatelessWidget {
  final List<TripItem> items;
  final List<HouseModel> houses;

  const InTransitSection({
    super.key,
    required this.items,
    required this.houses,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: EdgeInsets.symmetric(horizontal: context.spacingSm),
            childrenPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.local_shipping,
              color: colorScheme.primary,
              size: context.iconSizeMd,
            ),
            title: Text(
              'Temporanei',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              '${items.length} oggetti',
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            children: items.map((item) {
              final matchingHouses = houses.where((h) => h.id == item.originHouseId);
              final originHouse = matchingHouses.isNotEmpty ? matchingHouses.first : null;
              return InTransitItemCard(
                item: item,
                originHouseName: originHouse?.name ?? 'Casa sconosciuta',
              );
            }).toList(),
          ),
        ),
        SizedBox(height: context.spacingSm),
      ],
    );
  }
}