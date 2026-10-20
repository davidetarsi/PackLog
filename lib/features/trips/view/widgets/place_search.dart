import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/constants/house_icons.dart';
import '../../../../shared/model/model.dart';
import '../../../../shared/services/location_search_service.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/surface_colors.dart';
import '../../../../shared/widgets/ds_group_header.dart';
import '../../../../shared/widgets/ds_settings.dart';
import '../../../houses/model/house_model.dart';
import '../../../houses/providers/house_provider.dart';
import '../../model/trip_draft.dart';

/// Caratteri minimi prima di cercare luoghi: come [LocationAutocompleteField].
const int _minCharsForPlaces = 3;

/// Attesa tra un tasto e la richiesta dei luoghi.
const Duration _placesDebounce = Duration(milliseconds: 300);

/// Campo unico per scegliere la meta: le case dell'utente e i luoghi della
/// ricerca. I risultati stanno sotto il campo, nella pagina, non in overlay.
///
/// Il campo vuoto e attivo mostra le case. Scrivendo filtra le case per nome
/// e, dopo una breve attesa, aggiunge i luoghi del [LocationSearchService].
/// Scelto un posto, [onSelected] riceve il [DraftPlace] e la lista si chiude.
class PlaceSearch extends ConsumerStatefulWidget {
  const PlaceSearch({
    super.key,
    required this.onSelected,
    this.onTextChanged,
    this.hintText,
    this.initialText,
    this.autofocus = false,
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

  @override
  ConsumerState<PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends ConsumerState<PlaceSearch> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  final FocusNode _focusNode = FocusNode();

  Timer? _debounceTimer;
  List<LocationSuggestionModel> _places = const [];

  /// Vero mentre la scelta scrive il nome nel campo. Il controller notifica
  /// più volte durante quella scrittura (anche per la selezione del testo),
  /// quindi il filtro vale per tutta la durata e non per una sola notifica.
  bool _writingChoice = false;

  /// Ultimo testo visto. Il controller notifica anche quando cambia solo la
  /// selezione (un tocco che mette il cursore): quelle notifiche non sono
  /// modifiche del testo e vanno ignorate.
  late String _lastText = _controller.text;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  void _onTextChanged() {
    final text = _controller.text;
    if (text == _lastText) return;
    _lastText = text;
    if (_writingChoice) return;

    widget.onTextChanged?.call(text);

    _debounceTimer?.cancel();
    final query = _controller.text.trim();
    setState(() {
      if (query.length < _minCharsForPlaces) _places = const [];
    });
    if (query.length < _minCharsForPlaces) return;

    _debounceTimer = Timer(_placesDebounce, () => _searchPlaces(query));
  }

  Future<void> _searchPlaces(String query) async {
    final lang = Localizations.localeOf(context).languageCode;
    List<LocationSuggestionModel> results;
    try {
      results = await ref
          .read(locationSearchServiceProvider)
          .search(query, lang: lang);
    } catch (_) {
      results = const [];
    }
    // Se nel frattempo il testo è cambiato, questa risposta è già superata.
    if (!mounted || _controller.text.trim() != query) return;
    setState(() => _places = results);
  }

  void _select(DraftPlace place, String text) {
    _debounceTimer?.cancel();
    if (_controller.text != text) {
      _writingChoice = true;
      try {
        _controller.text = text;
      } finally {
        _writingChoice = false;
      }
    }
    _focusNode.unfocus();
    setState(() => _places = const []);
    widget.onSelected(place);
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final query = _controller.text.trim().toLowerCase();
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final matchingHouses = query.isEmpty
        ? houses
        : houses
              .where((h) => h.displayName.toLowerCase().contains(query))
              .toList();

    final showResults = _focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'trips.new.where_hint'.tr(),
            prefixIcon: Icon(
              Icons.search,
              size: context.iconSizeMd,
              color: cs.onSurfaceVariant,
            ),
            filled: true,
            fillColor: context.groupSurface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.spacingMd,
              vertical: context.spacingMd,
            ),
            border: _border(cs.outlineVariant, 1),
            enabledBorder: _border(cs.outlineVariant, 1),
            focusedBorder: _border(cs.onSurface, 1.5),
          ),
        ),
        if (showResults && matchingHouses.isNotEmpty) ...[
          SizedBox(height: context.spacingSm),
          // Il tocco su una riga non deve togliere il focus prima del suo
          // onTap: senza questo la lista sparisce al primo tocco.
          TextFieldTapRegion(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DsGroupHeader(
                  label: 'trips.new.your_homes'.tr(),
                  count: matchingHouses.length,
                ),
                DsSettingsGroup(
                  children: [
                    for (final house in matchingHouses)
                      _HouseRow(
                        key: Key('place_search_house_${house.id}'),
                        house: house,
                        onTap: () => _select(
                          DraftPlace.house(
                            id: house.id,
                            name: house.displayName,
                          ),
                          house.displayName,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (showResults && _places.isNotEmpty) ...[
          SizedBox(height: context.spacingSm),
          TextFieldTapRegion(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DsGroupHeader(
                  label: 'trips.new.places'.tr(),
                  count: _places.length,
                ),
                DsSettingsGroup(
                  children: [
                    for (final (i, place) in _places.indexed)
                      _PlaceRow(
                        key: Key('place_search_location_$i'),
                        place: place,
                        onTap: () => _select(
                          DraftPlace.location(place),
                          place.displayName,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HouseRow extends StatelessWidget {
  const _HouseRow({super.key, required this.house, required this.onTap});

  final HouseModel house;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ResultRow(
      icon: HouseIcons.getIcon(house.iconName),
      label: house.displayName,
      onTap: onTap,
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({super.key, required this.place, required this.onTap});

  final LocationSuggestionModel place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ResultRow(
      icon: Icons.place_outlined,
      label: place.displayName,
      onTap: onTap,
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
            Icon(icon, size: context.iconSizeMd, color: cs.onSurfaceVariant),
            SizedBox(width: context.spacingMd),
            Expanded(
              child: Text(
                label,
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
