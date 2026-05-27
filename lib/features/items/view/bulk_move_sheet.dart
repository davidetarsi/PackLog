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
  bool _spaceConfirmed = false;
  String? _selectedSpaceId;

  Future<void> _selectHouse(HouseModel house) async {
    final spaces = await ref.read(spacesByHouseProvider(house.id).future);
    if (!mounted) return;
    setState(() {
      _selectedHouse = house;
      _spaceConfirmed = spaces.isEmpty;
      _selectedSpaceId = null;
    });
  }

  void _confirm() {
    if (_selectedHouse == null || !_spaceConfirmed) return;
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
    final housesAsync = ref.watch(houseNotifierProvider);
    final spacesAsync = _selectedHouse != null
        ? ref.watch(spacesByHouseProvider(_selectedHouse!.id))
        : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
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
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    housesAsync.when(
                      data: (allHouses) {
                        final otherHouses = allHouses
                            .where((h) => h.id != widget.sourceHouseId)
                            .toList();
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: otherHouses
                              .map(
                                (house) => ListTile(
                                  leading: Icon(
                                    HouseIcons.getIcon(house.iconName),
                                    color: _selectedHouse?.id == house.id
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                  title: Text(house.displayName),
                                  trailing: _selectedHouse?.id == house.id
                                      ? Icon(Icons.check, color: cs.primary)
                                      : null,
                                  onTap: () => _selectHouse(house),
                                ),
                              )
                              .toList(),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, _) => ListTile(
                        enabled: false,
                        leading: const Icon(Icons.error_outline),
                        title: Text('errors.load_failed'.tr()),
                      ),
                    ),
                    if (_selectedHouse != null && spacesAsync != null)
                      _buildSpaceSection(spacesAsync),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.spacingMd),
            UniversalActionBar(
              primaryLabel: 'common.move'.tr(),
              primaryIcon: Icons.local_shipping_outlined,
              onPrimaryPressed: (_selectedHouse != null && _spaceConfirmed)
                  ? _confirm
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpaceSection(AsyncValue<List<SpaceModel>> spacesAsync) {
    final cs = Theme.of(context).colorScheme;

    return spacesAsync.when(
      data: (spaces) {
        if (spaces.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.inventory_2, color: cs.onSurfaceVariant),
              title: Text('spaces.default'.tr()),
              trailing: (_spaceConfirmed && _selectedSpaceId == null)
                  ? Icon(Icons.check, color: cs.primary)
                  : null,
              onTap: () => setState(() {
                _selectedSpaceId = null;
                _spaceConfirmed = true;
              }),
            ),
            ...spaces.map(
              (s) => ListTile(
                leading: Icon(
                  SpaceIcons.getIcon(s.iconName ?? 'meeting_room'),
                  color: cs.onSurfaceVariant,
                ),
                title: Text(s.name),
                trailing: (_spaceConfirmed && _selectedSpaceId == s.id)
                    ? Icon(Icons.check, color: cs.primary)
                    : null,
                onTap: () => setState(() {
                  _selectedSpaceId = s.id;
                  _spaceConfirmed = true;
                }),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, stack) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
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
