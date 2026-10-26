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
            const DsBottomSheetHandle(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingMd,
                vertical: context.spacingSm,
              ),
              child: Text(
                'items.bulk_move_sheet_title'.plural(
                  widget.itemCount,
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
                                  trailing:
                                      _isLoadingSpaces &&
                                          _selectedHouse?.id == house.id
                                      ? SizedBox.square(
                                          dimension: context.spacingLg,
                                          child:
                                              const CircularProgressIndicator(),
                                        )
                                      : null,
                                  enabled: !_isLoadingSpaces,
                                  onTap: _isLoadingSpaces
                                      ? null
                                      : () => _selectHouse(house),
                                ),
                              )
                              .toList(),
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
              ),
            ),
          ],
        ),
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
          children: [
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.inventory_2, color: cs.onSurfaceVariant),
              title: Text('spaces.default'.tr()),
              enabled: !_isLoadingSpaces && !_isFinishing,
              onTap: _isLoadingSpaces || _isFinishing
                  ? null
                  : () => _finish(house, null),
            ),
            ...spaces.map(
              (s) => ListTile(
                leading: Icon(
                  SpaceIcons.getIcon(s.iconName ?? 'meeting_room'),
                  color: cs.onSurfaceVariant,
                ),
                title: Text(s.name),
                enabled: !_isLoadingSpaces && !_isFinishing,
                onTap: _isLoadingSpaces || _isFinishing
                    ? null
                    : () => _finish(house, s.id),
              ),
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
