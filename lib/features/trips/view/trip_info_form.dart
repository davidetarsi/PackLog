import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/model/house_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';

/// Widget riutilizzabile per il form delle info del viaggio.
/// 
/// Contiene:
/// - Campo nome viaggio (in pill tab grande)
/// - Card con date partenza/ritorno
/// - Card con selezione casa + location autocomplete
class TripInfoForm extends ConsumerStatefulWidget {
  /// Nome iniziale del viaggio
  final String? initialName;
  
  /// Descrizione iniziale (opzionale)
  final String? initialDescription;
  
  /// Data/ora partenza iniziale
  final DateTime? initialDepartureDateTime;
  
  /// Data/ora ritorno iniziale
  final DateTime? initialReturnDateTime;
  
  /// ID casa destinazione iniziale
  final String? initialDestinationHouseId;
  
  /// Località destinazione iniziale (modello completo)
  final LocationSuggestionModel? initialDestinationLocation;

  
  /// Callback quando i dati cambiano
  final void Function({
    String? name,
    String? description,
    DateTime? departureDateTime,
    DateTime? returnDateTime,
    String? destinationHouseId,
    LocationSuggestionModel? destinationLocation,
  }) onChanged;

  const TripInfoForm({
    super.key,
    this.initialName,
    this.initialDescription,
    this.initialDepartureDateTime,
    this.initialReturnDateTime,
    this.initialDestinationHouseId,
    this.initialDestinationLocation,
    required this.onChanged,
  });

  @override
  ConsumerState<TripInfoForm> createState() => _TripInfoFormState();
}

class _TripInfoFormState extends ConsumerState<TripInfoForm> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  DateTime? _departureDateTime;
  DateTime? _returnDateTime;
  String? _destinationHouseId;
  LocationSuggestionModel? _destinationLocation;

  // Colore arancione per le icone
  static const Color _accentColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
    _departureDateTime = widget.initialDepartureDateTime;
    _returnDateTime = widget.initialReturnDateTime;
    _destinationHouseId = widget.initialDestinationHouseId;
    _destinationLocation = widget.initialDestinationLocation;
    
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      departureDateTime: _departureDateTime,
      returnDateTime: _returnDateTime,
      destinationHouseId: _destinationHouseId,
      destinationLocation: _destinationHouseId == null 
          ? _destinationLocation 
          : null,
    );
  }

  Future<void> _pickDepartureDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departureDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'trips.select_departure_date'.tr(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _departureDateTime != null
          ? TimeOfDay.fromDateTime(_departureDateTime!)
          : TimeOfDay.now(),
      helpText: 'trips.select_departure_time'.tr(),
    );
    if (time == null || !mounted) return;

    setState(() {
      _departureDateTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
      final autoReturn = _departureDateTime!.add(const Duration(hours: 12));
      if (_returnDateTime == null || _returnDateTime!.isBefore(_departureDateTime!)) {
        _returnDateTime = autoReturn;
      }
    });
    _notifyChanged();
  }

  Future<void> _pickReturnDateTime() async {
    final initialDate = _returnDateTime ?? _departureDateTime ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _departureDateTime ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'trips.select_return_date'.tr(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _returnDateTime != null
          ? TimeOfDay.fromDateTime(_returnDateTime!)
          : TimeOfDay.now(),
      helpText: 'trips.select_return_time'.tr(),
    );
    if (time == null || !mounted) return;

    setState(() {
      _returnDateTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
    _notifyChanged();
  }

  Future<void> _showDestinationHousePicker(List<HouseModel> houses) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'trips.select_destination_house'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cancel_outlined, color: _accentColor),
            title: Text('common.none_insert_location'.tr()),
            trailing: _destinationHouseId == null
                ? const Icon(Icons.check, color: _accentColor)
                : null,
            onTap: () => Navigator.pop(context, ''),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: houses.length,
              itemBuilder: (context, index) {
                final house = houses[index];
                return ListTile(
                  leading: const Icon(Icons.home_outlined, color: _accentColor),
                  title: Text(house.name),
                  subtitle: house.description != null ? Text(house.description!) : null,
                  trailing: _destinationHouseId == house.id
                      ? const Icon(Icons.check, color: _accentColor)
                      : null,
                  onTap: () => Navigator.pop(context, house.id),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (selected != null) {
      setState(() {
        _destinationHouseId = selected.isEmpty ? null : selected;
        if (_destinationHouseId != null) {
          _destinationLocation = null;
        }
      });
      _notifyChanged();
    }
  }

  String _formatDateTimeLine(DateTime? dateTime) {
    if (dateTime == null) return 'common.tap_to_set'.tr();
    return '${DateFormat('d MMM y').format(dateTime)} • ${DateFormat('HH:mm').format(dateTime)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final housesAsync = ref.watch(houseNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nome viaggio - Pill tab grande senza bordi
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: context.responsiveBorderRadius(24),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.spacingMd,
            vertical: context.spacingSm,
          ),
          child: TextFormField(
            controller: _nameController,
            style: TextStyle(
              fontSize: context.fontSizeXl,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'trips.name_hint'.tr(),
              hintStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                fontWeight: FontWeight.normal,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => _notifyChanged(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'common.name_required_validation'.tr();
              }
              return null;
            },
          ),
        ),
        
        SizedBox(height: context.spacingMd),
        
        // Card Date - Layout verticale
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: context.responsiveBorderRadius(AppConstants.cardBorderRadius),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              // Partenza
              _buildDateRow(
                context,
                colorScheme,
                icon: Icons.calendar_month_outlined,
                label: 'common.departure'.tr(),
                dateTime: _departureDateTime,
                onTap: _pickDepartureDateTime,
                onClear: () {
                  setState(() => _departureDateTime = null);
                  _notifyChanged();
                },
              ),
              // Linea arancione di collegamento
              Padding(
                padding: const EdgeInsets.only(left: 27),
                child: Row(
                  children: [
                    Container(
                      width: 2,
                      height: 16,
                      color: _accentColor,
                    ),
                  ],
                ),
              ),
              // Ritorno
              _buildDateRow(
                context,
                colorScheme,
                icon: Icons.calendar_month_outlined,
                label: 'common.return'.tr(),
                dateTime: _returnDateTime,
                onTap: _pickReturnDateTime,
                onClear: () {
                  setState(() => _returnDateTime = null);
                  _notifyChanged();
                },
              ),
            ],
          ),
        ),
        
        SizedBox(height: context.spacingMd),
        
        // Card Destinazione
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: context.responsiveBorderRadius(AppConstants.cardBorderRadius),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              // Selezione casa - allineato con icona
              housesAsync.when(
                data: (houses) => _buildDestinationRow(
                  context,
                  colorScheme,
                  icon: Icons.home_outlined,
                  label: 'common.arrival_house'.tr(),
                  value: _getSelectedHouseName(houses),
                  hasValue: _destinationHouseId != null,
                  onTap: () => _showDestinationHousePicker(houses),
                  onClear: _destinationHouseId != null
                      ? () {
                          setState(() => _destinationHouseId = null);
                          _notifyChanged();
                        }
                      : null,
                ),
                loading: () => Padding(
                  padding: EdgeInsets.all(context.spacingMd),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: EdgeInsets.all(context.spacingMd),
                  child: Text('${'common.error'.tr()}: $e'),
                ),
              ),
              // Location autocomplete (solo se nessuna casa selezionata)
              if (_destinationHouseId == null) ...[
                Divider(height: 1, indent: 56, endIndent: context.spacingMd),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacingMd,
                    vertical: context.spacingSm + 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: _accentColor,
                        size: 22,
                      ),
                      SizedBox(width: context.spacingMd),
                      Expanded(
                        child: LocationAutocompleteField(
                          initialValue: _destinationLocation?.displayName,
                          labelText: null,
                          hintText: 'trips.destination_hint'.tr(),
                          showBorder: false,
                          onLocationSelected: (location) {
                            setState(() {
                              _destinationLocation = location;
                            });
                            _notifyChanged();
                          },
                          onTextChanged: (text) {
                            // Se l'utente digita manualmente senza selezionare,
                            // creiamo un modello minimale con solo il displayName
                            setState(() {
                              if (text.isEmpty) {
                                _destinationLocation = null;
                              } else if (_destinationLocation?.displayName != text) {
                                // L'utente sta digitando, crea un modello temporaneo
                                _destinationLocation = LocationSuggestionModel(
                                  placeId: '',
                                  displayName: text,
                                );
                              }
                            });
                            _notifyChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateRow(
    BuildContext context,
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required DateTime? dateTime,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMd,
          vertical: context.spacingSm + 4,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: _accentColor,
              size: 22,
            ),
            SizedBox(width: context.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: context.fontSizeSm,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTimeLine(dateTime),
                    style: TextStyle(
                      fontSize: context.fontSizeMd,
                      color: dateTime != null 
                          ? colorScheme.onSurface 
                          : colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (dateTime != null)
              IconButton(
                icon: const Icon(Icons.clear, color: _accentColor, size: 20),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationRow(
    BuildContext context,
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required String value,
    required bool hasValue,
    required VoidCallback? onTap,
    required VoidCallback? onClear,
    Widget? customContent,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMd,
          vertical: context.spacingSm + 4,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: _accentColor,
              size: 22,
            ),
            SizedBox(width: context.spacingMd),
            if (customContent != null)
              customContent
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: context.fontSizeSm,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: context.fontSizeMd,
                        color: hasValue 
                            ? colorScheme.onSurface 
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.clear, color: _accentColor, size: 20),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  String _getSelectedHouseName(List<HouseModel> houses) {
    if (_destinationHouseId == null) {
      return 'common.none_selected'.tr();
    }
    final house = houses.where((h) => h.id == _destinationHouseId).firstOrNull;
    return house?.name ?? 'common.unknown_house'.tr();
  }
}
