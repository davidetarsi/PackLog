import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import 'trip_info_form.dart';

/// Schermata per modificare solo le info del viaggio (nome, date, destinazione).
class EditTripInfoScreen extends ConsumerStatefulWidget {
  final String tripId;

  const EditTripInfoScreen({super.key, required this.tripId});

  @override
  ConsumerState<EditTripInfoScreen> createState() => _EditTripInfoScreenState();
}

class _EditTripInfoScreenState extends ConsumerState<EditTripInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  TripModel? _trip;

  // Dati modificabili
  String _name = '';
  String? _description;
  DateTime? _departureDateTime;
  DateTime? _returnDateTime;
  String? _destinationHouseId;
  LocationSuggestionModel? _destinationLocation;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  void _loadTrip() {
    final tripsAsync = ref.read(tripNotifierProvider);
    tripsAsync.whenData((trips) {
      final trip = trips.where((t) => t.id == widget.tripId).firstOrNull;
      if (trip != null) {
        setState(() {
          _trip = trip;
          _name = trip.name;
          _description = trip.description;
          _departureDateTime = trip.departureDateTime;
          _returnDateTime = trip.returnDateTime;
          _destinationHouseId = trip.destinationHouseId;
          _destinationLocation = trip.destinationLocation;
        });
      }
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.required_field_error'.tr())),
      );
      return;
    }

    if (_trip == null) return;

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

    final updatedTrip = _trip!.copyWith(
      name: _name.trim(),
      description: _description,
      departureDateTime: _departureDateTime,
      returnDateTime: _returnDateTime,
      destinationHouseId: _destinationHouseId,
      destinationLocation: _destinationHouseId == null
          ? _destinationLocation
          : null,
      updatedAt: DateTime.now(),
    );

    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref.read(tripNotifierProvider.notifier).updateTrip(updatedTrip),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: 'errors.save_trip_failed'.tr(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: Text('trips.edit_info'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('trips.edit_info'.tr()),
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: context.spacingSm,
                right: context.spacingSm,
                top: context.spacingSm,
                bottom: 130,
              ),
              child: TripInfoForm(
                initialName: _name,
                initialDescription: _description,
                initialDepartureDateTime: _departureDateTime,
                initialReturnDateTime: _returnDateTime,
                initialDestinationHouseId: _destinationHouseId,
                initialDestinationLocation: _destinationLocation,
                onChanged: ({
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
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(context.spacingMd),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: _buildSaveButton(context, colorScheme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(28),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _isLoading ? null : _saveChanges,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.save,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: context.spacingSm),
                      Text(
                        'common.save_changes'.tr(),
                        style: TextStyle(
                          fontSize: context.fontSizeMd,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
