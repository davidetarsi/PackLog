import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/constants/space_icons.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_group_header.dart';
import '../../../shared/widgets/ds_settings.dart';
import '../providers/house_provider.dart';
import '../../items/providers/item_provider.dart';
import '../../luggages/providers/luggage_provider.dart';
import '../../luggages/view/add_edit_luggage_screen.dart';
import '../../spaces/providers/space_provider.dart';
import '../../spaces/view/add_edit_space_screen.dart';

/// Gestione unica degli spazi e dei bagagli di una casa.
class HouseStorageScreen extends ConsumerWidget {
  const HouseStorageScreen({super.key, required this.houseId});
  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('house_storage'),
      appBar: AppBar(title: Text('storage.title'.tr())),
      body: SafeArea(
        child: ref
            .watch(houseNotifierProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  _error(error, () => ref.invalidate(houseNotifierProvider)),
              data: (houses) {
                final house = houses.where((h) => h.id == houseId).firstOrNull;
                if (house == null) {
                  return DsEmptyState(
                    key: const Key('storage_not_found'),
                    icon: Icons.home_outlined,
                    title: 'houses.house_not_found'.tr(),
                    linkLabel: 'storage.go_home'.tr(),
                    linkKey: const Key('storage_go_home'),
                    onLink: () => context.go('/'),
                  );
                }
                return ListView(
                  padding: EdgeInsets.all(context.spacingMd),
                  children: [
                    Text(
                      house.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    _spaces(context, ref),
                    SizedBox(height: context.spacingLg),
                    _luggages(context, ref),
                  ],
                );
              },
            ),
      ),
    );
  }

  Widget _error(Object error, VoidCallback onRetry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: DsErrorState(
      error: error,
      message: 'storage.load_failed'.tr(),
      onRetry: onRetry,
    ),
  );

  Widget _spaces(BuildContext context, WidgetRef ref) => ref
      .watch(spaceNotifierProvider(houseId))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _error(error, () => ref.invalidate(spaceNotifierProvider(houseId))),
        data: (spaces) => ref
            .watch(itemNotifierProvider(houseId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _error(
                error,
                () => ref.invalidate(itemNotifierProvider(houseId)),
              ),
              data: (items) {
                // Un solo passaggio sulla lista già caricata, senza query per spazio.
                final counts = <String, int>{};
                for (final item in items) {
                  final id = item.spaceId;
                  if (id != null) {
                    counts.update(id, (n) => n + 1, ifAbsent: () => 1);
                  }
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DsGroupHeader(
                      label: 'spaces.title'.tr(),
                      count: spaces.length,
                    ),
                    DsSettingsGroup(
                      children: [
                        for (final space in spaces)
                          DsSettingsRow(
                            key: Key('storage_space_${space.id}'),
                            leading: Icon(
                              SpaceIcons.getIcon(
                                space.iconName ?? 'meeting_room',
                              ),
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            label: space.name,
                            subtitle: 'storage.item_count'.plural(
                              counts[space.id] ?? 0,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showAddEditSpaceSheet(
                              context,
                              houseId: houseId,
                              spaceId: space.id,
                            ),
                          ),
                        DsSettingsRow(
                          key: const Key('storage_add_space'),
                          leading: const Icon(Icons.add),
                          label: 'spaces.add_new'.tr(),
                          onTap: () =>
                              showAddEditSpaceSheet(context, houseId: houseId),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
      );

  Widget _luggages(BuildContext context, WidgetRef ref) => ref
      .watch(luggageNotifierProvider(houseId))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _error(
          error,
          () => ref.invalidate(luggageNotifierProvider(houseId)),
        ),
        data: (luggages) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsGroupHeader(label: 'luggages.title'.tr(), count: luggages.length),
            DsSettingsGroup(
              children: [
                for (final luggage in luggages)
                  DsSettingsRow(
                    key: Key('storage_luggage_${luggage.id}'),
                    leading: Icon(
                      Icons.luggage_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    label: luggage.name,
                    subtitle: luggage.sizeDescription,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showAddEditLuggageSheet(
                      context,
                      houseId: houseId,
                      luggageId: luggage.id,
                    ),
                  ),
                DsSettingsRow(
                  key: const Key('storage_add_luggage'),
                  leading: const Icon(Icons.add),
                  label: 'luggages.add_new'.tr(),
                  onTap: () =>
                      showAddEditLuggageSheet(context, houseId: houseId),
                ),
              ],
            ),
          ],
        ),
      );
}
