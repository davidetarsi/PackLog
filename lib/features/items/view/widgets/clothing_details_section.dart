import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_choice_group.dart';
import '../../../../shared/widgets/ds_choice_pill.dart';
import '../../../../shared/widgets/ds_field.dart';
import '../../../../shared/widgets/ds_field_label.dart';
import '../../../../shared/widgets/ds_picker_sheet.dart';
import '../../model/clothing_colors.dart';
import '../../model/clothing_details.dart';
import '../../model/clothing_labels.dart';
import '../../model/clothing_taxonomy.dart';
import '../../providers/user_colors_provider.dart';

/// Sezione "Dettagli" di un capo: tipo, colore, calore, pioggia, stile e usi,
/// a tag. Non salva nulla: ogni tocco emette i dettagli nuovi con [onChanged].
///
/// [doubts] sono i campi che il server segnala incerti ('subCategory',
/// 'warmth', 'waterResistance', 'formality'): mostrano "da controllare" finché
/// l'utente non li tocca, e il tocco chiama [onDoubtResolved] con il campo.
class ClothingDetailsSection extends ConsumerWidget {
  final ClothingDetails details;
  final ValueChanged<ClothingDetails> onChanged;
  final Set<String> doubts;
  final ValueChanged<String>? onDoubtResolved;

  const ClothingDetailsSection({
    super.key,
    required this.details,
    required this.onChanged,
    this.doubts = const {},
    this.onDoubtResolved,
  });

  /// Se i colori dell'utente non arrivano (in caricamento o in errore) si
  /// mostrano solo quelli di base: nessuno spinner.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userColors =
        ref.watch(userColorsProvider).valueOrNull ?? const <String>[];

    void resolved(String field) => onDoubtResolved?.call(field);
    String? toCheck(String field) =>
        doubts.contains(field) ? 'clothing.details.to_check'.tr() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TypeRow(
          value: details.subCategory,
          doubtNote: toCheck('subCategory'),
          onPicked: (type) {
            onChanged(details.copyWith(subCategory: type));
            resolved('subCategory');
          },
        ),
        _ColorChoice(
          color: details.color,
          userColors: userColors,
          onChanged: (color) => onChanged(
            color == null
                ? details.copyWith(clearColor: true)
                : details.copyWith(color: color),
          ),
        ),
        DsChoiceGroup<int>(
          title: 'clothing.details.warmth'.tr(),
          options: kWarmthLevels,
          labelOf: warmthLabel,
          selected: {details.warmth},
          onChanged: (s) => onChanged(details.copyWith(warmth: s.single)),
          doubt: doubts.contains('warmth'),
          note: toCheck('warmth'),
          onTouched: () => resolved('warmth'),
        ),
        DsChoiceGroup<int>(
          title: 'clothing.details.water'.tr(),
          options: kWaterResistanceLevels,
          labelOf: waterResistanceLabel,
          selected: {details.waterResistance},
          onChanged: (s) =>
              onChanged(details.copyWith(waterResistance: s.single)),
          doubt: doubts.contains('waterResistance'),
          note: toCheck('waterResistance'),
          onTouched: () => resolved('waterResistance'),
        ),
        DsChoiceGroup<String>(
          title: 'clothing.details.formality'.tr(),
          options: kFormalities,
          labelOf: formalityLabel,
          selected: {details.formality},
          onChanged: (s) => onChanged(details.copyWith(formality: s.single)),
          doubt: doubts.contains('formality'),
          note: toCheck('formality'),
          onTouched: () => resolved('formality'),
        ),
        DsChoiceGroup<String>(
          title: 'clothing.details.uses'.tr(),
          options: kActivityTags,
          labelOf: activityLabel,
          selected: details.uses,
          multiple: true,
          note: 'clothing.details.uses_hint'.tr(),
          onChanged: (s) => onChanged(details.copyWith(uses: s)),
        ),
      ],
    );
  }
}

/// Riga "Tipo": il valore a destra, tocco per scegliere dal picker raggruppato
/// per categoria.
class _TypeRow extends StatelessWidget {
  final String value;
  final String? doubtNote;
  final ValueChanged<String> onPicked;

  const _TypeRow({
    required this.value,
    required this.doubtNote,
    required this.onPicked,
  });

  Future<void> _pick(BuildContext context) async {
    final options = [
      for (final category in kClothingCategories)
        for (final type in kClothingTypes[category] ?? const <String>[])
          (category: category, type: type),
    ];
    final current = clothingCategoryOf(value);
    final picked = await DsPickerSheet.show<({String category, String type})>(
      context: context,
      title: 'clothing.details.choose_type'.tr(),
      items: options,
      getLabel: (o) => clothingTypeLabel(o.type),
      groupOf: (o) => clothingGroupLabel(o.category),
      selected: options
          .where(
            (o) => o.type == value && (current ?? o.category) == o.category,
          )
          .firstOrNull,
    );
    if (picked != null) onPicked(picked.type);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: const Key('clothing_type_row'),
      borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
      onTap: () => _pick(context),
      child: Padding(
        padding: EdgeInsets.only(
          top: context.spacingLg,
          bottom: context.spacingXs,
        ),
        child: Row(
          children: [
            Text(
              'clothing.details.type'.tr(),
              style: DsFieldLabel.prominentStyle(context),
            ),
            if (doubtNote != null) ...[
              SizedBox(width: context.spacingSm),
              Icon(
                Icons.help_outline,
                size: context.iconSizeSm,
                color: cs.onSurface,
              ),
              SizedBox(width: context.spacingXs / 2),
              Flexible(
                child: Text(
                  doubtNote!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: cs.onSurface),
                ),
              ),
            ],
            SizedBox(width: context.spacingMd),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        clothingTypeLabel(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: context.iconSizeMd,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gruppo "Colore": i colori di base e dell'utente, più "+ Altro colore" che
/// apre un campo di testo. Il colore del capo, se non è tra le scelte, si
/// aggiunge in coda e risulta selezionato.
class _ColorChoice extends StatefulWidget {
  final String? color;
  final List<String> userColors;

  /// `null` per togliere il colore.
  final ValueChanged<String?> onChanged;

  const _ColorChoice({
    required this.color,
    required this.userColors,
    required this.onChanged,
  });

  @override
  State<_ColorChoice> createState() => _ColorChoiceState();
}

class _ColorChoiceState extends State<_ColorChoice> {
  final _controller = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    _controller.clear();
    setState(() => _adding = false);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final options = colorChoices(widget.userColors);
    final current = widget.color?.trim();
    Set<String> selected = {};
    if (current != null && current.isNotEmpty) {
      final match = options.where(
        (o) => o.toLowerCase() == current.toLowerCase(),
      );
      if (match.isNotEmpty) {
        selected = {match.first};
      } else {
        options.add(current);
        selected = {current};
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsChoiceGroup<String>(
          title: 'clothing.details.color'.tr(),
          options: options,
          labelOf: colorLabel,
          selected: selected,
          required: false,
          onChanged: (s) => widget.onChanged(s.isEmpty ? null : s.single),
          trailing: DsChoicePill(
            label: 'clothing.details.other_color'.tr(),
            selected: false,
            onTap: () => setState(() => _adding = true),
          ),
        ),
        if (_adding)
          Padding(
            padding: EdgeInsets.only(top: context.spacingXs),
            child: DsTextField(
              key: const Key('clothing_color_field'),
              controller: _controller,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              hintText: 'clothing.details.color_hint'.tr(),
              onSubmitted: _submit,
            ),
          ),
      ],
    );
  }
}
