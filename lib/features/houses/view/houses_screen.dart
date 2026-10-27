import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/house_provider.dart';
import '../providers/house_stats_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../model/house_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/entity_action_handler.dart';
import '../../../shared/widgets/entity_context_menu.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import '../../../shared/widgets/refreshable_empty_state.dart';
import '../../../shared/widgets/tab_header.dart';
import 'widgets/new_house_row.dart';

class HousesScreen extends ConsumerStatefulWidget {
  const HousesScreen({super.key});

  @override
  ConsumerState<HousesScreen> createState() => _HousesScreenState();
}

class _HousesScreenState extends ConsumerState<HousesScreen> {
  @override
  Widget build(BuildContext context) {
    final housesAsync = ref.watch(houseNotifierProvider);
    final isSyncing = ref.watch(syncingProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ShellTabScaffold(
      body: Column(
        children: [
          TabHeader(title: 'navigation.houses'.tr()),
          Expanded(
            child: housesAsync.when(
              skipLoadingOnReload: true,
              data: (houses) {
                // Lista vuota durante un fullPull = DB appena svuotato (account switch
                // o primo avvio), non "utente senza case". Mostra skeleton finché il
                // pull non porta i dati reali.
                if (houses.isEmpty && isSyncing) {
                  return const SkeletonHousesBody();
                }
                if (houses.isEmpty) {
                  // Stato vuoto scrollabile: senza AlwaysScrollableScrollPhysics
                  // il gesto pull-to-refresh non verrebbe rilevato.
                  return RefreshableEmptyState(
                    onRefresh: () => ref.refresh(houseNotifierProvider.future),
                    icon: Icons.home_outlined,
                    title: 'houses.no_houses_title'.tr(),
                    action: const NewHouseRow(emphasized: true),
                  );
                }

                // Ordina le case: prima quella principale, poi le altre
                final sortedHouses = houses.toList()
                  ..sort((a, b) {
                    if (a.isPrimary && !b.isPrimary) return -1;
                    if (!a.isPrimary && b.isPrimary) return 1;
                    return 0;
                  });

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(houseNotifierProvider.future),
                  color: colorScheme.primary,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // `bottom`: vedi [ShellTabScaffold] — il contenuto scorre dietro
                    // la nav bar flottante, questo padding tiene l'ultima card
                    // raggiungibile.
                    padding: EdgeInsets.only(
                      top: context.spacingSm,
                      bottom: context.navBarReservedHeight,
                    ),
                    itemCount: sortedHouses.length + 1,
                    itemBuilder: (context, index) {
                      if (index == sortedHouses.length) {
                        return const NewHouseRow();
                      }
                      final house = sortedHouses[index];
                      return _HouseCard(house: house);
                    },
                  ),
                );
              },
              loading: () => const SkeletonHousesBody(),
              error: (error, stack) => DsErrorState(
                error: error,
                title: 'errors.load_houses'.tr(),
                onRetry: () =>
                    ref.read(houseNotifierProvider.notifier).refresh(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseCard extends ConsumerWidget {
  final HouseModel house;

  const _HouseCard({required this.house});

  Future<void> _onLongPress(BuildContext context, WidgetRef ref) async {
    final action = await showEntityContextMenu(
      context: context,
      entityType: 'common.house_type'.tr(),
      showSetPrimaryAction: true,
      isPrimary: house.isPrimary,
    );
    if (action == null || !context.mounted) return;

    await EntityActionHandler.handleAction(
      context: context,
      action: action,
      entityTypeLabel: 'common.house_type'.tr(),
      entityName: house.displayName,
      onCopy: () async {
        await ref.read(houseNotifierProvider.notifier).duplicateHouse(house.id);
      },
      copyErrorMessage: 'errors.save_house_failed'.tr(),
      copySuccessMessage: 'dialogs.copy_success'.tr(args: [house.displayName]),
      onDelete: () async {
        await ref.read(houseNotifierProvider.notifier).deleteHouse(house.id);
      },
      deleteErrorMessage: 'errors.delete_failed'.tr(args: [house.displayName]),
      deleteSuccessMessage: 'houses.delete'.tr(),
      onSetPrimary: () async {
        await ref
            .read(houseNotifierProvider.notifier)
            .setPrimaryHouse(house.id);
      },
      setPrimaryErrorMessage: 'errors.save_house_failed'.tr(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final stats = ref.watch(houseStatsProvider(house.id)).valueOrNull;
    final place = house.name.trim().isNotEmpty
        ? house.locationDisplayName ?? house.description
        : null;
    final statsLine = stats == null
        ? null
        : [
            'houses.total_items'.tr(args: [stats.totalItems.toString()]),
            if (stats.hasItemsInTrip) 'houses.badge_in_trip'.tr(),
            if (stats.hasTemporaryItems) 'houses.badge_guest'.tr(),
          ].join(' · ');
    final radius = BorderRadius.circular(AppConstants.cardBorderRadius);

    // Blocco come i gruppi del resto dell'app: superficie appena diversa,
    // niente bordo né divisori. Icona e puntina grigie: in questa pagina
    // l'arancio è solo di Crea.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingXs,
      ),
      child: Material(
        color: context.groupSurface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/houses/${house.id}'),
          onLongPress: () => _onLongPress(context, ref),
          child: Padding(
            padding: EdgeInsets.all(context.spacingMd),
            child: Row(
              children: [
                Container(
                  padding: context.cardPaddingDense,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: radius,
                  ),
                  child: Icon(
                    HouseIcons.getIcon(house.iconName),
                    color: cs.onSurfaceVariant,
                    size: context.iconSizeMd,
                  ),
                ),
                SizedBox(width: context.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              house.displayName,
                              style: tt.titleMedium?.copyWith(
                                fontSize: AppSpacing.fontMd,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // push_pin = casa principale (il segnalibro è dei
                          // viaggi salvati).
                          if (house.isPrimary) ...[
                            SizedBox(width: context.spacingXs),
                            Icon(
                              Icons.push_pin_outlined,
                              key: const Key('house_primary_pin'),
                              size: context.iconSizeSm,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      if (place != null)
                        Text(
                          place,
                          style: tt.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (statsLine != null)
                        Text(
                          statsLine,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
