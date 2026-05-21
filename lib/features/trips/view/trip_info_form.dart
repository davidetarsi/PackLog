import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/model/house_model.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/widgets/app_pill_tab.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';

class TripInfoForm extends ConsumerStatefulWidget {
  final String? initialDescription;
  final DateTime? initialDepartureDateTime;
  final DateTime? initialReturnDateTime;
  final String? initialDestinationHouseId;
  final LocationSuggestionModel? initialDestinationLocation;

  final void Function({
    String? description,
    DateTime? departureDateTime,
    DateTime? returnDateTime,
    String? destinationHouseId,
    LocationSuggestionModel? destinationLocation,
    String? destinationName,
  })
  onChanged;

  const TripInfoForm({
    super.key,
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
  late TextEditingController _descriptionController;
  DateTime? _departureDateTime;
  DateTime? _returnDateTime;
  String? _destinationHouseId;
  String? _destinationHouseName;
  LocationSuggestionModel? _destinationLocation;
  late bool _useHouseDestination;

  // _accentColor rimosso — usare colorScheme.primary nei build methods.

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _departureDateTime = widget.initialDepartureDateTime;
    _returnDateTime = widget.initialReturnDateTime;
    _destinationHouseId = widget.initialDestinationHouseId;
    _destinationLocation = widget.initialDestinationLocation;
    _useHouseDestination = widget.initialDestinationHouseId != null;
    if (_destinationHouseId != null) {
      final housesAsync = ref.read(houseNotifierProvider);
      housesAsync.whenData((houses) {
        final house =
            houses.where((h) => h.id == _destinationHouseId).firstOrNull;
        _destinationHouseName = house?.displayName;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _notifyChanged();
        });
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    final destinationName = _destinationHouseId != null
        ? _destinationHouseName
        : (_destinationLocation?.displayName.trim().isNotEmpty == true
              ? _destinationLocation!.displayName
              : null);

    widget.onChanged(
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      departureDateTime: _departureDateTime,
      returnDateTime: _returnDateTime,
      destinationHouseId: _destinationHouseId,
      destinationLocation: _destinationHouseId == null
          ? _destinationLocation
          : null,
      destinationName: destinationName,
    );
  }

  Future<void> _pickDateRange() async {
    final result = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TripDatePickerSheet(
        initialDeparture: _departureDateTime,
        initialReturn: _returnDateTime,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _departureDateTime = result.start;
      _returnDateTime = result.end;
    });
    _notifyChanged();
  }

  Future<void> _showDestinationHousePicker(List<HouseModel> houses) async {
    final selected = await DsPickerSheet.show<HouseModel>(
      context: context,
      title: 'trips.select_destination_house'.tr(),
      items: houses,
      getLabel: (h) => h.displayName,
      getSubtitle: (h) => h.description,
      getIcon: (_) => Icons.home_outlined,
      selected: houses.where((h) => h.id == _destinationHouseId).firstOrNull,
    );

    if (selected != null && mounted) {
      setState(() {
        _destinationHouseId = selected.id;
        _destinationHouseName = selected.displayName;
        _destinationLocation = null;
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
    return house?.displayName ?? 'common.unknown_house'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final housesAsync = ref.watch(houseNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Toggle destinazione — AppPillTab al posto di SegmentedButton ──
        AppPillTab<bool>(
          items: const [false, true],
          selectedItem: _useHouseDestination,
          getLabel: (v) => v
              ? 'common.destination_house'.tr()
              : 'common.destination_other'.tr(),
          getIcon: (v) => v
              ? const Icon(Icons.home_outlined, size: 18)
              : const Icon(Icons.place_outlined, size: 18),
          onSelected: (v) {
            setState(() {
              _useHouseDestination = v;
              if (_useHouseDestination) {
                _destinationLocation = null;
              } else {
                _destinationHouseId = null;
                _destinationHouseName = null;
              }
            });
            _notifyChanged();
          },
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
                  data: (houses) =>
                      _buildHouseRow(context, colorScheme, houses),
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

        SizedBox(height: context.spacingMd),

        // ── Date ──────────────────────────────────────────────────────
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
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingMd,
                vertical: context.spacingMd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  SizedBox(width: context.spacingMd),
                  Expanded(
                    child: (_departureDateTime != null ||
                            _returnDateTime != null)
                        ? Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                      style: TextStyle(
                                        fontSize: context.fontSizeSm,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Icon(
                                  Icons.arrow_forward,
                                  color: colorScheme.primary,
                                  size: 16,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                      style: TextStyle(
                                        fontSize: context.fontSizeSm,
                                      ),
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
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              ),
                            ),
                          ),
                  ),
                  if (_departureDateTime != null || _returnDateTime != null)
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: colorScheme.primary,
                        size: 20,
                      ),
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
      borderRadius: context.responsiveBorderRadius(
        AppConstants.cardBorderRadius,
      ),
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
                      fontSize: context.fontSizeXxs,
                      fontWeight: FontWeight.w600,
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
                  setState(() {
                    _destinationHouseId = null;
                    _destinationHouseName = null;
                  });
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

class _TripDatePickerSheet extends StatefulWidget {
  final DateTime? initialDeparture;
  final DateTime? initialReturn;

  const _TripDatePickerSheet({this.initialDeparture, this.initialReturn});

  @override
  State<_TripDatePickerSheet> createState() => _TripDatePickerSheetState();
}

class _TripDatePickerSheetState extends State<_TripDatePickerSheet> {
  DateTime? _departure;
  DateTime? _return;

  @override
  void initState() {
    super.initState();
    _departure = widget.initialDeparture;
    _return = widget.initialReturn;
  }

  Future<void> _pickDeparture() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _departure ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d == null || !mounted) return;
    setState(() {
      _departure = d;
      if (_return != null && !_return!.isAfter(d)) _return = null;
    });
  }

  Future<void> _pickReturn() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _return ?? (_departure ?? now),
      firstDate: _departure ?? now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d == null || !mounted) return;
    setState(() => _return = d);
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('d MMM y').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSave = _departure != null && _return != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, canSave ? 0 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _buildDateRow(
              context: context,
              cs: cs,
              icon: Icons.flight_takeoff,
              label: 'common.departure'.tr(),
              date: _departure,
              onTap: _pickDeparture,
            ),
            const SizedBox(height: 8),
            _buildDateRow(
              context: context,
              cs: cs,
              icon: Icons.flight_land,
              label: 'common.return'.tr(),
              date: _return,
              onTap: _pickReturn,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: canSave
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(
                            DateTimeRange(start: _departure!, end: _return!),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text('common.save'.tr()),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (canSave) const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow({
    required BuildContext context,
    required ColorScheme cs,
    required IconData icon,
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: cs.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 14,
                        color: date != null
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
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
