import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/houses/providers/house_provider.dart';
import '../../features/trips/model/trip_model.dart';
import '../../features/trips/providers/trip_provider.dart';
import '../constants/app_constants.dart';
import '../helpers/entity_action_handler.dart';
import '../theme/theme.dart';
import '../widgets/ds_badge.dart';
import '../widgets/entity_context_menu.dart';
import '../widgets/trip_info_badges.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripCardHero  (era TripSummaryCard)
// ─────────────────────────────────────────────────────────────────────────────

/// Card "hero" per un viaggio: layout generoso con nome grande, badge
/// orizzontali (date, destinazione, bagagli) e barra di progresso.
///
/// Tipicamente usata per il prossimo viaggio in evidenza nella [TripsScreen].
///
/// Equivalente rinominato di [TripSummaryCard].
class TripCardHero extends ConsumerWidget {
  final TripModel trip;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isClickable;

  const TripCardHero({
    super.key,
    required this.trip,
    this.onTap,
    this.onLongPress,
    this.isClickable = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final housesAsync = ref.watch(houseNotifierProvider);
    final house = housesAsync.valueOrNull
        ?.where((h) => h.id == trip.destinationHouseId)
        .firstOrNull;
    final displayDestination =
        house?.displayName ?? trip.destinationDisplayName ?? '';

    Widget content = Padding(
      padding: EdgeInsets.all(context.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  displayDestination,
                  style: TextStyle(
                    fontWeight: FontWeight.w600, // ≥24px → w600
                    fontSize: context.fontSizeTitle,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: context.spacingSm),
              Icon(
                Icons.flight_takeoff,
                size: context.iconSizeLg + 4,
                color: cs.onSurface,
              ),
            ],
          ),
          SizedBox(height: context.spacingSm),
          TripInfoBadges(trip: trip, showDestination: false),
          SizedBox(height: context.spacingMd),
          _TripProgress(trip: trip),
        ],
      ),
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius + 4,
        ),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: isClickable && (onTap != null || onLongPress != null)
          ? InkWell(
              borderRadius: context.responsiveBorderRadius(
                AppConstants.cardBorderRadius + 4,
              ),
              onTap: onTap,
              onLongPress: onLongPress,
              child: content,
            )
          : content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TripCardCompact  (era _TripCard di trips_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────

/// Card compatta per un viaggio: adatta alle colonne della masonry.
/// Mostra nome, progress bar, preview dei primi item e contatore "+N altri".
///
/// Include la logica di interazione (long-press → context menu).
class TripCardCompact extends ConsumerWidget {
  final TripModel trip;
  final int maxPreviewItems;

  const TripCardCompact({
    super.key,
    required this.trip,
    this.maxPreviewItems = 5,
  });

  Future<void> _onLongPress(
    BuildContext context,
    WidgetRef ref,
    String displayDestination,
  ) async {
    final action = await showEntityContextMenu(
      context: context,
      entityType: 'common.trip_type'.tr(),
    );
    if (action == null || !context.mounted) return;

    await EntityActionHandler.handleAction(
      context: context,
      action: action,
      entityTypeLabel: 'common.trip_type'.tr(),
      entityName: displayDestination,
      onCopy: () async {
        await ref
            .read(tripNotifierProvider.notifier)
            .duplicateTrip(trip.id, nameSuffix: 'trips.duplicate_suffix'.tr());
      },
      copyErrorMessage: 'errors.duplicate_trip_failed'.tr(
        args: [displayDestination],
      ),
      onDelete: () async {
        await ref.read(tripNotifierProvider.notifier).deleteTrip(trip.id);
      },
      deleteErrorMessage: 'errors.delete_trip_failed'.tr(
        args: [displayDestination],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final itemsToShow = trip.items.length.clamp(0, maxPreviewItems);
    final housesAsync = ref.watch(houseNotifierProvider);
    final house = housesAsync.valueOrNull
        ?.where((h) => h.id == trip.destinationHouseId)
        .firstOrNull;
    final displayDestination =
        house?.displayName ?? trip.destinationDisplayName ?? '';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius,
        ),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius,
        ),
        onTap: () => context.push('/trips/${trip.id}'),
        onLongPress: () => _onLongPress(context, ref, displayDestination),
        child: Padding(
          padding: context.cardPaddingHero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Titolo + icona salvato
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      displayDestination,
                      style: TextStyle(
                        fontWeight: FontWeight.w700, // 18px → w700
                        fontSize: context.fontSizeMd,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trip.isSaved)
                    Padding(
                      padding: EdgeInsets.only(left: context.spacingXs),
                      child: Icon(
                        Icons.bookmark,
                        size: context.iconSizeSm + 2,
                        color: cs.primary,
                      ),
                    ),
                ],
              ),
              if (trip.description != null) ...[
                SizedBox(height: context.spacingXs),
                Text(
                  trip.description!,
                  style: TextStyle(
                    fontSize: context.fontSizeXs,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: context.spacingSm),
              if (trip.items.isNotEmpty) ...[
                _TripProgress(trip: trip),
                SizedBox(height: context.spacingSm),
              ],
              _TripItemPreview(
                trip: trip,
                itemsToShow: itemsToShow,
                maxPreviewItems: maxPreviewItems,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-components
// ─────────────────────────────────────────────────────────────────────────────

/// Barra di progresso standardizzata per i viaggi.
class _TripProgress extends StatelessWidget {
  final TripModel trip;

  const _TripProgress({required this.trip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${trip.completedCount}/${trip.totalCount}',
          style: TextStyle(
            fontSize: context.fontSizeXs,
            color: context.textTertiary,
          ),
        ),
        SizedBox(height: context.spacingXs),
        LinearProgressIndicator(
          value: trip.completionPercentage,
          backgroundColor: cs.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            trip.completionPercentage == 1.0
                ? context.appColors.success
                : cs.primary,
          ),
        ),
      ],
    );
  }
}

/// Lista preview degli item di un viaggio (max N + contatore "+X altri").
class _TripItemPreview extends StatelessWidget {
  final TripModel trip;
  final int itemsToShow;
  final int maxPreviewItems;

  const _TripItemPreview({
    required this.trip,
    required this.itemsToShow,
    required this.maxPreviewItems,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(itemsToShow, (index) {
          final item = trip.items[index];
          return Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacingXs / 2),
            child: Row(
              children: [
                Icon(
                  item.isChecked
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: context.iconSizeSm,
                  color: item.isChecked
                      ? context.appColors.success
                      : context.textTertiary,
                ),
                SizedBox(width: context.spacingXs + 2),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: context.fontSizeXs,
                      decoration: item.isChecked
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.isChecked
                          ? cs.onSurface.withValues(alpha: 0.5)
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DsQuantityBadge(current: item.quantity),
              ],
            ),
          );
        }),
        if (trip.items.length > maxPreviewItems)
          Padding(
            padding: EdgeInsets.only(top: context.spacingXs),
            child: Text(
              'trips.more_items'.tr(
                args: [(trip.items.length - maxPreviewItems).toString()],
              ),
              style: TextStyle(
                fontSize: context.fontSizeXs,
                color: context.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
