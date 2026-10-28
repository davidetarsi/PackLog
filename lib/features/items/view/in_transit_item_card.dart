import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pack_log/features/items/view/item_category.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/shared/widgets/ds_badge.dart';
import 'package:pack_log/shared/widgets/universal_item_tile.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';

/// Card specifica per oggetti in transito
class InTransitItemCard extends StatelessWidget {
  final TripItem item;
  final String originHouseName;

  /// Se false, la provenienza non compare sulla riga perché è già scritta
  /// nell'header di sezione (caso in cui tutti i temporanei vengono dalla
  /// stessa casa, che è la norma).
  final bool showOrigin;
  final EdgeInsets dividerInsets;
  final bool showDivider;

  const InTransitItemCard({
    super.key,
    required this.item,
    required this.originHouseName,
    this.showOrigin = true,
    this.dividerInsets = EdgeInsets.zero,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Nessuno sfondo: lo sfondo arancione stava su ogni riga e, impilato,
    // formava un blocco squadrato alto quanto la sezione. Diceva per la terza
    // volta ciò che l'header e l'etichetta di riga già dicevano — e
    // "temporaneo" è uno stato, non un'azione: l'arancione non gli spetta.
    // Gli oggetti "in viaggio" nella stessa schermata non hanno mai avuto uno
    // sfondo, quindi questa era l'eccezione.
    return UniversalItemTile(
      dividerInsets: dividerInsets,
      showDivider: showDivider,
      leading: CategoryIcon(category: item.category),
      title: Text(
        item.name,
        style: Theme.of(context).textTheme.bodyMedium?.strong,
      ),
      subtitle: showOrigin
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flight_takeoff,
                  size: context.iconSizeXs,
                  color: colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: context.spacingXs),
                Text(
                  '${'common.from'.tr()} $originHouseName',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          : null,
      trailing: DsQuantityBadge(current: item.quantity),
    );
  }
}
