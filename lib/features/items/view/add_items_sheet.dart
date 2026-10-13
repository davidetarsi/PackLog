import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/ds_sheet_header.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';

enum AddItemsMethod { aiScan, manual }

/// Scelta fatta nel foglio: chi lo apre decide come navigare.
class AddItemsChoice {
  final AddItemsMethod method;
  final String houseId;
  const AddItemsChoice(this.method, this.houseId);
}

/// Casa proposta di default: la principale, altrimenti la prima.
HouseModel? defaultDestinationHouse(List<HouseModel> houses) {
  if (houses.isEmpty) return null;
  return houses.firstWhere((h) => h.isPrimary, orElse: () => houses.first);
}

/// Foglio dell'azione principale della tab Case. Non naviga: restituisce la
/// scelta, così la shell usa il proprio contesto (quello del foglio è già
/// smontato quando la `Future` si completa).
Future<AddItemsChoice?> showAddItemsSheet(BuildContext context) {
  return showModalBottomSheet<AddItemsChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const AddItemsSheet(),
  );
}

class AddItemsSheet extends ConsumerStatefulWidget {
  const AddItemsSheet({super.key});

  @override
  ConsumerState<AddItemsSheet> createState() => _AddItemsSheetState();
}

class _AddItemsSheetState extends ConsumerState<AddItemsSheet> {
  String? _selectedHouseId;

  HouseModel? _destination(List<HouseModel> houses) {
    for (final h in houses) {
      if (h.id == _selectedHouseId) return h;
    }
    return defaultDestinationHouse(houses);
  }

  Future<void> _chooseHouse(List<HouseModel> houses, HouseModel current) async {
    final picked = await DsPickerSheet.show<HouseModel>(
      context: context,
      title: 'items.add_sheet.choose_house'.tr(),
      items: houses,
      getLabel: (h) => h.displayName,
      getIcon: (h) => HouseIcons.getIcon(h.iconName),
      selected: current,
    );
    if (picked != null && mounted) {
      setState(() => _selectedHouseId = picked.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final house = _destination(houses);

    return Padding(
      padding: EdgeInsets.only(bottom: AppConstants.bottomSheetBottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSheetHeader(title: 'items.add_sheet.title'.tr()),
          if (house != null)
            ListTile(
              key: const Key('add_items_destination'),
              leading: Icon(HouseIcons.getIcon(house.iconName)),
              title: Text('items.add_sheet.destination'.tr()),
              subtitle: Text(house.displayName),
              trailing: const Icon(Icons.unfold_more),
              onTap: () => _chooseHouse(houses, house),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacingMd,
              vertical: context.spacingSm,
            ),
            child: Material(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(
                AppConstants.cardBorderRadius,
              ),
              child: InkWell(
                key: const Key('add_items_ai_scan'),
                borderRadius: BorderRadius.circular(
                  AppConstants.cardBorderRadius,
                ),
                onTap: house == null
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(AddItemsChoice(AddItemsMethod.aiScan, house.id)),
                child: Padding(
                  padding: EdgeInsets.all(context.spacingMd),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: context.iconSizeLg,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      SizedBox(width: context.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'items.add_sheet.ai_scan'.tr(),
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            SizedBox(height: context.spacingXs),
                            Text(
                              'items.add_sheet.ai_scan_hint'.tr(),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
            child: DsButton(
              key: const Key('add_items_manual'),
              label: 'items.add_sheet.manual'.tr(),
              icon: Icons.edit_outlined,
              variant: DsButtonVariant.secondary,
              expand: true,
              onPressed: house == null
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(AddItemsChoice(AddItemsMethod.manual, house.id)),
            ),
          ),
        ],
      ),
    );
  }
}
