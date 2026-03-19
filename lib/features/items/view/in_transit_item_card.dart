import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:stuff_tracker_2/features/items/view/item_category.dart';
import 'package:stuff_tracker_2/features/trips/model/trip_model.dart';
import 'package:stuff_tracker_2/shared/widgets/universal_item_tile.dart';

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
    // LOGICA CROMATICA:
    // Misceliamo lo sfondo standard dell'app (surface) con il nostro primario.
    // Il valore 0.10 significa "10% arancione, 90% sfondo".
    // Restituisce un colore solido brillante, senza l'effetto trasparenza opaca.
    final solidLightOrange = Color.lerp(colorScheme.surface, colorScheme.primary, 0.10);
    
    return UniversalItemTile(
      backgroundColor: solidLightOrange,
      //showInTransitOverlay: true,
      leading: CategoryIcon(category: item.category),
      title: Text(
        item.name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flight_takeoff,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '${'common.from'.tr()} $originHouseName',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: Text(
        'x${item.quantity}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}