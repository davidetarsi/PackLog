import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../model/trip_form_validation.dart';
import '../model/trip_leg.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import 'trip_info_form.dart';
import 'widgets/trip_legs_section.dart';

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
  String? _name;
  String? _description;
  DateTime? _departureDateTime;
  DateTime? _returnDateTime;
  String? _destinationHouseId;
  LocationSuggestionModel? _destinationLocation;
  String? _destinationName;
  List<TripLeg> _legs = [];

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
          _destinationName = trip.destinationLocation?.displayName;
          _legs = List.from(trip.legs);
        });
      }
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_trip == null) return;

    final error = tripFormError(
      name: _name,
      hasDestination:
          _destinationHouseId != null || _destinationLocation != null,
      departureDateTime: _departureDateTime,
      returnDateTime: _returnDateTime,
    );
    if (error != null) {
      AppSnackBar.showError(context, error.tr());
      return;
    }

    setState(() => _isLoading = true);

    final updatedTrip = _trip!.copyWith(
      // Segnaposto come rete di sicurezza: `TripModel.name` non è nullable, ma
      // tripFormError blocca già il salvataggio se mancano nome e destinazione.
      name: (_name?.trim().isNotEmpty ?? false)
          ? _name!.trim()
          : 'trips.unnamed_destination'.tr(),
      description: _description,
      departureDateTime: _departureDateTime,
      returnDateTime: _returnDateTime,
      legs: _legs,
      destinationHouseId: _destinationHouseId,
      destinationLocation: _destinationHouseId == null
          ? _destinationLocation
          : (_destinationName?.isNotEmpty == true
                ? LocationSuggestionModel(
                    placeId: '',
                    displayName: _destinationName!,
                  )
                : null),
      updatedAt: DateTime.now(),
    );

    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () =>
          ref.read(tripNotifierProvider.notifier).updateTrip(updatedTrip),
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
    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: Text('trips.edit_info'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StickyCtaScaffold(
      appBar: AppBar(title: Text('trips.edit_info'.tr())),
      // Builder: ctaReservedHeight legge CtaReservedSpaceScope, che
      // StickyCtaScaffold inserisce come discendente di `body` — serve un
      // context interno a questo subtree, non quello del metodo build
      // esterno (che sta sopra lo scope e non lo vedrebbe mai).
      body: Builder(
        builder: (context) => Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(
              context.spacingMd,
            ).copyWith(bottom: context.spacingMd + context.ctaReservedHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TripInfoForm(
                  initialName: _name,
                  initialDescription: _description,
                  initialDepartureDateTime: _departureDateTime,
                  initialReturnDateTime: _returnDateTime,
                  initialDestinationHouseId: _destinationHouseId,
                  initialDestinationLocation: _destinationLocation,
                  onChanged:
                      ({
                        description,
                        departureDateTime,
                        returnDateTime,
                        destinationHouseId,
                        destinationLocation,
                        destinationName,
                        name,
                      }) {
                        setState(() {
                          _description = description;
                          _departureDateTime = departureDateTime;
                          _returnDateTime = returnDateTime;
                          _destinationHouseId = destinationHouseId;
                          _destinationLocation = destinationLocation;
                          _destinationName = destinationName;
                          _name = name;
                        });
                      },
                ),

                SizedBox(height: context.spacingLg),

                // Stesso trattamento che ha in add_trip_screen: senza questa
                // sezione una tappa aggiunta in creazione non si potrebbe più
                // correggere né rimuovere, perché il dettaglio viaggio porta
                // qui e non a /trips/:id/edit.
                TripLegsSection(
                  legs: _legs,
                  onChanged: (legs) => setState(() => _legs = legs),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomContent: UniversalActionBar(
        // Key sulla pill: il test tocca il bottone senza dipendere dal testo
        // tradotto.
        primaryButtonKey: const Key('edit_trip_info_save'),
        primaryLabel: 'common.save_changes'.tr(),
        primaryIcon: Icons.save,
        onPrimaryPressed: _isLoading ? null : _saveChanges,
        isLoading: _isLoading,
      ),
    );
  }
}
