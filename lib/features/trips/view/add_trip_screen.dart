import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../model/trip_form_validation.dart';
import '../model/trip_leg.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../luggages/providers/luggage_provider.dart';
import '../../luggages/model/luggage_model.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/ds_section_header.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import 'trip_info_form.dart';
import 'trip_items_selector.dart';
import 'widgets/trip_legs_section.dart';

class AddTripScreen extends ConsumerStatefulWidget {
  final String? tripId;

  const AddTripScreen({super.key, this.tripId});

  @override
  ConsumerState<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends ConsumerState<AddTripScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  /// Passo del wizard. Vale solo in creazione: in modifica la schermata resta
  /// singola, perché gli oggetti di un viaggio esistente si cambiano da
  /// /trips/:id/edit-items.
  int _step = 0;

  /// Il wizard vale solo in creazione.
  bool get _isWizard => widget.tripId == null;

  // Dati del viaggio
  String? _name;

  /// Nome da salvare. `TripModel.name` non è nullable e un viaggio senza
  /// titolo in lista sarebbe illeggibile, quindi resta un segnaposto come rete
  /// di sicurezza — che in pratica non si vede mai, perché [tripFormError]
  /// blocca il salvataggio quando mancano sia il nome sia la destinazione.
  String get _effectiveName => (_name?.trim().isNotEmpty ?? false)
      ? _name!.trim()
      : 'trips.unnamed_destination'.tr();

  String? _description;
  DateTime? _departureDateTime;
  DateTime? _returnDateTime;
  String? _destinationHouseId;
  LocationSuggestionModel? _destinationLocation;
  String? _destinationName;
  List<TripItem> _selectedItems = [];
  List<LuggageModel> _selectedLuggages = [];
  List<TripLeg> _legs = [];

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
        _legs = List.from(trip.legs);
      });
    });
  }

  Future<void> _saveTrip() async {
    // Al passo 2 del wizard il `Form` del passo 1 non è più montato, quindi
    // `currentState` è null: in quel caso non c'è nulla da validare qui (i
    // campi del passo 1 sono già stati controllati prima di avanzare).
    if (!(_formKey.currentState?.validate() ?? true)) return;

    // Bottone sempre attivo: un bottone spento senza spiegazione non fa
    // distinguere "manca qualcosa" da "l'app è rotta".
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

    final now = DateTime.now();
    final trip = widget.tripId != null
        ? (() {
            final tripsAsync = ref.read(tripNotifierProvider);
            final trips = tripsAsync.value;
            if (trips == null) throw StateError('Lista non trovata');
            return trips
                .firstWhere((t) => t.id == widget.tripId)
                .copyWith(
                  name: _effectiveName,
                  description: _description,
                  items: _selectedItems,
                  luggages: _selectedLuggages,
                  legs: _legs,
                  departureDateTime: _departureDateTime,
                  returnDateTime: _returnDateTime,
                  destinationHouseId: _destinationHouseId,
                  destinationLocation: _destinationHouseId == null
                      ? _destinationLocation
                      : (_destinationName?.isNotEmpty == true
                            ? LocationSuggestionModel(
                                placeId: '',
                                displayName: _destinationName!,
                              )
                            : null),
                  updatedAt: now,
                );
          })()
        : TripModel(
            id: const Uuid().v4(),
            name: _effectiveName,
            description: _description,
            items: _selectedItems,
            luggages: _selectedLuggages,
            legs: _legs,
            departureDateTime: _departureDateTime,
            returnDateTime: _returnDateTime,
            destinationHouseId: _destinationHouseId,
            destinationLocation: _destinationHouseId == null
                ? _destinationLocation
                : (_destinationName?.isNotEmpty == true
                      ? LocationSuggestionModel(
                          placeId: '',
                          displayName: _destinationName!,
                        )
                      : null),
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

  /// Etichetta della CTA.
  ///
  /// Il conteggio compare da 1 in su: "(0)" su un bottone si legge come un
  /// avviso, proprio dove vogliamo dire il contrario.
  String _ctaLabel() {
    if (!_isWizard) return 'common.save_changes'.tr();
    if (_step == 0) return 'common.next'.tr();
    return _selectedItems.isEmpty
        ? 'trips.create_trip'.tr()
        : 'trips.create_trip_with_count'.tr(
            args: [_selectedItems.length.toString()],
          );
  }

  Future<void> _onPrimaryPressed() async {
    if (_isWizard && _step == 0) {
      if (!(_formKey.currentState?.validate() ?? true)) return;

      // Bottone sempre attivo: l'errore si spiega qui, non spegnendo la CTA.
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
      setState(() => _step = 1);
      return;
    }
    await _saveTrip();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Dal passo 2 il tasto indietro di sistema torna al passo 1 invece di
      // abbandonare la creazione a metà.
      canPop: !(_isWizard && _step == 1),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _step = 0);
      },
      child: StickyCtaScaffold(
        appBar: AppBar(
          title: Text(
            widget.tripId != null ? 'trips.edit'.tr() : 'trips.add_new'.tr(),
          ),
          bottom: _isWizard
              ? PreferredSize(
                  // L'altezza segue il testo invece di essere fissa: la riga
                  // contiene bodySmall (12) più il padding basso, e con
                  // "testo grande" di sistema un valore costante tornerebbe
                  // in overflow.
                  preferredSize: Size.fromHeight(
                    MediaQuery.textScalerOf(context).scale(20) +
                        context.spacingSm,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: context.spacingMd,
                      right: context.spacingMd,
                      bottom: context.spacingSm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: _step == 0 ? 0.5 : 1,
                            minHeight: 3,
                          ),
                        ),
                        SizedBox(width: context.spacingSm),
                        Text(
                          'trips.step_of'.tr(args: ['${_step + 1}', '2']),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        ),
        // Builder: ctaReservedHeight legge CtaReservedSpaceScope, che
        // StickyCtaScaffold inserisce come discendente di `body` — serve un
        // context interno a questo subtree, non quello del metodo build
        // esterno (che sta sopra lo scope e non lo vedrebbe mai).
        body: Builder(
          builder: (context) => _isWizard && _step == 1
              ? _buildItemsStep(context)
              : _buildInfoStep(context),
        ),
        bottomContent: UniversalActionBar(
          primaryLabel: _ctaLabel(),
          primaryIcon: _isWizard && _step == 0
              ? Icons.arrow_forward
              : Icons.save,
          onPrimaryPressed: _isLoading ? null : _onPrimaryPressed,
          isLoading: _isLoading,
        ),
      ),
    );
  }

  /// Passo 1 (e pagina unica in modifica): dati del viaggio e tappe.
  ///
  /// In modifica include anche oggetti e bagagli, perché lì la schermata resta
  /// a pagina singola.
  Widget _buildInfoStep(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMd,
          vertical: context.spacingSm,
        ).copyWith(bottom: context.spacingSm + context.ctaReservedHeight),
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

            TripLegsSection(
              legs: _legs,
              onChanged: (legs) => setState(() => _legs = legs),
            ),

            if (!_isWizard) ...[
              SizedBox(height: context.spacingLg),
              _buildItemsAndLuggages(context),
            ],
          ],
        ),
      ),
    );
  }

  /// Oggetti e bagagli dentro lo scroll della pagina singola (solo modifica).
  Widget _buildItemsAndLuggages(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sezione Oggetti
        DsSectionHeader(
          label: 'trips.items_to_bring'.tr(),
          padding: EdgeInsets.zero,
          trailing: _SectionCount(
            label: 'common.items_selected'.tr(
              args: [_selectedItems.length.toString()],
            ),
          ),
        ),
        SizedBox(height: context.spacingMd),

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
        DsSectionHeader(
          label: 'luggages.title'.tr(),
          padding: EdgeInsets.zero,
          trailing: _SectionCount(
            label: 'common.luggages_selected'.tr(
              args: [_selectedLuggages.length.toString()],
            ),
          ),
        ),
        SizedBox(height: context.spacingMd),

        _buildLuggageSelector(),
      ],
    );
  }

  /// Passo 2 del wizard: il selettore oggetti prende tutta l'altezza libera,
  /// così scorre per conto suo invece di allungare la pagina.
  Widget _buildItemsStep(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingSm,
      ).copyWith(bottom: context.ctaReservedHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsSectionHeader(
            label: 'trips.items_to_bring'.tr(),
            padding: EdgeInsets.zero,
            trailing: _SectionCount(
              label: 'common.items_selected'.tr(
                args: [_selectedItems.length.toString()],
              ),
            ),
          ),
          SizedBox(height: context.spacingMd),
          Expanded(
            child: TripItemsSelector(
              selectedItems: _selectedItems,
              onSelectionChanged: (items) =>
                  setState(() => _selectedItems = items),
            ),
          ),
          SizedBox(height: context.spacingMd),
          DsSectionHeader(
            label: 'luggages.title'.tr(),
            padding: EdgeInsets.zero,
            trailing: _SectionCount(
              label: 'common.luggages_selected'.tr(
                args: [_selectedLuggages.length.toString()],
              ),
            ),
          ),
          SizedBox(height: context.spacingMd),
          // Tetto d'altezza (non un Flexible): la Wrap dei bagagli cresce con
          // il numero di bagagli e senza limite manderebbe la Column in
          // overflow. Un Flexible si spartirebbe invece lo spazio con
          // l'Expanded qui sopra, dimezzando la lista oggetti anche quando i
          // bagagli sono due.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: context.responsive(140)),
            child: SingleChildScrollView(child: _buildLuggageSelector()),
          ),
        ],
      ),
    );
  }

  Widget _buildLuggageSelector() {
    // Cross-house list: in fase di creazione viaggio l'utente può
    // selezionare bagagli da qualunque casa.
    final luggagesAsync = ref.watch(allLuggagesProvider);

    return luggagesAsync.when(
      data: (allLuggages) {
        if (allLuggages.isEmpty) {
          return DsEmptyState(
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
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                  SizedBox(width: context.spacingXs),
                  Text(luggage.name),
                  SizedBox(width: context.spacingXs),
                  Text(
                    '(${luggage.effectiveVolumeLiters ?? 0}L)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
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
              selectedColor: colorScheme.primaryContainer,
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

/// Conteggio a fianco del titolo di sezione ("3 selezionati").
///
/// È un dato di stato, non un'azione: niente fill arancione. Resta un badge
/// per distinguerlo dal titolo, ma su superficie neutra.
class _SectionCount extends StatelessWidget {
  final String label;

  const _SectionCount({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Testo semplice, niente riquadro: è un conteggio di stato accanto al
    // titolo di sezione, e un badge su "0 selezionati" dava peso visivo a
    // un'informazione che il più delle volte dice "niente".
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
    );
  }
}
