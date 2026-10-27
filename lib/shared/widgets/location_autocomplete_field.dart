import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_search_feedback.dart';
import '../model/model.dart';
import '../services/location_search_service.dart';
import '../theme/app_spacing.dart';
import 'ds_group_header.dart';
import 'ds_search_field.dart';
import 'ds_settings.dart';
import 'location_result_row.dart';

/// Caratteri minimi prima di cercare un luogo.
const int kLocationSearchMinChars = 3;

/// Attesa tra un tasto e la richiesta dei luoghi.
const Duration kLocationSearchDebounce = Duration(milliseconds: 300);

/// Scrive [text] nel campo come scelta già fatta: niente ricerca, risultati e
/// tastiera chiusi.
typedef LocationFill = void Function(String text);

/// Campo per cercare un luogo (città, regione o paese) tramite
/// [locationSearchServiceProvider]. È l'unico dell'app: luogo della casa,
/// meta e tappe del viaggio passano tutti da qui, quindi rotella al posto
/// della x, errori, "nessun luogo" e righe dei risultati sono uguali ovunque.
///
/// I risultati stanno sotto il campo, nella pagina, non in overlay, e
/// compaiono dalla terza lettera. Con [leadingResults] sopra i luoghi si
/// aggiungono altri risultati (le case dell'utente nel viaggio).
class LocationAutocompleteField extends ConsumerStatefulWidget {
  const LocationAutocompleteField({
    super.key,
    this.initialValue,
    this.onLocationSelected,
    this.onTextChanged,
    this.hintText,
    this.autofocus = false,
    this.hasError = false,
    this.errorText,
    this.placesLabel,
    this.leadingResults,
  });

  /// Testo del campo all'apertura, per un luogo già scelto.
  final String? initialValue;

  /// Il luogo scelto fra i risultati della ricerca.
  final ValueChanged<LocationSuggestionModel>? onLocationSelected;

  /// A ogni modifica digitata del testo; non per una scelta.
  final ValueChanged<String>? onTextChanged;

  /// Se null, `common.search_location_hint`.
  final String? hintText;

  final bool autofocus;

  /// Bordo in colore di errore senza testo (luogo obbligatorio che manca).
  final bool hasError;

  /// Errore sotto il campo, con il bordo in colore di errore.
  final String? errorText;

  /// Intestazione sopra i luoghi trovati; senza, i luoghi non ne hanno.
  final String? placesLabel;

  /// Risultati da mostrare sopra i luoghi mentre il campo ha il focus, anche
  /// a campo vuoto. Riceve il testo cercato (minuscolo, senza spazi ai lati)
  /// e [LocationFill] per scrivere nel campo la scelta fatta.
  final Widget? Function(String query, LocationFill fill)? leadingResults;

  @override
  ConsumerState<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends ConsumerState<LocationAutocompleteField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  final FocusNode _focusNode = FocusNode();

  Timer? _debounceTimer;
  List<LocationSuggestionModel> _places = const [];
  Object? _searchError;
  bool _isSearching = false;

  /// Ultima ricerca completata: "nessun luogo" solo dopo una risposta vera,
  /// non mentre si scrive.
  String? _searchedQuery;
  int _requestId = 0;

  /// Vero mentre la scelta scrive il nome nel campo. Il controller notifica
  /// più volte durante quella scrittura (anche per la selezione del testo),
  /// quindi il filtro vale per tutta la durata e non per una sola notifica.
  bool _writingChoice = false;

  /// Ultimo testo visto. Il controller notifica anche quando cambia solo la
  /// selezione (un tocco che mette il cursore): quelle notifiche non sono
  /// modifiche del testo e vanno ignorate.
  late String _lastText;

  @override
  void initState() {
    super.initState();
    // Inizializzato qui e non alla dichiarazione: un valore pigro, letto per la
    // prima volta dopo una modifica, coinciderebbe con il testo nuovo e il
    // primo tasto verrebbe scartato.
    _lastText = _controller.text;
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
    final query = text.trim();
    // I luoghi mostrati sono della ricerca precedente: durante l'attesa non
    // devono restare sotto il testo nuovo.
    setState(() {
      _places = const [];
      _searchError = null;
      _searchedQuery = null;
      _isSearching = false;
      _requestId++;
    });
    if (query.length < kLocationSearchMinChars) return;

    _debounceTimer = Timer(kLocationSearchDebounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted || query != _controller.text.trim()) return;
    final request = ++_requestId;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final results = await ref
          .read(locationSearchServiceProvider)
          .search(query, lang: Localizations.localeOf(context).languageCode);
      if (!mounted ||
          request != _requestId ||
          _controller.text.trim() != query) {
        return;
      }
      setState(() {
        _places = results;
        _searchedQuery = query;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted ||
          request != _requestId ||
          _controller.text.trim() != query) {
        return;
      }
      setState(() {
        _places = const [];
        _searchError = error;
        _isSearching = false;
      });
    }
  }

  /// Scrive la scelta nel campo, chiude risultati e tastiera.
  void _fill(String text) {
    _debounceTimer?.cancel();
    _requestId++;
    if (_controller.text != text) {
      _writingChoice = true;
      try {
        _controller.text = text;
      } finally {
        _writingChoice = false;
      }
    }
    _focusNode.unfocus();
    setState(() {
      _places = const [];
      _searchError = null;
      _searchedQuery = null;
      _isSearching = false;
    });
  }

  void _selectPlace(LocationSuggestionModel place) {
    _fill(place.displayName);
    widget.onLocationSelected?.call(place);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final showResults = _focusNode.hasFocus;
    final leading = showResults
        ? widget.leadingResults?.call(
            _controller.text.trim().toLowerCase(),
            _fill,
          )
        : null;
    final noResults =
        showResults &&
        !_isSearching &&
        _searchError == null &&
        _searchedQuery != null &&
        _places.isEmpty;
    final placesLabel = widget.placesLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsSearchField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          hasError: widget.hasError,
          errorText: widget.errorText,
          isLoading: _isSearching,
          hintText: widget.hintText ?? 'common.search_location_hint'.tr(),
        ),
        if (leading != null) ...[
          SizedBox(height: context.spacingSm),
          // Il tocco su una riga non deve togliere il focus prima del suo
          // onTap: senza questo la lista sparisce al primo tocco.
          TextFieldTapRegion(child: leading),
        ],
        if (showResults && _places.isNotEmpty) ...[
          SizedBox(height: context.spacingSm),
          TextFieldTapRegion(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (placesLabel != null)
                  DsGroupHeader(label: placesLabel, count: _places.length),
                DsSettingsGroup(
                  children: [
                    for (final (i, place) in _places.indexed)
                      LocationResultRow(
                        key: Key('location_result_$i'),
                        place: place,
                        onTap: () => _selectPlace(place),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (showResults && _searchError != null)
          LocationSearchFeedback(
            error: _searchError!,
            onRetry: () => _search(_controller.text.trim()),
          ),
        if (noResults)
          Padding(
            padding: EdgeInsets.only(
              top: context.spacingSm,
              left: context.spacingMd,
            ),
            child: Text(
              'location_search.no_results'.tr(),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
