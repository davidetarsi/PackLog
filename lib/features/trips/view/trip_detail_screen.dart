import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_checkbox.dart';
import '../../../shared/widgets/ds_not_found_state.dart';
import '../../../shared/widgets/ds_group_header.dart';
import '../../../shared/widgets/ds_section_title.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../houses/providers/house_provider.dart';
import '../../items/model/item_model.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import 'widgets/pack/pack_parts.dart';
import 'widgets/pack/pack_summary_line.dart';
import 'widgets/pack/pack_weather.dart';

enum _TripMenu { edit, duplicate, save, delete }

/// La valigia del viaggio mentre la si fa: cosa c'è da portare e cosa è già
/// dentro. È la pagina valigia (lo step 2 del nuovo viaggio) vista nel momento
/// dopo: stessi pezzi (riepilogo, meteo, bagagli, oggetti per categoria), ma
/// qui si spunta invece di scegliere.
///
/// Un solo bottone, "Modifica valigia", che apre la pagina valigia; modifica
/// del viaggio, copia, salvati ed eliminazione stanno nel menu ⋮, come nel
/// dettaglio casa.
class TripDetailScreen extends ConsumerWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripNotifierProvider);

    return tripsAsync.when(
      data: (trips) {
        final trip = trips.where((t) => t.id == tripId).firstOrNull;
        if (trip == null) return _notFound(context);
        return _TripDetail(trip: trip);
      },
      loading: () => const SkeletonTripDetailScreen(),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text('common.error'.tr())),
        body: DsErrorState(
          error: error,
          title: 'errors.load_trips'.tr(),
          onRetry: () => ref.read(tripNotifierProvider.notifier).refresh(),
        ),
      ),
    );
  }

  Widget _notFound(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('trips.not_found'.tr())),
      body: DsNotFoundState(
        icon: Icons.luggage_outlined,
        title: 'trips.not_found'.tr(),
        actionLabel: 'common.back_to_trips'.tr(),
        onAction: () => context.go('/trips'),
      ),
    );
  }
}

class _TripDetail extends ConsumerWidget {
  final TripModel trip;

  const _TripDetail({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final destinationHouse = houses
        .where((h) => h.id == trip.destinationHouseId)
        .firstOrNull;
    final hasItems = trip.items.isNotEmpty;

    return StickyCtaScaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<_TripMenu>(
            key: const Key('trip_detail_menu'),
            icon: const Icon(Icons.more_vert),
            onSelected: (choice) => _onMenu(context, ref, choice),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _TripMenu.edit,
                child: Text('trips.detail.edit_trip'.tr()),
              ),
              PopupMenuItem(
                value: _TripMenu.duplicate,
                child: Text('trips.detail.duplicate'.tr()),
              ),
              PopupMenuItem(
                value: _TripMenu.save,
                child: Text(
                  trip.isSaved
                      ? 'trips.detail.unsave'.tr()
                      : 'trips.detail.save'.tr(),
                ),
              ),
              PopupMenuItem(
                value: _TripMenu.delete,
                child: Text(
                  'common.delete'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomContent: DsButton(
        key: const Key('trip_detail_cta'),
        label: hasItems
            ? 'trips.detail.edit_suitcase'.tr()
            : 'trips.pack.title'.tr(),
        icon: hasItems ? Icons.edit_outlined : Icons.luggage_outlined,
        expand: true,
        onPressed: () => context.push('/trips/${trip.id}/edit-items'),
      ),
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            context.spacingSm,
            context.spacingMd,
            context.spacingLg + context.ctaReservedHeight,
          ),
          children: [
            // Il riepilogo è la cartolina del viaggio: toccarlo apre la
            // modifica di date e tappe.
            InkWell(
              key: const Key('trip_detail_summary'),
              borderRadius: BorderRadius.circular(
                AppConstants.cardBorderRadius,
              ),
              onTap: () => context.push('/trips/${trip.id}/edit-info'),
              child: PackSummaryLine(
                trip: trip,
                destinationHouseName: destinationHouse?.displayName,
                houseNames: {for (final h in houses) h.id: h.displayName},
              ),
            ),
            PackWeatherSection(tripId: trip.id),
            if (trip.luggages.isNotEmpty) ...[
              DsSectionTitle('trips.pack.luggages'.tr()),
              Wrap(
                spacing: context.spacingSm,
                runSpacing: context.spacingSm,
                children: [
                  for (final luggage in trip.luggages)
                    PackPill(label: luggage.name, icon: Icons.luggage_outlined),
                ],
              ),
            ],
            _ItemsSection(trip: trip),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    _TripMenu choice,
  ) async {
    final notifier = ref.read(tripNotifierProvider.notifier);
    switch (choice) {
      case _TripMenu.edit:
        context.push('/trips/${trip.id}/edit-info');
      case _TripMenu.duplicate:
        final ok = await ErrorRetryDialog.executeWithRetry(
          context: context,
          operation: () => notifier.duplicateTrip(
            trip.id,
            nameSuffix: 'trips.duplicate_suffix'.tr(),
          ),
          errorTitle: 'errors.save_error'.tr(),
          errorMessage: 'errors.duplicate_trip_failed'.tr(args: [trip.name]),
        );
        if (ok && context.mounted) {
          AppSnackBar.showSuccess(context, 'trips.detail.duplicated'.tr());
        }
      case _TripMenu.save:
        await ErrorRetryDialog.executeWithRetry(
          context: context,
          operation: () => notifier.toggleSaved(trip.id),
          errorTitle: 'errors.save_error'.tr(),
          errorMessage: 'errors.save_trip_failed'.tr(args: [trip.name]),
        );
      case _TripMenu.delete:
        await _delete(context, ref);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: 'common.trip_type'.tr(),
      itemName: trip.name,
    );
    if (confirmed != true || !context.mounted) return;
    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () =>
          ref.read(tripNotifierProvider.notifier).deleteTrip(trip.id),
      errorTitle: 'errors.delete_error'.tr(),
      errorMessage: 'errors.delete_trip_failed'.tr(args: [trip.name]),
    );
    if (success && context.mounted) context.pop();
  }
}

/// "Cosa porti": quanti sono già in valigia, poi gli oggetti per categoria
/// in ordine canonico, come nella pagina valigia e nella casa.
class _ItemsSection extends ConsumerWidget {
  final TripModel trip;

  const _ItemsSection({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = trip.items;

    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: context.spacingLg),
        child: DsEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'trips.no_items_in_list'.tr(),
        ),
      );
    }

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
            Material(
              color: context.groupSurface,
              borderRadius: BorderRadius.circular(
                AppConstants.cardBorderRadius,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final item in items.where((i) => i.category == category))
                    _PackedRow(
                      item: item,
                      onToggle: () => ref
                          .read(tripNotifierProvider.notifier)
                          .toggleItemCheck(trip.id, item.id),
                    ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}

/// Riga di un oggetto da mettere in valigia: casella, nome e quantità. Una
/// volta dentro il nome si spegne e si barra; tutta la riga spunta.
class _PackedRow extends StatelessWidget {
  final TripItem item;
  final VoidCallback onToggle;

  const _PackedRow({required this.item, required this.onToggle});

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
