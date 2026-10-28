import 'package:flutter/material.dart';

import '../model/model.dart';
import '../theme/app_spacing.dart';

/// Riga di un luogo trovato dalla ricerca: nome in chiaro e, sotto, dove si
/// trova ("Lombardia, Italia"). Icona grigia secondo il tipo. Unica per
/// tutta l'app: campo luogo della casa, meta e tappe del viaggio.
class LocationResultRow extends StatelessWidget {
  const LocationResultRow({
    super.key,
    required this.place,
    required this.onTap,
  });

  final LocationSuggestionModel place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final subtitle = locationContext(place);
    final icon = switch (place.locationType) {
      LocationType.country => Icons.flag_outlined,
      LocationType.state => Icons.map_outlined,
      LocationType.city || LocationType.other => Icons.place_outlined,
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMd,
          vertical: context.spacingSmPlus,
        ),
        child: Row(
          children: [
            Icon(icon, size: context.iconSizeMd, color: cs.onSurfaceVariant),
            SizedBox(width: context.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name ?? place.displayName,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dove si trova un luogo, senza ripeterne il nome: regione e paese per una
/// città, il paese per una regione, niente per un paese.
String? locationContext(LocationSuggestionModel place) {
  final name = place.name;
  final parts = <String>[
    if (place.locationType == LocationType.city &&
        place.state != null &&
        place.state != name)
      place.state!,
    if (place.locationType != LocationType.country &&
        place.country != null &&
        place.country != name)
      place.country!,
  ];
  return parts.isEmpty ? null : parts.join(', ');
}
