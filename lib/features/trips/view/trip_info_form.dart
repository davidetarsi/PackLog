import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/model/house_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';

class TripInfoForm extends ConsumerStatefulWidget {
  final String? initialName;
  final String? initialDescription;
  final DateTime? initialDepartureDateTime;
  final DateTime? initialReturnDateTime;
  final String? initialDestinationHouseId;
  final LocationSuggestionModel? initialDestinationLocation;

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
  late bool _useHouseDestination;

  // _accentColor rimosso — usare colorScheme.primary nei build methods.

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _departureDateTime = widget.initialDepartureDateTime;
    _returnDateTime = widget.initialReturnDateTime;
    _destinationHouseId = widget.initialDestinationHouseId;
    _destinationLocation = widget.initialDestinationLocation;
    _useHouseDestination = widget.initialDestinationHouseId != null;
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

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: (_departureDateTime != null && _returnDateTime != null)
          ? DateTimeRange(start: _departureDateTime!, end: _returnDateTime!)
          : null,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (range == null || !mounted) return;

    setState(() {
      _departureDateTime = range.start;
      _returnDateTime = range.end;
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
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: houses.length,
              itemBuilder: (context, index) {
                final cs = Theme.of(context).colorScheme;
                final house = houses[index];
                return ListTile(
                  leading: Icon(Icons.home_outlined, color: cs.primary),
                  title: Text(house.name),
                  subtitle: house.description != null
                      ? Text(house.description!)
                      : null,
                  trailing: _destinationHouseId == house.id
                      ? Icon(Icons.check, color: cs.primary)
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('d MMM y').format(dt);
  }

  String _getSelectedHouseName(List<HouseModel> houses) {
    if (_destinationHouseId == null) {
      return 'common.none_selected'.tr();
    }
    final house = houses.where((h) => h.id == _destinationHouseId).firstOrNull;
    return house?.name ?? 'common.unknown_house'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final housesAsync = ref.watch(houseNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Nome viaggio ───────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(vertical: context.spacingSm),
          child: TextFormField(
            controller: _nameController,
            style: TextStyle(
              fontSize: context.fontSizeXl,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'trips.name_hint'.tr(),
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant,
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

        // ── Date - riga unica con range picker ─────────────────────────
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: context.responsiveBorderRadius(
              AppConstants.cardBorderRadius,
            ),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: InkWell(
            onTap: _pickDateRange,
            borderRadius: context.responsiveBorderRadius(
              AppConstants.cardBorderRadius,
            ),
            child: Padding(
              padding: context.cardPaddingHero,
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: colorScheme.primary, size: 22),
                  SizedBox(width: context.spacingMd),
                  Expanded(
                    child: (_departureDateTime != null || _returnDateTime != null)
                        ? Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'common.departure'.tr(),
                                      style: TextStyle(
                                        fontSize: context.fontSizeXs,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(_departureDateTime),
                                      style: TextStyle(fontSize: context.fontSizeSm),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.arrow_forward, color: colorScheme.primary, size: 16),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'common.return'.tr(),
                                      style: TextStyle(
                                        fontSize: context.fontSizeXs,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(_returnDateTime),
                                      style: TextStyle(fontSize: context.fontSizeSm),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'common.tap_to_set_dates'.tr(),
                            style: TextStyle(
                              fontSize: context.fontSizeMd,
                              color: colorScheme.onSurface.withValues(alpha: 0.38),
                            ),
                          ),
                  ),
                  if (_departureDateTime != null || _returnDateTime != null)
                    IconButton(
                      icon: Icon(Icons.clear, color: colorScheme.primary, size: 20),
                      onPressed: () {
                        setState(() {
                          _departureDateTime = null;
                          _returnDateTime = null;
                        });
                        _notifyChanged();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: context.spacingMd),

        // ── Toggle destinazione (autonomo) ─────────────────────────────
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text('common.destination_other'.tr()),
                icon: const Icon(Icons.place_outlined, size: 18),
              ),
              ButtonSegment(
                value: true,
                label: Text('common.destination_house'.tr()),
                icon: const Icon(Icons.home_outlined, size: 18),
              ),
            ],
            selected: {_useHouseDestination},
            onSelectionChanged: (selection) {
              setState(() {
                _useHouseDestination = selection.first;
                if (_useHouseDestination) {
                  _destinationLocation = null;
                } else {
                  _destinationHouseId = null;
                }
              });
              _notifyChanged();
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return colorScheme.primary.withValues(alpha: 0.12); // state layer selected
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return colorScheme.primary;
                }
                return colorScheme.onSurfaceVariant;
              }),
              side: WidgetStateProperty.all(
                BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
          ),
        ),

        SizedBox(height: context.spacingSm),

        // ── Contenuto destinazione ─────────────────────────────────────
        Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: context.responsiveBorderRadius(
                AppConstants.cardBorderRadius,
              ),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: _useHouseDestination
                ? housesAsync.when(
                  data: (houses) => _buildHouseRow(context, colorScheme, houses),
                  loading: () => Padding(
                    padding: EdgeInsets.all(context.spacingMd),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: EdgeInsets.all(context.spacingMd),
                    child: ErrorState(
                      error: e,
                      onRetry: () => ref.invalidate(houseNotifierProvider),
                    ),
                  ),
                )
              : _buildLocationRow(context, colorScheme),
        ),
      ],
    );
  }

  Widget _buildHouseRow(
    BuildContext context,
    ColorScheme colorScheme,
    List<HouseModel> houses,
  ) {
    return InkWell(
      onTap: () => _showDestinationHousePicker(houses),
      borderRadius: context.responsiveBorderRadius(AppConstants.cardBorderRadius),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMd,
          vertical: context.spacingMd,
        ),
        child: Row(
          children: [
            Icon(Icons.home_outlined, color: colorScheme.primary, size: 22),
            SizedBox(width: context.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'common.arrival_house'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getSelectedHouseName(houses),
                    style: TextStyle(
                      fontSize: context.fontSizeSm,
                      color: _destinationHouseId != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            if (_destinationHouseId != null)
              IconButton(
                icon: Icon(Icons.clear, color: colorScheme.primary, size: 20),
                onPressed: () {
                  setState(() => _destinationHouseId = null);
                  _notifyChanged();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingSm + 4,
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: colorScheme.primary, size: 22),
          Expanded(
            child: LocationAutocompleteField(
              initialValue: _destinationLocation?.displayName,
              labelText: null,
              hintText: 'trips.destination_hint'.tr(),
              hintStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              showBorder: false,
              onLocationSelected: (location) {
                setState(() => _destinationLocation = location);
                _notifyChanged();
              },
              onTextChanged: (text) {
                setState(() {
                  if (text.isEmpty) {
                    _destinationLocation = null;
                  } else if (_destinationLocation?.displayName != text) {
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
    );
  }
}
