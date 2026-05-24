import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';
import '../../spaces/model/space_model.dart';
import '../../spaces/providers/space_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/constants/space_icons.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/universal_action_bar.dart';

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
    return showModalBottomSheet<BulkMoveDestination>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          BulkMoveSheet(itemCount: itemCount, sourceHouseId: sourceHouseId),
    );
  }

  @override
  ConsumerState<BulkMoveSheet> createState() => _BulkMoveSheetState();
}

class _BulkMoveSheetState extends ConsumerState<BulkMoveSheet> {
  HouseModel? _selectedHouse;
  String? _selectedSpaceId;

  Future<void> _pickHouse(List<HouseModel> allHouses) async {
    final otherHouses = allHouses
        .where((h) => h.id != widget.sourceHouseId)
        .toList();
    final picked = await DsPickerSheet.show<HouseModel>(
      context: context,
      title: 'items.bulk_move_title'.tr(),
      items: otherHouses,
      getLabel: (h) => h.displayName,
      getSubtitle: (h) => h.isPrimary ? 'houses.primary'.tr() : null,
      getIcon: (h) => HouseIcons.getIcon(h.iconName),
      selected: _selectedHouse,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedHouse = picked;
      _selectedSpaceId = null;
    });
  }

  void _confirm() {
    if (_selectedHouse == null) return;
    Navigator.of(context).pop(
      BulkMoveDestination(
        houseId: _selectedHouse!.id,
        houseDisplayName: _selectedHouse!.displayName,
        spaceId: _selectedSpaceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allHouses = ref.watch(houseNotifierProvider).value ?? [];
    final spacesAsync = _selectedHouse != null
        ? ref.watch(spacesByHouseProvider(_selectedHouse!.id))
        : null;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.modalBorderRadius),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BottomSheetHandle(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingMd,
                vertical: context.spacingSm,
              ),
              child: Text(
                'items.bulk_move_sheet_title'.tr(
                  args: [widget.itemCount.toString()],
                ),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: Icon(
                _selectedHouse != null
                    ? HouseIcons.getIcon(_selectedHouse!.iconName)
                    : Icons.home_outlined,
                color: cs.primary,
              ),
              title: Text(
                _selectedHouse?.displayName ?? 'common.select_house'.tr(),
                style: _selectedHouse == null
                    ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      )
                    : null,
              ),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () => _pickHouse(allHouses),
            ),
            const Divider(height: 1),
            if (_selectedHouse != null) _buildSpaceList(spacesAsync!),
            SizedBox(height: context.spacingMd),
            UniversalActionBar(
              primaryLabel: 'common.move'.tr(),
              primaryIcon: Icons.local_shipping_outlined,
              onPrimaryPressed: _selectedHouse == null ? null : _confirm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpaceList(AsyncValue<List<SpaceModel>> spacesAsync) {
    final cs = Theme.of(context).colorScheme;

    final defaultTile = ListTile(
      leading: Icon(Icons.inventory_2, color: cs.onSurfaceVariant),
      title: Text('spaces.default'.tr()),
      trailing: _selectedSpaceId == null
          ? Icon(Icons.check, color: cs.primary)
          : null,
      onTap: () => setState(() => _selectedSpaceId = null),
    );

    return spacesAsync.when(
      data: (spaces) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          defaultTile,
          ...spaces.map(
            (s) => ListTile(
              leading: Icon(
                SpaceIcons.getIcon(s.iconName ?? 'meeting_room'),
                color: cs.onSurfaceVariant,
              ),
              title: Text(s.name),
              trailing: _selectedSpaceId == s.id
                  ? Icon(Icons.check, color: cs.primary)
                  : null,
              onTap: () => setState(() => _selectedSpaceId = s.id),
            ),
          ),
        ],
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, stack) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          defaultTile,
          ListTile(
            enabled: false,
            leading: const Icon(Icons.error_outline),
            title: Text('errors.load_failed'.tr()),
          ),
        ],
      ),
    );
  }
}
