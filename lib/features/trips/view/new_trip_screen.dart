import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/helpers/dialog_helpers.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_link_button.dart';
import '../../../shared/widgets/ds_steps.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../houses/providers/house_provider.dart';
import '../model/trip_draft.dart';
import '../model/trip_postcard.dart';
import '../providers/trip_provider.dart';
import 'widgets/place_search.dart';
import 'widgets/postcard/trip_itinerary_view.dart';
import 'widgets/stop_sheet.dart';
import 'widgets/trip_dates_sheet.dart';
import '../../../shared/widgets/ds_field.dart';
import '../../../shared/widgets/ds_section_title.dart';

/// Id provvisorio per l'itinerario: la bozza non è ancora un viaggio salvato.
const _draftTripId = 'draft';

/// Dove si ferma il campo mancante dopo lo scorrimento, dall'alto.
const _missingAlignment = 0.1;

const _missingScrollDuration = Duration(milliseconds: 300);

/// Passo 1 di "Nuovo viaggio": meta, date, tappe e nome. Salva solo con meta,
/// date e nessuna tappa a zero notti.
class NewTripScreen extends ConsumerStatefulWidget {
  const NewTripScreen({super.key});

  @override
  ConsumerState<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends ConsumerState<NewTripScreen> {
  TripDraft _draft = const TripDraft.empty();
  final TextEditingController _nameController = TextEditingController();

  /// Vero mentre il viaggio si salva: i bottoni restano del loro colore.
  bool _saving = false;

  /// Dopo un tocco su un bottone spento: i campi mancanti si colorano.
  bool _showErrors = false;

  final GlobalKey _whereKey = GlobalKey();
  final GlobalKey _whenKey = GlobalKey();
  final GlobalKey _itineraryKey = GlobalKey();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _whereMissing => !_draft.hasDestination;

  bool get _whenMissing => !_draft.hasDates;

  /// Fine della prima tappa, o le date in attesa se non c'è ancora una meta.
  DateTime? get _firstEnd =>
      _draft.stops.isEmpty ? _draft.pendingEnd : _draft.stops.first.end;

  /// Cambia la bozza e riallinea il campo nome: segue la meta finché il nome
  /// non è stato scritto a mano.
  void _update(TripDraft next) {
    setState(() => _draft = next);
    final text = _draft.nameEdited
        ? _draft.name
        : (_draft.destination?.shortName ?? '');
    if (_nameController.text != text) {
      _nameController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  Future<void> _pickDates() async {
    final range = await showTripRangeSheet(
      context,
      initialDeparture: _draft.departure,
      initialReturn: _firstEnd,
    );
    if (!mounted || range == null || !range.isComplete) return;
    _update(_draft.withFirstDates(range.departureDate!, range.returnDate!));
  }

  Future<void> _addStop() async {
    final result = await showStopSheet(
      context,
      start: _draft.lastEnd!,
      previousName: _draft.stops.last.place.shortName,
    );
    if (!mounted) return;
    if (result case StopSaved(:final stop)) {
      _update(_draft.addStop(stop.place, stop.end));
    }
  }

  /// Modifica o elimina una tappa. La meta (indice 0) non si cambia qui: si
  /// cambia dalla sua ricerca.
  Future<void> _editStop(int index) async {
    if (index < 1) return;
    final stops = _draft.stops;
    final result = await showStopSheet(
      context,
      start: _draft.stopStart(index)!,
      previousName: stops[index - 1].place.shortName,
      initial: stops[index],
    );
    if (!mounted) return;
    switch (result) {
      case StopSaved(:final stop):
        _update(_draft.updateStop(index, place: stop.place, end: stop.end));
      case StopRemoved():
        _update(_draft.removeStop(index));
      case null:
        break;
    }
  }

  /// Bottone spento: colora i campi mancanti e scorre al primo. Le tappe a
  /// zero notti hanno già il loro avviso, quindi senza campi vuoti si scorre lì.
  void _showMissing() {
    setState(() => _showErrors = true);
    final target = _whereMissing
        ? _whereKey
        : _whenMissing
        ? _whenKey
        : _itineraryKey;
    final targetContext = target.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      alignment: _missingAlignment,
      duration: _missingScrollDuration,
    );
  }

  void _onLater() {
    if (!_draft.canSave) {
      _showMissing();
      return;
    }
    _save(goToPacking: false);
  }

  /// Salva il viaggio e va dove dice il passo 1. Con un errore il modulo resta
  /// compilato e la riprova la gestisce [ErrorRetryDialog].
  Future<void> _save({required bool goToPacking}) async {
    if (_saving) return;
    setState(() => _saving = true);

    // Il router si prende prima dell'attesa: dopo il salvataggio questo
    // context non è più montato.
    final router = GoRouter.of(context);
    final trip = _draft.toTripModel(id: const Uuid().v4(), now: DateTime.now());

    final saved = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref.read(tripNotifierProvider.notifier).addTrip(trip),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: 'errors.create_trip_failed'.tr(),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      return;
    }

    if (goToPacking) {
      router.go('/trips');
      router.push('/trips/${trip.id}/edit-items?from=new');
    } else {
      router.go('/trips?focus=${trip.id}');
    }
  }

  Future<void> _confirmDiscard() async {
    final leave = await DialogHelpers.showConfirmation(
      context: context,
      title: 'trips.new.discard_title'.tr(),
      message: 'trips.new.discard_message'.tr(),
      isDestructive: true,
    );
    if (leave && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final houses = ref.watch(houseNotifierProvider).valueOrNull ?? const [];
    final houseNames = {
      for (final house in houses) house.id: house.displayName,
    };

    return PopScope(
      // Il modulo con qualcosa scritto chiede conferma prima di uscire.
      // Durante il salvataggio il back non fa nulla: né uscita né dialogo.
      canPop: !_saving && !_draft.hasUserInput,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _saving) return;
        _confirmDiscard();
      },
      // Stesso scaffold degli altri form con CTA in fondo: i bottoni restano
      // fissi sotto il contenuto e, con la tastiera aperta, restano sotto la
      // tastiera invece di salire con essa. Due righe (bottone e link) e uno
      // sfondo pieno, perché il link non va letto sopra il testo che scorre.
      child: StickyCtaScaffold(
        appBar: AppBar(title: Text('trips.new.title'.tr())),
        ctaHeightOverride:
            StickyCtaScaffold.standardHeight(context) +
            kMinInteractiveDimension,
        ctaBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
        bottomContent: _buildBottomBar(context),
        body: Builder(
          builder: (context) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              context.spacingMd,
              context.spacingSm,
              context.spacingMd,
              context.spacingLg + context.ctaReservedHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DsSteps(
                  labels: [
                    'trips.new.step_trip'.tr(),
                    'trips.new.step_suitcase'.tr(),
                  ],
                  current: 0,
                ),
                _buildWhere(context),
                _buildWhen(context),
                _buildItinerary(context, houseNames),
                _buildName(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWhere(BuildContext context) {
    final place = _draft.destination;
    final showError = _showErrors && _whereMissing;

    return Column(
      key: _whereKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionTitle('trips.new.where'.tr()),
        if (place == null)
          PlaceSearch(
            key: const Key('new_trip_place_search'),
            hasError: showError,
            onSelected: (chosen) => _update(_draft.withDestination(chosen)),
          )
        else
          DsFieldBox(
            key: const Key('new_trip_destination'),
            icon: place.houseId == null
                ? Icons.place_outlined
                : Icons.home_outlined,
            suffixIcon: IconButton(
              key: const Key('new_trip_clear_destination'),
              tooltip: 'trips.new.where_clear'.tr(),
              icon: Icon(
                Icons.close,
                size: context.iconSizeSm,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => _update(_draft.clearDestination()),
            ),
            child: Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        if (showError) _FieldError('trips.new.where_missing'.tr()),
      ],
    );
  }

  Widget _buildWhen(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final departure = _draft.departure;
    final end = _firstEnd;
    final showError = _showErrors && _whenMissing;
    final nights = nightsBetween(departure, end);

    final value = departure == null || end == null
        ? null
        : '${_formatDay(context, departure)} – ${_formatDay(context, end)}';

    return Column(
      key: _whenKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionTitle('trips.new.when'.tr()),
        DsFieldBox(
          key: const Key('new_trip_dates'),
          icon: Icons.calendar_today_outlined,
          hasError: showError,
          onTap: _pickDates,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? 'common.tap_to_set_dates'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: value == null
                      ? tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)
                      : tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (value != null && nights != null)
                Text(
                  'trips.itinerary.nights'.plural(nights),
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
        if (showError) _FieldError('trips.new.when_missing'.tr()),
      ],
    );
  }

  Widget _buildItinerary(BuildContext context, Map<String, String> houseNames) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final stops = _draft.stops;

    return Column(
      key: _itineraryKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionTitle('trips.new.itinerary'.tr()),
        if (stops.isEmpty)
          Text(
            'trips.new.itinerary_empty'.tr(),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          )
        else ...[
          Material(
            color: context.groupSurface,
            borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.all(context.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TripItineraryView(
                    // Tutte le tappe, senza il riassunto "+N tappe": qui ognuna
                    // si tocca per modificarla.
                    entries: buildItinerary(
                      _draft.toTripModel(id: _draftTripId, now: DateTime.now()),
                      destination: _draft.destination!.shortName,
                      maxPlaces: math.max(2, stops.length),
                      houseNames: houseNames,
                      // La catena del passo 1 è la verità: le righe seguono
                      // l'ordine delle tappe, anche se una finisce prima di iniziare.
                      sortLegs: false,
                    ),
                    onPlaceTap: _editStop,
                    firstTappablePlace: 1,
                  ),
                  SizedBox(height: context.spacingSm),
                  DsLinkButton(
                    key: const Key('new_trip_add_stop'),
                    label: 'trips.new.stop_add'.tr(),
                    onPressed: _addStop,
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: context.spacingSm),
                    child: Text(
                      'trips.new.stops_tip'.tr(),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final index in (_draft.stopsWithoutNights.toList()..sort()))
            Padding(
              padding: EdgeInsets.only(top: context.spacingSm),
              child: Text(
                'trips.new.stop_no_nights'.tr(
                  args: [stops[index].place.shortName],
                ),
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildName(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionTitle('trips.new.name'.tr()),
        TextField(
          key: const Key('new_trip_name'),
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (text) => _update(_draft.withName(text)),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.edit_outlined,
              size: context.iconSizeMd,
              color: cs.onSurfaceVariant,
            ),
            filled: true,
            fillColor: context.groupSurface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.spacingMd,
              vertical: context.spacingMd,
            ),
            border: _inputBorder(cs.outlineVariant, 1),
            enabledBorder: _inputBorder(cs.outlineVariant, 1),
            focusedBorder: _inputBorder(cs.onSurface, 1.5),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: context.spacingSm),
          child: Text(
            'trips.new.name_hint'.tr(),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DsButton(
          key: const Key('new_trip_next'),
          label: 'trips.new.next'.tr(),
          icon: Icons.arrow_forward,
          expand: true,
          isLoading: _saving,
          onPressed: _draft.canSave ? () => _save(goToPacking: true) : null,
          onDisabledTap: _showMissing,
        ),
        DsLinkButton(
          key: const Key('new_trip_later'),
          label: 'trips.new.later'.tr(),
          onPressed: _onLater,
        ),
      ],
    );
  }
}

String _formatDay(BuildContext context, DateTime day) =>
    DateFormat('EEE d MMM', context.locale.toString()).format(day);

OutlineInputBorder _inputBorder(Color color, double width) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
      borderSide: BorderSide(color: color, width: width),
    );

/// Messaggio sotto un campo mancante, in colore di errore.
class _FieldError extends StatelessWidget {
  const _FieldError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.spacingXs, left: context.spacingMd),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
