import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../luggages/providers/luggage_provider.dart';
import '../../luggages/model/luggage_model.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../../shared/helpers/design_system.dart';
import 'trip_info_form.dart';
import 'trip_items_selector.dart';

class AddTripScreen extends ConsumerStatefulWidget {
  final String? tripId;

  const AddTripScreen({super.key, this.tripId});

  @override
  ConsumerState<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends ConsumerState<AddTripScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Dati del viaggio
  String _name = '';
  String? _description;
  DateTime? _departureDateTime;
  DateTime? _returnDateTime;
  String? _destinationHouseId;
  LocationSuggestionModel? _destinationLocation;
  List<TripItem> _selectedItems = [];
  List<LuggageModel> _selectedLuggages = [];

  @override
  void initState() {
    super.initState();
    if (widget.tripId != null) {
      _loadTrip();
    }
  }

  Future<void> _loadTrip() async {
    final tripsAsync = ref.read(tripNotifierProvider);
    tripsAsync.whenData((trips) {
      final trip = trips.firstWhere(
        (t) => t.id == widget.tripId,
        orElse: () => throw StateError('Lista non trovata'),
      );
      setState(() {
        _name = trip.name;
        _description = trip.description;
        _departureDateTime = trip.departureDateTime;
        _returnDateTime = trip.returnDateTime;
        _destinationHouseId = trip.destinationHouseId;
        _destinationLocation = trip.destinationLocation;
        _selectedItems = List.from(trip.items);
        _selectedLuggages = List.from(trip.luggages);
      });
    });
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;

    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('common.required_field_error'.tr())));
      return;
    }

    // Validazione date
    if (_departureDateTime != null && _returnDateTime != null) {
      if (_returnDateTime!.isBefore(_departureDateTime!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.return_before_departure_error'.tr()),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final trip = widget.tripId != null
        ? (() {
            final tripsAsync = ref.read(tripNotifierProvider);
            final trips = tripsAsync.value;
            if (trips == null) throw StateError('Lista non trovata');
            return trips
                .firstWhere((t) => t.id == widget.tripId)
                .copyWith(
                  name: _name.trim(),
                  description: _description,
                  items: _selectedItems,
                  luggages: _selectedLuggages,
                  departureDateTime: _departureDateTime,
                  returnDateTime: _returnDateTime,
                  destinationHouseId: _destinationHouseId,
                  destinationLocation: _destinationHouseId == null
                      ? _destinationLocation
                      : null,
                  updatedAt: now,
                );
          })()
        : TripModel(
            id: const Uuid().v4(),
            name: _name.trim(),
            description: _description,
            items: _selectedItems,
            luggages: _selectedLuggages,
            departureDateTime: _departureDateTime,
            returnDateTime: _returnDateTime,
            destinationHouseId: _destinationHouseId,
            destinationLocation: _destinationHouseId == null
                ? _destinationLocation
                : null,
            createdAt: now,
            updatedAt: now,
          );

    final isEditing = widget.tripId != null;
    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () async {
        if (isEditing) {
          await ref.read(tripNotifierProvider.notifier).updateTrip(trip);
        } else {
          await ref.read(tripNotifierProvider.notifier).addTrip(trip);
        }
      },
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: isEditing
          ? 'errors.save_trip_failed'.tr()
          : 'errors.create_trip_failed'.tr(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.go('/trips');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StickyCtaScaffold(
      appBar: AppBar(
        title: Text(
          widget.tripId != null ? 'trips.edit'.tr() : 'trips.add_new'.tr(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: context.spacingSm,
            right: context.spacingSm,
            top: context.spacingSm,
            bottom: context.spacingMd,
          ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sezione Info Viaggio
                  Text(
                    'trips.trip_info'.tr(),
                    style: TextStyle(
                      fontSize: context.fontSizeMd,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: context.spacingSm),
                  TripInfoForm(
                    initialName: _name,
                    initialDescription: _description,
                    initialDepartureDateTime: _departureDateTime,
                    initialReturnDateTime: _returnDateTime,
                    initialDestinationHouseId: _destinationHouseId,
                    initialDestinationLocation: _destinationLocation,
                    onChanged:
                        ({
                          name,
                          description,
                          departureDateTime,
                          returnDateTime,
                          destinationHouseId,
                          destinationLocation,
                        }) {
                          setState(() {
                            if (name != null) _name = name;
                            _description = description;
                            _departureDateTime = departureDateTime;
                            _returnDateTime = returnDateTime;
                            _destinationHouseId = destinationHouseId;
                            _destinationLocation = destinationLocation;
                          });
                        },
                  ),

                  SizedBox(height: context.spacingLg),

                  // Sezione Oggetti
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'trips.items_to_bring'.tr(),
                        style: TextStyle(
                          fontSize: context.fontSizeMd,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spacingSm,
                          vertical: context.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: context.responsiveBorderRadius(12),
                        ),
                        child: Text(
                          'common.items_selected'.tr(args: [_selectedItems.length.toString()]),
                          style: TextStyle(
                            fontSize: context.fontSizeXs,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.spacingSm),

                  // Lista oggetti (shrinkWrap per scroll globale)
                  TripItemsSelector(
                    selectedItems: _selectedItems,
                    shrinkWrap: true,
                    onSelectionChanged: (items) {
                      setState(() {
                        _selectedItems = items;
                      });
                    },
                  ),

                  SizedBox(height: context.spacingLg),

                  // Sezione Bagagli
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'luggages.title'.tr(),
                        style: TextStyle(
                          fontSize: context.fontSizeMd,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spacingSm,
                          vertical: context.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: context.responsiveBorderRadius(12),
                        ),
                        child: Text(
                          'common.luggages_selected'.tr(args: [_selectedLuggages.length.toString()]),
                          style: TextStyle(
                            fontSize: context.fontSizeXs,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.spacingSm),

                  _buildLuggageSelector(),
                ],
              ),
            ),
          ),
      bottomContent: UniversalActionBar(
        primaryLabel: widget.tripId != null
            ? 'common.save_changes'.tr()
            : 'trips.create_trip'.tr(),
        primaryIcon: Icons.save,
        onPrimaryPressed: _isLoading ? null : _saveTrip,
        isLoading: _isLoading,
      ),
    );
  }

  Widget _buildLuggageSelector() {
    final luggagesAsync = ref.watch(luggageNotifierProvider);

    return luggagesAsync.when(
      data: (allLuggages) {
        if (allLuggages.isEmpty) {
          return EmptyState(
            icon: Icons.luggage_outlined,
            title: 'luggages.no_luggages'.tr(),
            subtitle: 'luggages.no_luggages_subtitle'.tr(),
          );
        }

        return Wrap(
          spacing: context.spacingSm,
          runSpacing: context.spacingSm,
          children: allLuggages.map((luggage) {
            final isSelected = _selectedLuggages.any((l) => l.id == luggage.id);
            final colorScheme = Theme.of(context).colorScheme;

            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.luggage,
                    size: context.iconSizeSm,
                    color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurface,
                  ),
                  SizedBox(width: context.spacingXs),
                  Text(luggage.name),
                  SizedBox(width: context.spacingXs),
                  Text(
                    '(${luggage.effectiveVolumeLiters ?? 0}L)',
                    style: TextStyle(
                      fontSize: context.fontSizeXs,
                      color: isSelected
                          ? colorScheme.onSecondaryContainer.withValues(alpha: 0.7)
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedLuggages.add(luggage);
                  } else {
                    _selectedLuggages.removeWhere((l) => l.id == luggage.id);
                  }
                });
              },
              backgroundColor: Colors.transparent,
              selectedColor: colorScheme.secondaryContainer,
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
