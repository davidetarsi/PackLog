import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/houses/model/house_model.dart';
import '../../features/houses/providers/house_provider.dart';
import '../../features/profile/providers/gpt_usage_provider.dart';
import '../constants/app_constants.dart';
import '../constants/house_icons.dart';
import '../theme/app_spacing.dart';
import 'ds_link_button.dart';
import 'ds_picker_sheet.dart';
import 'ds_sheet_header.dart';

enum CreateAction { aiScan, manualItems, newHouse, newTrip }

/// Scelta fatta nel foglio Crea. [houseId] c'è per le azioni sugli oggetti.
class CreateChoice {
  final CreateAction action;
  final String? houseId;
  const CreateChoice(this.action, [this.houseId]);
}

/// Casa proposta di default: la principale, altrimenti la prima.
HouseModel? defaultDestinationHouse(List<HouseModel> houses) {
  if (houses.isEmpty) return null;
  return houses.firstWhere((h) => h.isPrimary, orElse: () => houses.first);
}

/// Foglio del tasto Crea. Non naviga: restituisce la scelta, così la shell usa
/// il proprio contesto (quello del foglio è già smontato quando la `Future` si
/// completa).
///
/// [fromTrips] decide solo l'ordine delle voci sotto la scansione AI: aperto
/// da Viaggi, "Nuovo viaggio" viene prima.
Future<CreateChoice?> showCreateSheet(
  BuildContext context, {
  required bool fromTrips,
}) {
  return showModalBottomSheet<CreateChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CreateSheet(fromTrips: fromTrips),
  );
}

class CreateSheet extends ConsumerStatefulWidget {
  final bool fromTrips;

  const CreateSheet({super.key, required this.fromTrips});

  @override
  ConsumerState<CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends ConsumerState<CreateSheet> {
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
      title: 'create_sheet.choose_house'.tr(),
      items: houses,
      getLabel: (h) => h.displayName,
      getIcon: (h) => HouseIcons.getIcon(h.iconName),
      selected: current,
    );
    if (picked != null && mounted) {
      setState(() => _selectedHouseId = picked.id);
    }
  }

  void _choose(CreateAction action, [String? houseId]) =>
      Navigator.of(context).pop(CreateChoice(action, houseId));

  @override
  Widget build(BuildContext context) {
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final house = _destination(houses);
    final aiExhausted =
        ref.watch(gptUsageProvider).valueOrNull?.isExhausted ?? false;

    final newHouse = _CreateRow(
      key: const Key('create_new_house'),
      icon: Icons.home_outlined,
      title: 'create_sheet.new_house'.tr(),
      subtitle: 'create_sheet.new_house_hint'.tr(),
      // Senza case è l'unica strada: la si mette in evidenza.
      emphasized: houses.isEmpty,
      onTap: () => _choose(CreateAction.newHouse),
    );
    final newTrip = _CreateRow(
      key: const Key('create_new_trip'),
      icon: Icons.luggage_outlined,
      title: 'create_sheet.new_trip'.tr(),
      subtitle: 'create_sheet.new_trip_hint'.tr(),
      onTap: () => _choose(CreateAction.newTrip),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: AppConstants.bottomSheetBottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSheetHeader(title: 'create_sheet.title'.tr()),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.spacingMd,
              context.spacingSm,
              context.spacingMd,
              0,
            ),
            child: _AiScanCard(
              house: house,
              exhausted: aiExhausted,
              onScan: house == null || aiExhausted
                  ? null
                  : () => _choose(CreateAction.aiScan, house.id),
              onChooseHouse: house == null
                  ? null
                  : () => _chooseHouse(houses, house),
            ),
          ),
          if (house != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingSm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DsLinkButton(
                  key: const Key('create_manual_items'),
                  label: 'create_sheet.manual_link'.tr(),
                  onPressed: () => _choose(CreateAction.manualItems, house.id),
                ),
              ),
            )
          else
            SizedBox(height: context.spacingMd),
          ...(widget.fromTrips ? [newTrip, newHouse] : [newHouse, newTrip]),
        ],
      ),
    );
  }
}

/// Card principale del foglio: la strada che vogliamo far seguire.
class _AiScanCard extends StatelessWidget {
  final HouseModel? house;
  final bool exhausted;
  final VoidCallback? onScan;
  final VoidCallback? onChooseHouse;

  const _AiScanCard({
    required this.house,
    required this.exhausted,
    required this.onScan,
    required this.onChooseHouse,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enabled = onScan != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // In chiaro `primaryContainer` è quasi bianco e la card non spiccava:
    // un velo di `primary` sulla superficie la rende arancio deciso.
    final background = !enabled
        ? colorScheme.onSurface.withValues(alpha: 0.08)
        : isDark
        ? colorScheme.primaryContainer
        : Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.22),
            colorScheme.surface,
          );
    final foreground = enabled
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface.withValues(alpha: 0.38);
    final hint = house == null
        ? 'create_sheet.need_house'.tr()
        : exhausted
        ? 'create_sheet.ai_exhausted'.tr()
        : 'create_sheet.ai_scan_hint'.tr();
    final radius = BorderRadius.circular(AppConstants.cardBorderRadius);

    return Material(
      color: background,
      borderRadius: radius,
      child: InkWell(
        key: const Key('create_ai_scan'),
        borderRadius: radius,
        onTap: onScan,
        child: Padding(
          padding: EdgeInsets.all(context.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: context.iconSizeLg,
                    color: foreground,
                  ),
                  SizedBox(width: context.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'create_sheet.ai_scan'.tr(),
                          style: textTheme.titleMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                        SizedBox(height: context.spacingXs),
                        Text(
                          hint,
                          style: textTheme.bodySmall?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (house != null) ...[
                SizedBox(height: context.spacingSm),
                Align(
                  alignment: Alignment.centerRight,
                  // Solo testo e freccia, senza pillola: in scuro una pillola
                  // scura dentro la card arancio appesantiva.
                  child: InkWell(
                    key: const Key('create_destination'),
                    borderRadius: BorderRadius.circular(
                      AppConstants.pillBorderRadius,
                    ),
                    onTap: onChooseHouse,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacingSm,
                        vertical: context.spacingXs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            HouseIcons.getIcon(house!.iconName),
                            size: context.iconSizeSm,
                            color: foreground,
                          ),
                          SizedBox(width: context.spacingXs),
                          Text(
                            'create_sheet.in_house'.tr(
                              args: [house!.displayName],
                            ),
                            style: textTheme.labelLarge?.copyWith(
                              color: foreground,
                            ),
                          ),
                          Icon(
                            Icons.expand_more,
                            size: context.iconSizeSm,
                            color: foreground,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool emphasized;
  final VoidCallback onTap;

  const _CreateRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = emphasized
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: EdgeInsets.all(context.spacingSm),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
        ),
        child: Icon(icon, color: accent),
      ),
      title: Text(
        title,
        style: emphasized ? TextStyle(color: colorScheme.primary) : null,
      ),
      subtitle: Text(subtitle),
    );
  }
}
