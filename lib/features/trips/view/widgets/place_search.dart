import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/constants/house_icons.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_group_header.dart';
import '../../../../shared/widgets/ds_settings.dart';
import '../../../../shared/widgets/location_autocomplete_field.dart';
import '../../../houses/model/house_model.dart';
import '../../../houses/providers/house_provider.dart';
import '../../model/trip_draft.dart';

/// Campo unico per scegliere la meta o una tappa: le case dell'utente e i
/// luoghi della ricerca. È il [LocationAutocompleteField] di tutta l'app, con
/// le case sopra i luoghi.
///
/// Il campo vuoto e attivo mostra le case. Scrivendo filtra le case per nome
/// e, dopo una breve attesa, aggiunge i luoghi. Scelto un posto, [onSelected]
/// riceve il [DraftPlace] e la lista si chiude.
class PlaceSearch extends ConsumerWidget {
  const PlaceSearch({
    super.key,
    required this.onSelected,
    this.onTextChanged,
    this.hintText,
    this.initialText,
    this.autofocus = false,
    this.hasError = false,
  });

  final ValueChanged<DraftPlace> onSelected;

  /// Chiamata a ogni modifica digitata del testo. Non scatta per la scelta di
  /// un posto: quella passa da [onSelected].
  final ValueChanged<String>? onTextChanged;

  /// Se null, il testo di default è `trips.new.where_hint`.
  final String? hintText;

  /// Testo del campo all'apertura, per modificare un posto già scelto.
  final String? initialText;

  final bool autofocus;

  /// Bordo in colore di errore, quando il campo è obbligatorio e manca.
  final bool hasError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];

    return LocationAutocompleteField(
      initialValue: initialText,
      autofocus: autofocus,
      hasError: hasError,
      hintText: hintText ?? 'trips.new.where_hint'.tr(),
      placesLabel: 'trips.new.places'.tr(),
      onTextChanged: onTextChanged,
      onLocationSelected: (place) => onSelected(DraftPlace.location(place)),
      leadingResults: (query, fill) {
        final matching = query.isEmpty
            ? houses
            : houses
                  .where((h) => h.displayName.toLowerCase().contains(query))
                  .toList();
        if (matching.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsGroupHeader(
              label: 'trips.new.your_homes'.tr(),
              count: matching.length,
            ),
            DsSettingsGroup(
              children: [
                for (final house in matching)
                  _HouseRow(
                    key: Key('place_search_house_${house.id}'),
                    house: house,
                    onTap: () {
                      fill(house.displayName);
                      onSelected(
                        DraftPlace.house(id: house.id, name: house.displayName),
                      );
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HouseRow extends StatelessWidget {
  const _HouseRow({super.key, required this.house, required this.onTap});

  final HouseModel house;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMd,
          vertical: context.spacingMd,
        ),
        child: Row(
          children: [
            Icon(
              HouseIcons.getIcon(house.iconName),
              size: context.iconSizeMd,
              color: cs.onSurfaceVariant,
            ),
            SizedBox(width: context.spacingMd),
            Expanded(
              child: Text(
                house.displayName,
                style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
