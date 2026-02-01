import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../constants/app_constants.dart';

/// Tipo di località
enum LocationType {
  city,
  state,
  country,
  other,
}

/// Modello per rappresentare una località restituita dall'API Geoapify
class LocationSuggestion {
  final String placeId;
  final String displayName;
  final String? name; // Nome principale (città, regione o stato)
  final String? city;
  final String? state;
  final String? country;
  final LocationType locationType;
  final double? lat;
  final double? lon;

  const LocationSuggestion({
    required this.placeId,
    required this.displayName,
    this.name,
    this.city,
    this.state,
    this.country,
    this.locationType = LocationType.other,
    this.lat,
    this.lon,
  });

  factory LocationSuggestion.fromGeoapifyJson(Map<String, dynamic> json) {
    final properties = json['properties'] as Map<String, dynamic>? ?? {};
    
    // Ottieni il tipo di risultato dall'API
    final resultType = properties['result_type'] as String? ?? '';
    final city = properties['city'] as String?;
    final state = properties['state'] as String?;
    final county = properties['county'] as String?;
    final country = properties['country'] as String?;
    final formatted = properties['formatted'] as String? ?? '';
    final name = properties['name'] as String?;
    
    // Determina il tipo di località basandosi PRINCIPALMENTE su result_type
    LocationType locationType;
    String? mainName;
    
    // L'API restituisce result_type che è la fonte più affidabile
    switch (resultType) {
      case 'country':
        locationType = LocationType.country;
        // Per i paesi, usa SEMPRE il campo 'country' che è nella lingua richiesta (italiano)
        // Il campo 'name' spesso è in inglese (es. "Turkey" invece di "Turchia")
        mainName = country ?? name;
        break;
        
      case 'state':
      case 'region':
      case 'county':
      case 'province':
        locationType = LocationType.state;
        mainName = state ?? county ?? name;
        break;
        
      case 'city':
      case 'town':
      case 'village':
      case 'municipality':
        locationType = LocationType.city;
        mainName = city ?? name;
        break;
        
      case 'postcode':
      case 'suburb':
      case 'district':
      case 'locality':
      case 'neighbourhood':
        // Questi sono sottotipi di città/luoghi
        if (city != null) {
          locationType = LocationType.city;
          mainName = city;
        } else if (state != null || county != null) {
          locationType = LocationType.state;
          mainName = state ?? county;
        } else {
          locationType = LocationType.other;
          mainName = name ?? country;
        }
        break;
        
      default:
        // Fallback: cerca di dedurre dal contesto
        if (city == null && state == null && county == null && country != null && name == country) {
          // Probabilmente un paese
          locationType = LocationType.country;
          mainName = country;
        } else if (city == null && (state != null || county != null)) {
          // Probabilmente una regione/stato
          locationType = LocationType.state;
          mainName = state ?? county ?? name;
        } else if (city != null) {
          // Probabilmente una città
          locationType = LocationType.city;
          mainName = city;
        } else {
          locationType = LocationType.other;
          mainName = name ?? city ?? state ?? county ?? country;
        }
    }
    
    // Costruisci il displayName in italiano
    // Preferisci costruire un nome pulito invece di usare 'formatted' che può essere misto
    String displayName;
    final parts = <String>[];
    
    if (mainName != null) {
      parts.add(mainName);
    }
    
    // Aggiungi contesto in base al tipo
    if (locationType == LocationType.city) {
      if (state != null && state != mainName) {
        parts.add(state);
      }
      if (country != null) {
        parts.add(country);
      }
    } else if (locationType == LocationType.state) {
      if (country != null && country != mainName) {
        parts.add(country);
      }
    }
    // Per i paesi, non aggiungere nulla
    
    displayName = parts.isNotEmpty ? parts.join(', ') : formatted;
    
    // Fallback al formatted se displayName è vuoto
    if (displayName.isEmpty) {
      displayName = formatted;
    }

    return LocationSuggestion(
      placeId: properties['place_id'] as String? ?? '',
      displayName: displayName,
      name: mainName,
      city: city,
      state: state,
      country: country,
      locationType: locationType,
      lat: (properties['lat'] as num?)?.toDouble(),
      lon: (properties['lon'] as num?)?.toDouble(),
    );
  }
  
  /// Chiave univoca per la deduplicazione (nome + tipo + paese)
  String get deduplicationKey {
    final normalizedName = (name ?? displayName).toLowerCase().trim();
    return '$normalizedName|${locationType.name}|${country?.toLowerCase() ?? ''}';
  }

  @override
  String toString() => displayName;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationSuggestion && 
           (other.placeId == placeId || other.displayName == displayName);
  }
  
  @override
  int get hashCode => displayName.hashCode;
}

/// Widget riutilizzabile per l'autocomplete delle località.
/// Usa l'API Geoapify per cercare città, regioni e stati.
/// 
/// I suggerimenti appaiono dalla terza lettera digitata.
class LocationAutocompleteField extends StatefulWidget {
  /// Valore iniziale del campo
  final String? initialValue;
  
  /// Callback chiamata quando viene selezionata una località
  final ValueChanged<LocationSuggestion>? onLocationSelected;
  
  /// Callback chiamata quando il testo cambia (anche senza selezione)
  final ValueChanged<String>? onTextChanged;
  
  /// Label del campo
  final String? labelText;
  
  /// Hint del campo
  final String? hintText;
  
  /// Numero minimo di caratteri per iniziare la ricerca
  final int minCharsForSearch;
  
  /// Ritardo in millisecondi prima di effettuare la ricerca (debounce)
  final int debounceMs;

  const LocationAutocompleteField({
    super.key,
    this.initialValue,
    this.onLocationSelected,
    this.onTextChanged,
    this.labelText,
    this.hintText,
    this.minCharsForSearch = 3,
    this.debounceMs = 300,
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
  List<LocationSuggestion> _suggestions = [];
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
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _removeOverlay();
    }
  }

  Future<List<LocationSuggestion>> _fetchLocationSuggestions(
    String query,
  ) async {
    final uri = Uri.https(
      'api.geoapify.com',
      '/v1/geocode/autocomplete',
      {
        'text': query,
        'apiKey': ApiKeys.geoapify,
        'lang': 'it',
        'limit': '10', // Richiedi più risultati per avere varietà dopo deduplicazione
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Errore nella richiesta: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final features = json['features'] as List<dynamic>? ?? [];

    // Converti i risultati
    final suggestions = features
        .map((feature) => LocationSuggestion.fromGeoapifyJson(
              feature as Map<String, dynamic>,
            ))
        .where((s) => s.displayName.isNotEmpty)
        .toList();
    
    // Rimuovi duplicati basandosi sulla chiave di deduplicazione (nome + tipo + paese)
    final seen = <String>{};
    final uniqueSuggestions = <LocationSuggestion>[];
    for (final suggestion in suggestions) {
      if (seen.add(suggestion.deduplicationKey)) {
        uniqueSuggestions.add(suggestion);
      }
    }
    
    // Limita a massimo 5 risultati
    return uniqueSuggestions.take(5).toList();
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
            borderRadius: BorderRadius.circular(
              AppConstants.cardBorderRadius,
            ),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
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
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
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

  Widget _buildSuggestionTile(LocationSuggestion suggestion, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Scegli l'icona in base al tipo di località
    IconData icon;
    switch (suggestion.locationType) {
      case LocationType.country:
        icon = Icons.flag_outlined;
        break;
      case LocationType.state:
        icon = Icons.map_outlined;
        break;
      case LocationType.city:
        icon = Icons.location_city_outlined;
        break;
      case LocationType.other:
        icon = Icons.location_on_outlined;
        break;
    }
    
    // Costruisci il sottotitolo con le info aggiuntive
    String? subtitle;
    final parts = <String>[];
    
    // Per le città, mostra stato e paese
    if (suggestion.locationType == LocationType.city) {
      if (suggestion.state != null && suggestion.state != suggestion.name) {
        parts.add(suggestion.state!);
      }
      if (suggestion.country != null) {
        parts.add(suggestion.country!);
      }
    } 
    // Per le regioni/stati, mostra solo il paese
    else if (suggestion.locationType == LocationType.state) {
      if (suggestion.country != null && suggestion.country != suggestion.name) {
        parts.add(suggestion.country!);
      }
    }
    // Per i paesi, nessun sottotitolo
    
    if (parts.isNotEmpty) {
      subtitle = parts.join(', ');
    }
    
    // Usa il nome principale, oppure il displayName come fallback
    final title = suggestion.name ?? suggestion.displayName;
    
    return InkWell(
      onTap: () => _selectSuggestion(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: index < _suggestions.length - 1
              ? Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: colorScheme.primary,
            ),
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
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
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

  void _selectSuggestion(LocationSuggestion suggestion) {
    _ignoreNextChange = true;
    _controller.text = suggestion.displayName;
    _removeOverlay();
    widget.onLocationSelected?.call(suggestion);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.labelText ?? 'Destinazione',
          hintText: widget.hintText ?? 'Cerca città, regione o stato...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          ),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
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
