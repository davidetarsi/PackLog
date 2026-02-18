import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
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
      });
    });
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;

    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Il nome è obbligatorio')));
      return;
    }

    // Validazione date
    if (_departureDateTime != null && _returnDateTime != null) {
      if (_returnDateTime!.isBefore(_departureDateTime!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La data di ritorno deve essere dopo la partenza'),
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
      errorTitle: 'Errore di salvataggio',
      errorMessage: isEditing
          ? 'Impossibile salvare le modifiche al viaggio.'
          : 'Impossibile creare il viaggio.',
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.tripId != null ? 'Modifica viaggio' : 'Nuovo viaggio',
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            // CONTENUTO SCROLLABILE
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: context.spacingSm,
                right: context.spacingSm,
                top: context.spacingSm,
                bottom: 130, // Spazio per il bottone fisso
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sezione Info Viaggio
                  Text(
                    'Informazioni viaggio',
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
                        'Oggetti da portare',
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
                          '${_selectedItems.length} selezionati',
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
                ],
              ),
            ),

            // BOTTONE FISSO IN BASSO
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
        onTap: _isLoading ? null : _saveTrip,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colorScheme.primary, width: 2),
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
                      Icon(Icons.save, color: colorScheme.onSurfaceVariant),
                      SizedBox(width: context.spacingSm),
                      Text(
                        widget.tripId != null
                            ? 'Salva modifiche'
                            : 'Crea viaggio',
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
