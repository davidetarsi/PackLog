import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_search_feedback.dart';
import '../model/model.dart';
import '../services/location_search_service.dart';
import '../theme/app_spacing.dart';
import 'ds_search_field.dart';
import 'ds_settings.dart';
import 'location_result_row.dart';

/// Campo per cercare un luogo (città, regione o paese) tramite
/// [locationSearchServiceProvider]. Unico in tutta l'app: luogo della casa,
/// meta e tappe del viaggio.
///
/// I risultati stanno sotto il campo, nella pagina, come nella ricerca della
/// meta del nuovo viaggio: niente pannello sovrapposto che copre il resto del
/// foglio. Compaiono dalla terza lettera.
class LocationAutocompleteField extends ConsumerStatefulWidget {
  /// Valore iniziale del campo
  final String? initialValue;

  /// Callback chiamata quando viene selezionata una località
  final ValueChanged<LocationSuggestionModel>? onLocationSelected;

  /// Callback chiamata quando il testo cambia (anche senza selezione)
  final ValueChanged<String>? onTextChanged;

  /// Hint del campo
  final String? hintText;

  /// Numero minimo di caratteri per iniziare la ricerca
  final int minCharsForSearch;

  /// Ritardo in millisecondi prima di effettuare la ricerca (debounce)
  final int debounceMs;

  /// Errore sotto il campo, con il bordo del colore di errore: per esempio
  /// il luogo obbligatorio che manca.
  final String? errorText;

  const LocationAutocompleteField({
    super.key,
    this.initialValue,
    this.onLocationSelected,
    this.onTextChanged,
    this.hintText,
    this.minCharsForSearch = 3,
    this.debounceMs = 300,
    this.errorText,
  });

  @override
  ConsumerState<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends ConsumerState<LocationAutocompleteField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<LocationSuggestionModel> _suggestions = [];
  bool _isLoading = false;
  Object? _searchError;
  int _requestId = 0;

  /// Ultima ricerca completata: serve a dire "nessun luogo" solo dopo una
  /// risposta vera, non mentre si scrive.
  String? _searchedQuery;
  Timer? _debounceTimer;

  // Per evitare di fare ricerche dopo aver selezionato
  bool _ignoreNextChange = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
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
    if (_ignoreNextChange) {
      _ignoreNextChange = false;
      return;
    }

    final text = _controller.text;
    widget.onTextChanged?.call(text);

    _debounceTimer?.cancel();
    // I risultati sono della ricerca precedente: non restano sotto il testo
    // nuovo durante l'attesa.
    setState(() {
      _suggestions = [];
      _searchedQuery = null;
      _searchError = null;
      _isLoading = false;
      _requestId++;
    });
    if (text.trim().length < widget.minCharsForSearch) return;

    _debounceTimer = Timer(
      Duration(milliseconds: widget.debounceMs),
      () => _searchLocations(text.trim()),
    );
  }

  Future<void> _searchLocations(String query) async {
    if (!mounted || query != _controller.text.trim()) return;
    final request = ++_requestId;
    setState(() {
      _isLoading = true;
      _searchError = null;
    });
    try {
      final suggestions = await ref
          .read(locationSearchServiceProvider)
          .search(query, lang: context.locale.languageCode);
      if (!mounted ||
          request != _requestId ||
          _controller.text.trim() != query) {
        return;
      }
      setState(() {
        _suggestions = suggestions;
        _searchedQuery = query;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted ||
          request != _requestId ||
          _controller.text.trim() != query) {
        return;
      }
      setState(() {
        _suggestions = [];
        _searchError = error;
        _isLoading = false;
      });
    }
  }

  void _selectSuggestion(LocationSuggestionModel suggestion) {
    _debounceTimer?.cancel();
    _requestId++;
    _ignoreNextChange = true;
    _controller.text = suggestion.displayName;
    setState(() {
      _suggestions = [];
      _searchError = null;
      _searchedQuery = null;
      _isLoading = false;
    });
    widget.onLocationSelected?.call(suggestion);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hint = widget.hintText ?? 'common.search_location_hint'.tr();

    final showResults = _focusNode.hasFocus;
    final noResults =
        showResults &&
        !_isLoading &&
        _searchError == null &&
        _suggestions.isEmpty &&
        _searchedQuery != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsSearchField(
          controller: _controller,
          focusNode: _focusNode,
          hintText: hint,
          errorText: widget.errorText,
          isLoading: _isLoading,
        ),
        if (showResults && _suggestions.isNotEmpty) ...[
          SizedBox(height: context.spacingSm),
          // Il tocco su una riga non deve togliere il focus prima del suo
          // onTap: senza questo la lista sparisce al primo tocco.
          TextFieldTapRegion(
            child: DsSettingsGroup(
              children: [
                for (final (i, s) in _suggestions.indexed)
                  LocationResultRow(
                    key: Key('location_result_$i'),
                    place: s,
                    onTap: () => _selectSuggestion(s),
                  ),
              ],
            ),
          ),
        ],
        if (showResults && _searchError != null)
          LocationSearchFeedback(
            error: _searchError!,
            onRetry: () => _searchLocations(_controller.text.trim()),
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
