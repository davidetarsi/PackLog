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
import '../../../shared/widgets/ds_icon_button.dart';
import '../../../shared/widgets/ds_link_button.dart';
import '../../../shared/widgets/ds_steps.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../houses/providers/house_provider.dart';
import '../../../core/monitoring/monitoring_service.dart';
import '../model/trip_draft.dart';
import '../model/trip_model.dart';
import '../model/trip_postcard.dart';
import '../providers/trip_provider.dart';
import '../providers/trip_weather_provider.dart';
import 'widgets/place_search.dart';
import 'widgets/postcard/trip_itinerary_view.dart';
import 'widgets/stop_sheet.dart';
import 'widgets/trip_dates_sheet.dart';
import 'widgets/trip_edit_placeholder.dart';
import '../../../shared/widgets/ds_field.dart';
import '../../../shared/widgets/ds_section_title.dart';

/// Id provvisorio per l'itinerario: la bozza non è ancora un viaggio salvato.
const _draftTripId = 'draft';

/// Dove si ferma il campo mancante dopo lo scorrimento, dall'alto.
const _missingAlignment = 0.1;

const _missingScrollDuration = AppMotion.slow;

/// Passo 1 di "Nuovo viaggio": meta, date, tappe e nome. Salva solo con meta,
/// date e nessuna tappa a zero notti.
///
/// Con [tripId] è la modifica di un viaggio esistente: stessa pagina, senza i
/// passi, con un solo "Salva" che si accende dopo un cambiamento.
class NewTripScreen extends ConsumerStatefulWidget {
  const NewTripScreen({
    super.key,
    this.tripId,
    this.discardOnExit = false,
    this.aiIntent = false,
  });

  /// Viaggio da modificare; null per un viaggio nuovo.
  final String? tripId;

  /// Se `true`, uscire senza un salvataggio riuscito elimina il viaggio.
  /// Serve al flusso "Riusa": la copia nasce senza date e, se l'utente la
  /// abbandona, non deve restare in lista.
  final bool discardOnExit;

  /// Viene da "Valigia con AI" (`/new-trip?ai=1`): il primario del passo 1 è
  /// "Prepara con AI" e la strada manuale diventa un link.
  final bool aiIntent;

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

  /// In modifica: il viaggio com'era all'apertura.
  TripModel? _original;

  /// In modifica: l'utente ha cambiato qualcosa.
  bool _edited = false;

  /// In modifica: salvato con successo, l'uscita non elimina nulla.
  bool _savedOk = false;

  bool get _isEdit => widget.tripId != null;

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
    setState(() {
      _draft = next;
      _edited = true;
    });
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

  /// Strada manuale ("Prepara a mano"): passo 2 senza AI. È un link,
  /// quindi non si spegne: senza campi mostra gli errori come il bottone.
  void _onPackMyself() {
    if (!_draft.canSave) {
      _showMissing();
      return;
    }
    _save(goToPacking: true);
  }

  /// Salva il viaggio e va dove dice il passo 1. Con [withAi] la pagina
  /// valigia parte con il foglio "Valigia con AI" aperto. Con un errore il
  /// modulo resta compilato e la riprova la gestisce [ErrorRetryDialog].
  Future<void> _save({required bool goToPacking, bool withAi = false}) async {
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
      // Il meteo parte con "Avanti": la pagina valigia trova la richiesta già
      // in corso, o la cache se il viaggio ce l'ha già.
      ref.read(tripWeatherNotifierProvider(trip.id));
      router.go('/trips');
      router.push(
        '/trips/${trip.id}/edit-items?from=new${withAi ? '&ai=1' : ''}',
      );
    } else {
      router.go('/trips?focus=${trip.id}');
    }
  }

  /// In modifica: riporta i cambiamenti sul viaggio di adesso, che conserva
  /// oggetti, bagagli, valigia AI, nota e tutto il resto.
  Future<void> _saveEdit() async {
    final original = _original;
    if (_saving || original == null) return;
    setState(() => _saving = true);
    final draftTrip = _draft.toTripModel(id: original.id, now: DateTime.now());
    // Il viaggio com'è adesso nel provider, non la copia di apertura: risposte
    // AI, oggetti e bagagli salvati nel frattempo non devono sparire.
    final corrente = ref
        .read(tripNotifierProvider)
        .valueOrNull
        ?.where((t) => t.id == original.id)
        .firstOrNull;
    final updated = (corrente ?? original).copyWith(
      name: draftTrip.name,
      departureDateTime: draftTrip.departureDateTime,
      returnDateTime: draftTrip.returnDateTime,
      destinationHouseId: draftTrip.destinationHouseId,
      destinationLocation: draftTrip.destinationLocation,
      legs: draftTrip.legs,
      updatedAt: draftTrip.updatedAt,
    );
    final saved = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () =>
          ref.read(tripNotifierProvider.notifier).updateTrip(updated),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: 'errors.save_trip_failed'.tr(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      // Prima del pop: l'uscita non va scambiata per un abbandono.
      _savedOk = true;
      context.pop();
    }
  }

  /// La pagina si è chiusa: con "Riusa" e senza salvataggio la copia va via.
  void _onClosed() {
    if (!_isEdit || !widget.discardOnExit || _savedOk) return;
    // Catturati prima: il callback d'errore può arrivare dopo il dispose.
    final notifier = ref.read(tripNotifierProvider.notifier);
    final monitoring = ref.read(monitoringServiceProvider);
    notifier
        .deleteTrip(widget.tripId!)
        .catchError(
          (Object error, StackTrace stack) =>
              monitoring.captureException(error, stackTrace: stack),
        );
  }

  /// Copia il viaggio nella bozza, una volta sola: un sync che rimpiazza la
  /// lista non deve sovrascrivere ciò che l'utente sta modificando. Nessun
  /// `setState`: siamo dentro il build che legge questi campi subito dopo.
  void _hydrate(TripModel trip, Map<String, String> houseNames) {
    if (_original != null) return;
    _original = trip;
    _draft = TripDraft.fromTrip(
      trip,
      houseName: houseNames[trip.destinationHouseId],
    );
    _nameController.text = _draft.name;
  }

  Future<void> _confirmDiscard() async {
    final leave = await DialogHelpers.showConfirmation(
      context: context,
      title: _isEdit
          ? 'trips.edit.discard_title'.tr()
          : 'trips.new.discard_title'.tr(),
      message: _isEdit
          ? 'trips.edit.discard_message'.tr()
          : 'trips.new.discard_message'.tr(),
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

    if (_isEdit) {
      final tripsAsync = ref.watch(tripNotifierProvider);
      final trip = tripsAsync.valueOrNull
          ?.where((t) => t.id == widget.tripId)
          .firstOrNull;
      if (trip != null) _hydrate(trip, houseNames);
      final placeholder = tripEditPlaceholder(
        context: context,
        ref: ref,
        title: 'trips.detail.edit_trip'.tr(),
        tripsAsync: tripsAsync,
        isHydrated: _original != null,
      );
      if (placeholder != null) {
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) _onClosed();
          },
          child: placeholder,
        );
      }
    }

    final hasChanges = _isEdit ? _edited : _draft.hasUserInput;

    return PopScope(
      // Il modulo con qualcosa scritto (o cambiato) chiede conferma prima di
      // uscire. Durante il salvataggio il back non fa nulla.
      canPop: !_saving && !hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _onClosed();
          return;
        }
        if (_saving) return;
        _confirmDiscard();
      },
      // Stesso scaffold degli altri form con CTA in fondo: i bottoni restano
      // fissi sotto il contenuto e, con la tastiera aperta, restano sotto la
      // tastiera invece di salire con essa. Due righe (bottone e link) sulla
      // fascia di vetro: il testo dietro è sfocato, il link si legge.
      child: StickyCtaScaffold(
        appBar: AppBar(
          title: Text(
            _isEdit ? 'trips.detail.edit_trip'.tr() : 'trips.new.title'.tr(),
          ),
        ),
        // Il nuovo viaggio ha bottone e link; la modifica solo il bottone.
        ctaHeightOverride: _isEdit ? null : _newTripCtaHeight(context),
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
                if (!_isEdit)
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
        DsSectionTitle('trips.new.where'.tr(), isRequired: true),
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
            suffixIcon: DsIconButton(
              key: const Key('new_trip_clear_destination'),
              tooltip: 'trips.new.where_clear'.tr(),
              icon: Icons.close,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              onPressed: () => _update(_draft.clearDestination()),
            ),
            child: Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.strong,
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
        DsSectionTitle('trips.new.when'.tr(), isRequired: true),
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
                      : tt.bodyLarge?.strong,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionTitle('trips.new.name'.tr()),
        DsTextField(
          key: const Key('new_trip_name'),
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          prefixIcon: Icons.edit_outlined,
          helperText: 'trips.new.name_hint'.tr(),
          onChanged: (text) => _update(_draft.withName(text)),
        ),
      ],
    );
  }

  /// Fascia in fondo al passo 1: "Avanti" e "Prepara con AI" (due bottoni) più
  /// il link "Più tardi"; con [NewTripScreen.aiIntent] un bottone e due link.
  double _newTripCtaHeight(BuildContext context) =>
      StickyCtaScaffold.standardHeight(context) +
      (widget.aiIntent
          ? kMinInteractiveDimension * 2
          : context.spacingSm +
                context.responsive(AppConstants.ctaHeight) +
                kMinInteractiveDimension);

  Widget _buildBottomBar(BuildContext context) {
    if (_isEdit) {
      return DsButton(
        key: const Key('edit_trip_save'),
        label: 'common.save'.tr(),
        expand: true,
        isLoading: _saving,
        onPressed: _draft.canSave && _edited ? _saveEdit : null,
        onDisabledTap: _draft.canSave ? null : _showMissing,
      );
    }
    // Senza meta e date i link sono spenti come i bottoni; toccare un
    // bottone spento mostra cosa manca.
    final later = DsLinkButton(
      key: const Key('new_trip_later'),
      label: 'trips.new.later'.tr(),
      onPressed: _draft.canSave ? _onLater : null,
    );

    if (widget.aiIntent) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _prepareAiButton(),
          DsLinkButton(
            key: const Key('new_trip_manual'),
            label: 'trips.new.pack_myself'.tr(),
            onPressed: _draft.canSave ? _onPackMyself : null,
          ),
          later,
        ],
      );
    }
    // Prima la valigia con AI, arancio; "Avanti" a mano è la seconda strada,
    // a contorno neutro.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _prepareAiButton(),
        SizedBox(height: context.spacingSm),
        DsButton(
          key: const Key('new_trip_next'),
          variant: DsButtonVariant.neutral,
          label: 'trips.new.next'.tr(),
          icon: Icons.arrow_forward,
          expand: true,
          onPressed: _draft.canSave && !_saving
              ? () => _save(goToPacking: true)
              : null,
          onDisabledTap: _saving ? null : _showMissing,
        ),
        later,
      ],
    );
  }

  /// "Prepara con AI": la strada principale, arancio. Spento finché mancano
  /// meta o date; il tocco da spento mostra cosa manca.
  Widget _prepareAiButton() {
    return DsButton(
      key: const Key('new_trip_prepare_ai'),
      label: 'trips.new.prepare_with_ai'.tr(),
      icon: Icons.auto_awesome,
      expand: true,
      isLoading: _saving,
      onPressed: _draft.canSave
          ? () => _save(goToPacking: true, withAi: true)
          : null,
      onDisabledTap: _showMissing,
    );
  }
}

String _formatDay(BuildContext context, DateTime day) =>
    DateFormat('EEE d MMM', context.locale.toString()).format(day);

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
