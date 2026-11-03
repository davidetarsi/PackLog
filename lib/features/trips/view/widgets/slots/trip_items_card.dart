import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/helpers/design_system.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_group_header.dart';
import '../../../../../shared/widgets/ds_section_title.dart';
import '../../../../items/model/item_model.dart';
import '../../../../../shared/widgets/ds_checkbox.dart';
import '../../../model/trip_model.dart';
import '../../../providers/trip_provider.dart';
import 'flight_target.dart';

/// Valigia vuota: niente oggetti (e niente posti).
class EmptySuitcase extends StatelessWidget {
  const EmptySuitcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.spacingLg),
      child: DsEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'trips.no_items_in_list'.tr(),
      ),
    );
  }
}

/// Gli oggetti di un gruppo, uno per riga, da spuntare.
class ItemsCard extends ConsumerWidget {
  final String tripId;
  final List<TripItem> items;

  /// La chiave della riga di un oggetto (per farlo volare fin qui).
  final GlobalKey Function(String itemId)? rowKey;

  /// Gli oggetti in volo verso questo gruppo: la loro riga si vede quando
  /// atterrano.
  final ValueListenable<Set<String>>? flying;

  const ItemsCard({
    super.key,
    required this.tripId,
    required this.items,
    this.rowKey,
    this.flying,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final item in items)
            FlightTarget(
              key: rowKey?.call(item.id),
              hidden: flying,
              itemId: item.id,
              child: PackedRow(
                item: item,
                onToggle: () => ref
                    .read(tripNotifierProvider.notifier)
                    .toggleItemCheck(tripId, item.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// Riga di un oggetto da mettere in valigia: casella, nome e quantità. Una
/// volta dentro il nome si spegne e si barra; tutta la riga spunta.
class PackedRow extends StatelessWidget {
  final TripItem item;
  final VoidCallback onToggle;

  const PackedRow({super.key, required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final packed = item.isChecked;

    return InkWell(
      key: Key('trip_item_${item.id}'),
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingSm,
          vertical: context.spacingXs,
        ),
        child: Row(
          children: [
            DsCheckbox(value: packed, onChanged: (_) => onToggle()),
            SizedBox(width: context.spacingXs),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyLarge?.copyWith(
                  color: packed ? context.textTertiary : cs.onSurface,
                  decoration: packed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (item.quantity > 1)
              Padding(
                padding: EdgeInsets.only(right: context.spacingSm),
                child: Text(
                  '×${item.quantity}',
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Cosa porti" senza posti: quanti sono già in valigia, poi gli oggetti per categoria
/// in ordine canonico, come nella pagina valigia e nella casa.
class PlainItemsSection extends ConsumerWidget {
  final TripModel trip;

  const PlainItemsSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = trip.items;

    if (items.isEmpty) return const EmptySuitcase();

    final packed = trip.completedCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionTitle('trips.pack.items'.tr()),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppConstants.pillBorderRadius,
                ),
                child: LinearProgressIndicator(
                  key: const Key('trip_detail_progress'),
                  value: packed / items.length,
                  minHeight: context.spacingXs,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.onSurface,
                ),
              ),
            ),
            SizedBox(width: context.spacingSm),
            Text(
              'trips.detail.packed_count'.tr(
                args: [packed.toString(), items.length.toString()],
              ),
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        for (final category in ItemCategory.values)
          if (items.any((item) => item.category == category)) ...[
            DsGroupHeader(
              label: category.displayName,
              count: items.where((i) => i.category == category).length,
            ),
            ItemsCard(
              tripId: trip.id,
              items: items.where((i) => i.category == category).toList(),
            ),
          ],
      ],
    );
  }
}
