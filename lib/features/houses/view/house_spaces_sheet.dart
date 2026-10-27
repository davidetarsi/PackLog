import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/ds_not_found_state.dart';
import '../../../shared/constants/space_icons.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_form_sheet.dart';
import '../../../shared/widgets/ds_group_header.dart';
import '../../../shared/widgets/ds_settings.dart';
import '../providers/house_provider.dart';
import '../../items/providers/item_provider.dart';
import '../../spaces/providers/space_provider.dart';
import '../../spaces/view/add_edit_space_screen.dart';

/// Gli spazi appartengono alla casa e si gestiscono senza lasciare il dettaglio.
Future<void> showHouseSpacesSheet(
  BuildContext context, {
  required String houseId,
}) => showDsFormSheet<void>(
  context,
  builder: (_) => HouseSpacesSheet(houseId: houseId),
);

class HouseSpacesSheet extends ConsumerWidget {
  const HouseSpacesSheet({super.key, required this.houseId});
  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DsFormSheet(
    key: const Key('house_spaces'),
    title: 'spaces.title'.tr(),
    child: ref
        .watch(houseNotifierProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _error(
            context,
            error,
            () => ref.invalidate(houseNotifierProvider),
          ),
          data: (houses) {
            final house = houses.where((h) => h.id == houseId).firstOrNull;
            if (house == null) {
              return DsNotFoundState(
                key: const Key('storage_not_found'),
                icon: Icons.home_outlined,
                title: 'houses.house_not_found'.tr(),
                actionLabel: 'common.close'.tr(),
                onAction: () => Navigator.pop(context),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  house.displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                _spaces(context, ref),
              ],
            );
          },
        ),
  );

  Widget _error(BuildContext context, Object error, VoidCallback onRetry) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacingMd),
        child: DsErrorState(
          error: error,
          title: 'storage.load_failed'.tr(),
          onRetry: onRetry,
        ),
      );

  Widget _spaces(BuildContext context, WidgetRef ref) => ref
      .watch(spaceNotifierProvider(houseId))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _error(
          context,
          error,
          () => ref.invalidate(spaceNotifierProvider(houseId)),
        ),
        data: (spaces) => ref
            .watch(itemNotifierProvider(houseId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _error(
                context,
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
}
