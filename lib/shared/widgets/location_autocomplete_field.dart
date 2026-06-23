import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../helpers/snack_bar_helper.dart';
import '../model/model.dart';
import '../theme/app_spacing.dart';

/// Widget riutilizzabile per l'autocomplete delle località.
/// Usa l'API Geoapify per cercare città, regioni e stati.
///
/// I suggerimenti appaiono dalla terza lettera digitata.
class LocationAutocompleteField extends StatefulWidget {
  /// Valore iniziale del campo
  final String? initialValue;

  /// Callback chiamata quando viene selezionata una località
  final ValueChanged<LocationSuggestionModel>? onLocationSelected;

  /// Callback chiamata quando il testo cambia (anche senza selezione)
  final ValueChanged<String>? onTextChanged;

  /// Label del campo
  final String? labelText;

  /// Stile personalizzato per la label
  final TextStyle? labelStyle;

  /// Hint del campo
  final String? hintText;

  /// Stile personalizzato per l'hint text
  final TextStyle? hintStyle;

  /// Numero minimo di caratteri per iniziare la ricerca
  final int minCharsForSearch;

  /// Ritardo in millisecondi prima di effettuare la ricerca (debounce)
  final int debounceMs;

  /// Se mostrare il bordo del campo di input
  final bool showBorder;

  /// Se usare un layout compatto (meno padding interno)
  final bool isDense;

  const LocationAutocompleteField({
    super.key,
    this.initialValue,
    this.onLocationSelected,
    this.onTextChanged,
    this.labelText,
    this.labelStyle,
    this.hintText,
    this.hintStyle,
    this.minCharsForSearch = 3,
    this.debounceMs = 300,
    this.showBorder = true,
    this.isDense = false,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  List<LocationSuggestionModel> _suggestions = [];
  bool _isLoading = false;
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
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _onTextChanged() {
    if (_ignoreNextChange) {
      _ignoreNextChange = false;
      return;
    }

    final text = _controller.text;
    widget.onTextChanged?.call(text);

    // Cancella il timer precedente
    _debounceTimer?.cancel();

    if (text.length < widget.minCharsForSearch) {
      _removeOverlay();
      setState(() {
        _suggestions = [];
      });
      return;
    }

    // Debounce: aspetta prima di fare la richiesta
    _debounceTimer = Timer(
      Duration(milliseconds: widget.debounceMs),
      () => _searchLocations(text),
    );
  }

  Future<void> _searchLocations(String query) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final suggestions = await _fetchLocationSuggestions(query);

      if (!mounted) return;

      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });

      if (suggestions.isNotEmpty && _focusNode.hasFocus) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } on _GeocodeRateLimitException {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _removeOverlay();
      // Feedback esplicito all'utente: senza questo vedrebbe "nessun
      // risultato" e penserebbe che la località non esista.
      AppSnackBar.showWarning(
        context,
        'location_search.rate_limit_reached'.tr(),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _removeOverlay();
    }
  }

  Future<List<LocationSuggestionModel>> _fetchLocationSuggestions(
    String query,
  ) async {
    final uri = Uri.parse('${AppConfig.supabaseUrl}/functions/v1/geocode-proxy')
        .replace(
          queryParameters: {
            'text': query,
            'lang': context.locale.languageCode.substring(0, 2),
            'limit': '15',
            'bias': 'countrycode:none',
          },
        );

    // Il proxy esegue `getUser(token)` per il rate-limit per-utente: serve
    // il JWT dell'utente loggato, non l'anon key. L'auth gate del router
    // garantisce che chiunque possa raggiungere questo widget sia loggato;
    // in caso edge di sessione scaduta tra il check e qui, ritorniamo
    // suggestion vuoti senza errori — l'utente proverà a digitare ancora.
    final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
    if (jwt == null) return [];

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $jwt',
          'apikey': AppConfig.supabaseAnonKey,
        },
      );

      if (response.statusCode == 429) {
        throw const _GeocodeRateLimitException();
      }

      if (response.statusCode != 200) {
        throw Exception('Errore HTTP Geoapify: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final geoapifyResponse = GeoapifyResponseModel.fromJson(json);

      final suggestions = geoapifyResponse.features
          .map(
            (feature) => LocationSuggestionModel.fromGeoapifyFeature(feature),
          )
          .where((s) => s.displayName.isNotEmpty)
          // ARCHITECTURE CHOICE: Filtro applicativo per garantire solo macro-aree.
          // Scartiamo tutto ciò che finisce nel bucket 'other' (strade, ristoranti, etc.)
          .where((s) => s.locationType != LocationType.other)
          .toList();

      final seen = <String>{};
      final uniqueSuggestions = <LocationSuggestionModel>[];

      for (final suggestion in suggestions) {
        if (seen.add(suggestion.deduplicationKey)) {
          uniqueSuggestions.add(suggestion);
        }
      }

      return uniqueSuggestions.take(5).toList();
    } catch (e) {
      // In produzione, loggare l'errore su Crashlytics/Sentry, non stamparlo solo in console
      debugPrint('[LocationAutocompleteField] Errore API: $e');
      rethrow;
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _getFieldWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, _getFieldHeight() + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
            child: _buildSuggestionsList(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  double _getFieldWidth() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  double _getFieldHeight() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.height ?? 56;
  }

  Widget _buildSuggestionsList() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(context.spacingMd),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return _buildSuggestionTile(suggestion, index);
        },
      ),
    );
  }

  Widget _buildSuggestionTile(LocationSuggestionModel suggestion, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    // Scegli l'icona in base al tipo di località
    final icon = switch (suggestion.locationType) {
      LocationType.country => Icons.flag_outlined,
      LocationType.state => Icons.map_outlined,
      LocationType.city => Icons.location_city_outlined,
      LocationType.other => Icons.location_on_outlined,
    };

    // Costruisci il sottotitolo con le info aggiuntive
    final subtitle = _buildSubtitle(suggestion);

    // Usa il nome principale, oppure il displayName come fallback
    final title = suggestion.name ?? suggestion.displayName;

    return InkWell(
      onTap: () => _selectSuggestion(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: index < _suggestions.length - 1
              ? Border(bottom: BorderSide(color: colorScheme.outlineVariant))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: context.fontSizeXxs,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Costruisce il sottotitolo in base al tipo di località
  String? _buildSubtitle(LocationSuggestionModel suggestion) {
    final parts = <String>[];

    switch (suggestion.locationType) {
      case LocationType.city:
        // Per le città, mostra stato e paese
        if (suggestion.state != null && suggestion.state != suggestion.name) {
          parts.add(suggestion.state!);
        }
        if (suggestion.country != null) {
          parts.add(suggestion.country!);
        }
        break;

      case LocationType.state:
        // Per le regioni/stati, mostra solo il paese
        if (suggestion.country != null &&
            suggestion.country != suggestion.name) {
          parts.add(suggestion.country!);
        }
        break;

      case LocationType.country:
      case LocationType.other:
        // Per i paesi e altri, nessun sottotitolo
        break;
    }

    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  void _selectSuggestion(LocationSuggestionModel suggestion) {
    _ignoreNextChange = true;
    _controller.text = suggestion.displayName;
    _removeOverlay();
    widget.onLocationSelected?.call(suggestion);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelText: widget.labelText ?? 'common.destination'.tr(),
          labelStyle: widget.labelStyle,
          isDense: widget.isDense,
          hintText: widget.hintText ?? 'common.search_location_hint'.tr(),
          hintStyle: widget.hintStyle,
          border: widget.showBorder
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.inputBorderRadius,
                  ),
                )
              : InputBorder.none,
          enabledBorder: widget.showBorder
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.inputBorderRadius,
                  ),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1,
                  ),
                )
              : InputBorder.none,
          focusedBorder: widget.showBorder
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.inputBorderRadius,
                  ),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                )
              : InputBorder.none,
          prefixIcon: null,
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: colorScheme.primary),
                  onPressed: () {
                    _controller.clear();
                    widget.onTextChanged?.call('');
                    _removeOverlay();
                  },
                )
              : null,
        ),
      ),
    );
  }
}

/// Sentinella interna: distingue il 429 del rate-limit dagli altri errori
/// così da poter mostrare un messaggio specifico in `_searchLocations`.
class _GeocodeRateLimitException implements Exception {
  const _GeocodeRateLimitException();
}
