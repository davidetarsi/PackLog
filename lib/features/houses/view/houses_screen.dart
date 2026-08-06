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
import '../../../shared/widgets/ds_badge.dart';
import '../../../shared/widgets/entity_context_menu.dart';
import 'add_edit_house_screen.dart';
import '../../../shared/widgets/skeleton/skeleton.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import '../../../shared/widgets/refreshable_empty_state.dart';

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
      body: housesAsync.when(
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
              iconColor: colorScheme.primary,
              title: 'houses.no_houses_title'.tr(),
              action: FilledButton.icon(
                onPressed: () => showAddEditHouseSheet(context),
                icon: const Icon(Icons.add),
                label: Text('houses.no_houses_subtitle'.tr()),
              ),
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
            onRefresh: () async => ref.refresh(houseNotifierProvider.future),
            color: colorScheme.primary,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              // `bottom`: vedi [ShellTabScaffold] — il contenuto scorre dietro
              // la nav bar flottante, questo padding tiene l'ultima card
              // raggiungibile.
              padding: EdgeInsets.only(
                top: context.spacingMd,
                bottom: context.navBarReservedHeight,
              ),
              itemCount: sortedHouses.length,
              itemBuilder: (context, index) {
                final house = sortedHouses[index];
                return _HouseCard(house: house);
              },
            ),
          );
        },
        loading: () => const SkeletonHousesBody(),
        error: (error, stack) => DsErrorState(
          error: error,
          onRetry: () => ref.read(houseNotifierProvider.notifier).refresh(),
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(houseStatsProvider(house.id));

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingSm,
      ),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius + 4,
        ),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: /* house.isPrimary ? 1.5 : */ 1,
        ),
      ),
      child: Stack(
        children: [
          InkWell(
            borderRadius: context.responsiveBorderRadius(
              AppConstants.cardBorderRadius + 4,
            ),
            onTap: () {
              context.push('/houses/${house.id}');
            },
            onLongPress: () => _onLongPress(context, ref),
            child: Padding(
              padding: EdgeInsets.all(context.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: context.cardPaddingDense,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: context.responsiveBorderRadius(
                            AppConstants.cardBorderRadius,
                          ),
                        ),
                        child: Icon(
                          HouseIcons.getIcon(house.iconName),
                          color: house.isPrimary
                              ? colorScheme.primary
                              : colorScheme.onPrimaryContainer,
                          size: context.iconSizeMd,
                        ),
                      ),
                      SizedBox(width: context.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              house.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700, // 20px → w700
                                fontSize: context.fontSizeLg,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (house.name.trim().isNotEmpty &&
                                (house.locationDisplayName != null ||
                                    house.description != null)) ...[
                              SizedBox(height: context.spacingXs),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      house.locationDisplayName ??
                                          house.description!,
                                      style: TextStyle(
                                        fontSize: context.fontSizeSm + 1,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Divider
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: context.spacingMd),
                    child: Divider(
                      height: 1,
                      color: colorScheme.outlineVariant,
                    ),
                  ),

                  // Stats row
                  statsAsync.when(
                    skipLoadingOnReload: true,
                    data: (stats) => Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'houses.total_items'.tr(
                            args: [stats.totalItems.toString()],
                          ),
                          style: TextStyle(
                            fontSize: context.fontSizeSm,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (stats.hasItemsInTrip)
                          DsStatusBadge(
                            type: DsStatusBadgeType.onTrip,
                            label: 'houses.badge_in_trip'.tr(),
                          ),
                        if (stats.hasItemsInTrip && stats.hasTemporaryItems)
                          AppSpacing.hGapSm,
                        if (stats.hasTemporaryItems)
                          DsStatusBadge(
                            type: DsStatusBadgeType.temporary,
                            label: 'houses.badge_guest'.tr(),
                          ),
                      ],
                    ),
                    loading: () => const SizedBox(height: 20),
                    error: (error, stackTrace) => const SizedBox(height: 20),
                  ),
                ],
              ),
            ),
          ),

          // Badge principale in alto a destra (stile bookmark/salvato)
          if (house.isPrimary)
            // push_pin = "casa principale/fissata" — non bookmark (riservato ai viaggi salvati)
            Positioned(
              top: 0,
              right: 12,
              child: Icon(Icons.push_pin, size: 20, color: colorScheme.primary),
            ),
        ],
      ),
    );
  }
}
