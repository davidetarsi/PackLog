import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';
import '../../spaces/model/space_model.dart';
import '../../spaces/providers/space_provider.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/constants/space_icons.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/widgets/ds_form_sheet.dart';
import '../../../shared/widgets/ds_group_header.dart';
import '../../../shared/widgets/ds_settings.dart';

class BulkMoveDestination {
  const BulkMoveDestination({
    required this.houseId,
    required this.houseDisplayName,
    this.spaceId,
  });

  final String houseId;
  final String houseDisplayName;
  final String? spaceId;
}

class BulkMoveSheet extends ConsumerStatefulWidget {
  const BulkMoveSheet({
    super.key,
    required this.itemCount,
    required this.sourceHouseId,
  });

  final int itemCount;
  final String sourceHouseId;

  static Future<BulkMoveDestination?> show(
    BuildContext context, {
    required int itemCount,
    required String sourceHouseId,
  }) {
    return showDsSheet<BulkMoveDestination>(
      context,
      builder: (_) =>
          BulkMoveSheet(itemCount: itemCount, sourceHouseId: sourceHouseId),
    );
  }

  @override
  ConsumerState<BulkMoveSheet> createState() => _BulkMoveSheetState();
}

class _BulkMoveSheetState extends ConsumerState<BulkMoveSheet> {
  HouseModel? _selectedHouse;
  bool _isLoadingSpaces = false;
  bool _isFinishing = false;

  Future<void> _selectHouse(HouseModel house) async {
    if (_isLoadingSpaces || _isFinishing) return;
    setState(() {
      _isLoadingSpaces = true;
      _selectedHouse = house;
    });
    await _loadSpaces(house);
  }

  Future<void> _loadSpaces(HouseModel house) async {
    try {
      final spaces = await ref.read(spaceNotifierProvider(house.id).future);
      if (!mounted) return;
      setState(() => _isLoadingSpaces = false);
      if (spaces.isEmpty) _finish(house, null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSpaces = false);
    }
  }

  void _finish(HouseModel house, String? spaceId) {
    if (_isFinishing) return;
    _isFinishing = true;
    Navigator.of(context).pop(
      BulkMoveDestination(
        houseId: house.id,
        houseDisplayName: house.displayName,
        spaceId: spaceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final housesAsync = ref.watch(houseNotifierProvider);
    final spacesAsync = _selectedHouse != null
        ? ref.watch(spaceNotifierProvider(_selectedHouse!.id))
        : null;

    return DsFormSheet(
      title: 'items.bulk_move_sheet_title'.plural(
        widget.itemCount,
        args: [widget.itemCount.toString()],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          housesAsync.when(
            data: (allHouses) {
              final otherHouses = allHouses
                  .where((h) => h.id != widget.sourceHouseId)
                  .toList();
              if (otherHouses.isEmpty) return const SizedBox.shrink();
              return DsSettingsGroup(
                children: [
                  for (final house in otherHouses)
                    DsSettingsRow(
                      leading: Icon(
                        HouseIcons.getIcon(house.iconName),
                        color: _selectedHouse?.id == house.id
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                      label: house.displayName,
                      trailing:
                          _isLoadingSpaces && _selectedHouse?.id == house.id
                          ? SizedBox.square(
                              dimension: context.spacingLg,
                              child: const CircularProgressIndicator(),
                            )
                          : null,
                      enabled: !_isLoadingSpaces,
                      onTap: _isLoadingSpaces
                          ? null
                          : () => _selectHouse(house),
                    ),
                ],
              );
            },
            loading: () => Padding(
              padding: EdgeInsets.all(context.spacingMd),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => DsErrorState(
              error: error,
              title: 'errors.load_houses'.tr(),
              onRetry: () => ref.invalidate(houseNotifierProvider),
            ),
          ),
          if (_selectedHouse != null && spacesAsync != null)
            _buildSpaceSection(_selectedHouse!, spacesAsync),
        ],
      ),
    );
  }

  Widget _buildSpaceSection(
    HouseModel house,
    AsyncValue<List<SpaceModel>> spacesAsync,
  ) {
    final cs = Theme.of(context).colorScheme;

    return spacesAsync.when(
      data: (spaces) {
        if (spaces.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsGroupHeader(label: 'spaces.title'.tr()),
            DsSettingsGroup(
              children: [
                DsSettingsRow(
                  leading: Icon(Icons.inventory_2, color: cs.onSurfaceVariant),
                  label: 'spaces.default'.tr(),
                  enabled: !_isLoadingSpaces && !_isFinishing,
                  onTap: _isLoadingSpaces || _isFinishing
                      ? null
                      : () => _finish(house, null),
                ),
                for (final s in spaces)
                  DsSettingsRow(
                    leading: Icon(
                      SpaceIcons.getIcon(s.iconName ?? 'meeting_room'),
                      color: cs.onSurfaceVariant,
                    ),
                    label: s.name,
                    enabled: !_isLoadingSpaces && !_isFinishing,
                    onTap: _isLoadingSpaces || _isFinishing
                        ? null
                        : () => _finish(house, s.id),
                  ),
              ],
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.all(context.spacingMd),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => DsErrorState(
        error: error,
        title: 'storage.load_failed'.tr(),
        onRetry: _isLoadingSpaces ? () {} : () => _retrySpaces(house),
      ),
    );
  }

  Future<void> _retrySpaces(HouseModel house) async {
    if (_isLoadingSpaces || _isFinishing) return;
    setState(() => _isLoadingSpaces = true);
    ref.invalidate(spaceNotifierProvider(house.id));
    await _loadSpaces(house);
  }
}
