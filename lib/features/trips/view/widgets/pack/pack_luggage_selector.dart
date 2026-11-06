import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_error_state.dart';
import '../../../../../shared/widgets/ds_link_button.dart';
import '../../../../luggages/model/luggage_model.dart';
import '../../../../luggages/providers/luggage_provider.dart';
import '../../../../luggages/view/add_edit_luggage_screen.dart';
import '../../../../luggages/view/luggages_management_sheet.dart';
import 'pack_parts.dart';

class PackLuggageSelector extends ConsumerWidget {
  final Set<String> selectedIds;
  final ValueChanged<LuggageModel> onToggle;
  final ValueChanged<List<LuggageModel>> onCreated;

  const PackLuggageSelector({
    super.key,
    required this.selectedIds,
    required this.onToggle,
    required this.onCreated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(luggageNotifierProvider)
        .when(
          data: (luggages) {
            if (luggages.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'trips.pack.no_luggages'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  _newLuggage(context),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: context.spacingSm,
                  runSpacing: context.spacingSm,
                  children: [
                    for (final luggage in luggages)
                      PackPill(
                        label: luggage.name,
                        icon: Icons.luggage_outlined,
                        selected: selectedIds.contains(luggage.id),
                        onTap: () => onToggle(luggage),
                      ),
                  ],
                ),
                DsLinkButton(
                  key: const Key('pack_manage_luggages'),
                  icon: Icons.edit_outlined,
                  label: 'luggages.manage'.tr(),
                  onPressed: () async {
                    final before = {for (final luggage in luggages) luggage.id};
                    await showLuggagesManagementSheet(context);
                    if (!context.mounted) return;
                    final latest = ref
                        .read(luggageNotifierProvider)
                        .valueOrNull;
                    if (latest == null) return;
                    onCreated([
                      for (final luggage in latest)
                        if (!before.contains(luggage.id)) luggage,
                    ]);
                  },
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DsErrorState(
            error: error,
            title: 'luggages.load_failed'.tr(),
            onRetry: () => ref.invalidate(luggageNotifierProvider),
          ),
        );
  }

  Widget _newLuggage(BuildContext context) => DsLinkButton(
    key: const Key('pack_new_luggage'),
    icon: Icons.add,
    label: 'luggages.add_new'.tr(),
    onPressed: () async {
      final created = await showAddEditLuggageSheet(context);
      if (created != null && context.mounted) onCreated([created]);
    },
  );
}
