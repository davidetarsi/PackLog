import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/trip_info_form.dart';

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
  String? _destinationLocationName;

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
          _destinationLocationName = trip.destinationLocationName;
        });
      }
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il nome è obbligatorio')),
      );
      return;
    }

    if (_trip == null) return;

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

    final updatedTrip = _trip!.copyWith(
      name: _name.trim(),
      description: _description,
      departureDateTime: _departureDateTime,
      returnDateTime: _returnDateTime,
      destinationHouseId: _destinationHouseId,
      destinationLocationName: _destinationHouseId == null
          ? _destinationLocationName
          : null,
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(tripNotifierProvider.notifier).updateTrip(updatedTrip);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modifica info')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifica info viaggio'),
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
                initialDestinationLocationName: _destinationLocationName,
                onChanged: ({
                  name,
                  description,
                  departureDateTime,
                  returnDateTime,
                  destinationHouseId,
                  destinationLocationName,
                }) {
                  setState(() {
                    if (name != null) _name = name;
                    _description = description;
                    _departureDateTime = departureDateTime;
                    _returnDateTime = returnDateTime;
                    _destinationHouseId = destinationHouseId;
                    _destinationLocationName = destinationLocationName;
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
                        'Salva modifiche',
                        style: TextStyle(
                          fontSize: context.fontSizeLg,
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
