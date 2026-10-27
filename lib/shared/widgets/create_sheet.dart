import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/houses/model/house_model.dart';
import '../../features/houses/providers/house_provider.dart';
import '../../features/profile/providers/gpt_usage_provider.dart';
import '../constants/app_constants.dart';
import '../constants/house_icons.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'ds_form_sheet.dart';
import 'ds_group_header.dart';
import 'ds_picker_sheet.dart';

enum CreateAction { aiScan, manualItems, newHouse, newTrip, aiSuitcase }

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
/// L'ordine delle voci è lo stesso da ogni tab.
Future<CreateChoice?> showCreateSheet(BuildContext context) {
  return showDsSheet<CreateChoice>(
    context,
    builder: (_) => const CreateSheet(),
  );
}

class CreateSheet extends ConsumerStatefulWidget {
  const CreateSheet({super.key});

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

    return DsFormSheet(
      title: 'create_sheet.title'.tr(),
      // Il padding laterale è già nelle card AI e nelle righe a tutta larghezza.
      padding: EdgeInsets.only(bottom: context.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Le due strade con l'AI, alla pari e sopra le loro corrispondenti
          // a mano. L'ordine è lo stesso da ogni tab.
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.spacingMd,
              context.spacingSm,
              context.spacingMd,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AiCard(
                  key: const Key('create_ai_scan'),
                  icon: Icons.photo_camera_outlined,
                  title: 'create_sheet.ai_scan'.tr(),
                  hint: house == null
                      ? 'create_sheet.need_house'.tr()
                      : aiExhausted
                      ? 'create_sheet.ai_exhausted'.tr()
                      : 'create_sheet.ai_scan_hint'.tr(),
                  onTap: house == null || aiExhausted
                      ? null
                      : () => _choose(CreateAction.aiScan, house.id),
                  footer: house == null
                      ? null
                      : _HouseChooser(
                          house: house,
                          onTap: () => _chooseHouse(houses, house),
                        ),
                ),
                SizedBox(height: context.spacingSm),
                _AiCard(
                  key: const Key('create_ai_suitcase'),
                  icon: Icons.auto_awesome_outlined,
                  title: 'create_sheet.ai_suitcase'.tr(),
                  hint: aiExhausted
                      ? 'create_sheet.ai_exhausted'.tr()
                      : 'create_sheet.ai_suitcase_hint'.tr(),
                  onTap: aiExhausted
                      ? null
                      : () => _choose(CreateAction.aiSuitcase),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
            child: DsGroupHeader(label: 'create_sheet.without_ai'.tr()),
          ),
          _CreateRow(
            key: const Key('create_manual_items'),
            icon: Icons.edit_outlined,
            title: 'create_sheet.manual'.tr(),
            subtitle: house == null
                ? 'create_sheet.manual_need_house'.tr()
                : 'create_sheet.manual_hint'.tr(args: [house.displayName]),
            onTap: house == null
                ? null
                : () => _choose(CreateAction.manualItems, house.id),
          ),
          _CreateRow(
            key: const Key('create_new_trip'),
            icon: Icons.luggage_outlined,
            title: 'create_sheet.new_trip'.tr(),
            subtitle: 'create_sheet.new_trip_hint'.tr(),
            onTap: () => _choose(CreateAction.newTrip),
          ),
          _CreateRow(
            key: const Key('create_new_house'),
            icon: Icons.home_outlined,
            title: 'create_sheet.new_house'.tr(),
            subtitle: 'create_sheet.new_house_hint'.tr(),
            // Senza case è l'unica strada: la si mette in evidenza.
            emphasized: houses.isEmpty,
            onTap: () => _choose(CreateAction.newHouse),
          ),
        ],
      ),
    );
  }
}

/// Card di una funzione AI: velo arancio con il bordo, icona a sinistra in un
/// riquadro. Le due card hanno lo stesso peso; spente perdono velo e bordo.
class _AiCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? onTap;

  /// Sotto il testo, allineato a lui: la scelta della casa.
  final Widget? footer;

  const _AiCard({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enabled = onTap != null;

    final background = enabled
        ? Color.alphaBlend(
            colorScheme.primary.withValues(alpha: AppOpacity.selected),
            colorScheme.surface,
          )
        : colorScheme.onSurface.withValues(alpha: AppOpacity.pressed);
    // Testi neutri come nel resto del foglio; l'arancio resta all'icona.
    final disabledColor = colorScheme.onSurface.withValues(
      alpha: AppOpacity.disabled,
    );
    final iconColor = enabled ? colorScheme.onPrimaryContainer : disabledColor;
    final titleColor = enabled ? colorScheme.onSurface : disabledColor;
    final hintColor = enabled ? colorScheme.onSurfaceVariant : disabledColor;
    final radius = BorderRadius.circular(AppConstants.cardBorderRadius);

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: enabled
            ? BorderSide(
                color: colorScheme.primary,
                width: AppConstants.hairlineBorderWidth,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          // La scelta della casa ha già il suo spazio di tocco: sotto basta
          // poco margine.
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            context.spacingMd,
            context.spacingMd,
            footer == null ? context.spacingMd : context.spacingXs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(context.spacingSm),
                decoration: BoxDecoration(
                  color: enabled
                      ? colorScheme.primaryContainer
                      : colorScheme.onSurface.withValues(
                          alpha: AppOpacity.pressed,
                        ),
                  borderRadius: BorderRadius.circular(
                    AppConstants.badgeBorderRadius,
                  ),
                ),
                child: Icon(icon, size: context.iconSizeMd, color: iconColor),
              ),
              SizedBox(width: context.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(color: titleColor),
                    ),
                    SizedBox(height: context.spacingXs),
                    Text(
                      hint,
                      style: textTheme.bodyMedium?.copyWith(color: hintColor),
                    ),
                    if (footer != null) footer!,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Casa in cui finiscono gli oggetti scansionati: testo neutro con la freccia
/// del menu, allineato al testo della card.
class _HouseChooser extends StatelessWidget {
  final HouseModel house;
  final VoidCallback onTap;

  const _HouseChooser({required this.house, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.onSurface;

    return InkWell(
      key: const Key('create_destination'),
      borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              HouseIcons.getIcon(house.iconName),
              size: context.iconSizeSm,
              color: color,
            ),
            SizedBox(width: context.spacingXs),
            Flexible(
              child: Text(
                'create_sheet.in_house'.tr(args: [house.displayName]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.strong.copyWith(color: color),
              ),
            ),
            Icon(Icons.expand_more, size: context.iconSizeSm, color: color),
          ],
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

  /// `null` spegne la riga (oggetti a mano senza nessuna casa).
  final VoidCallback? onTap;

  const _CreateRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final accent = !enabled
        ? colorScheme.onSurface.withValues(alpha: AppOpacity.disabled)
        : emphasized
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return ListTile(
      enabled: enabled,
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
        style: emphasized
            ? Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colorScheme.primary)
            : null,
      ),
      subtitle: Text(subtitle),
    );
  }
}
