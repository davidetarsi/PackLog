import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/model/house_model.dart';
import '../model/trip_date_range.dart';
import '../view/trip_date_range_screen.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/helpers/design_system.dart';
import '../../../shared/widgets/app_pill_tab.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';

class TripInfoForm extends ConsumerStatefulWidget {
  final String? initialName;
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
    String? name,
  })
  onChanged;

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
  late TextEditingController _descriptionController;
  late TextEditingController _nameController;
  final _nameFocusNode = FocusNode();
  DateTime? _departureDateTime;
  DateTime? _returnDateTime;
  String? _destinationHouseId;
  String? _destinationHouseName;
  LocationSuggestionModel? _destinationLocation;
  late bool _useHouseDestination;

  /// Una volta che l'utente ha scritto il nome, nessun cambio di destinazione
  /// o di date lo tocca più. Senza questo flag l'app cancellerebbe quello che
  /// l'utente ha appena scritto.
  bool _nameTouched = false;

  /// _derivedName() usa context.locale, non chiamabile in initState: il primo
  /// didChangeDependencies calcola il valore reale di _nameTouched una sola
  /// volta (guardia). Finché non scatta, il default resta conservativo.
  bool _initialTouchComputed = false;

  // _accentColor rimosso — usare colorScheme.primary nei build methods.

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _nameController = TextEditingController(text: widget.initialName ?? '');
    // Default conservativo finché didChangeDependencies non può calcolare il
    // valore reale (serve context.locale per _derivedName): meglio non
    // aggiornare un nome che rischiare di cancellarne uno scritto a mano.
    _nameTouched = true;
    _nameFocusNode.addListener(_onNameFocusChanged);
    _departureDateTime = widget.initialDepartureDateTime;
    _returnDateTime = widget.initialReturnDateTime;
    _destinationHouseId = widget.initialDestinationHouseId;
    _destinationLocation = widget.initialDestinationLocation;
    _useHouseDestination = widget.initialDestinationHouseId != null;
    if (_destinationHouseId != null) {
      final housesAsync = ref.read(houseNotifierProvider);
      housesAsync.whenData((houses) {
        final house = houses
            .where((h) => h.id == _destinationHouseId)
            .firstOrNull;
        _destinationHouseName = house?.displayName;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _notifyChanged();
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialTouchComputed) return;
    _initialTouchComputed = true;
    final initial = widget.initialName ?? '';
    // "Toccato" solo se il nome iniziale differisce da quello che il calcolo
    // automatico produrrebbe: un nome mai personalizzato deve continuare a
    // seguire date e destinazione anche in modifica, uno personalizzato no.
    _nameTouched = initial.isNotEmpty && initial != _derivedName();
  }

  @override
  void didUpdateWidget(covariant TripInfoForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Mentre il campo ha il focus non lo riscrive nessuno, genitore incluso:
    // il giro onChanged → setState del genitore → initialName ci rimanda qui
    // il nome derivato mentre l'utente sta ancora digitando (basta che svuoti
    // il campo perché _notifyChanged emetta il derivato), e adottarlo gli
    // cancellerebbe il testo sotto le dita ricollassando il cursore. È la
    // stessa guardia che ha _syncDerivedName; al blur ci pensa
    // _onNameFocusChanged.
    // Le altre condizioni: solo se la prop è cambiata davvero, il campo non è
    // "touched" e il testo proposto differisce da quello già nel controller —
    // riscrivere con lo stesso identico testo collasserebbe comunque la
    // selection.
    final newName = widget.initialName ?? '';
    if (widget.initialName != oldWidget.initialName &&
        !_nameFocusNode.hasFocus &&
        !_nameTouched &&
        newName.isNotEmpty &&
        newName != _nameController.text) {
      _nameController.text = newName;
      // Adottare un nome che coincide col derivato non è una
      // personalizzazione: marcarlo "toccato" congelerebbe per sempre un nome
      // che l'utente non ha mai scritto (caso reale: add_trip_screen in
      // modifica che carica il viaggio dopo il primo frame). È la stessa
      // asimmetria che didChangeDependencies già evita sul nome iniziale.
      // Se invece il nome è davvero personalizzato va difeso, altrimenti il
      // prossimo _notifyChanged() lo sovrascriverebbe subito col derivato.
      if (newName != _derivedName()) _nameTouched = true;
    }
    if (widget.initialDescription != oldWidget.initialDescription &&
        (widget.initialDescription ?? '') != _descriptionController.text) {
      _descriptionController.text = widget.initialDescription ?? '';
    }
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_onNameFocusChanged);
    _nameFocusNode.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Nome derivato da destinazione e date, com'era prima nelle schermate.
  String _derivedName() {
    final destination = _destinationHouseId != null
        ? _destinationHouseName
        : _destinationLocation?.displayName;
    final dest = (destination?.trim().isNotEmpty == true)
        ? destination!.trim()
        : 'trips.unnamed_destination'.tr();

    final dep = _departureDateTime != null
        ? DateFormat.yMd(context.locale.toString()).format(_departureDateTime!)
        : '';
    final ret = _returnDateTime != null
        ? DateFormat.yMd(context.locale.toString()).format(_returnDateTime!)
        : '';

    if (dep.isEmpty) return dest;
    return ret.isEmpty ? '$dest, $dep' : '$dest, $dep – $ret';
  }

  /// Alla perdita di focus un campo vuoto torna al nome derivato — aspettare
  /// il salvataggio lascerebbe un campo visibilmente vuoto per tutta la
  /// compilazione.
  void _onNameFocusChanged() {
    if (_nameFocusNode.hasFocus) return;
    if (_nameController.text.trim().isNotEmpty) return;
    setState(() {
      // Riaggancia: senza questo, cambiare le date dopo aver svuotato il
      // campo lascerebbe il nome congelato sulle date vecchie.
      _nameTouched = false;
      _nameController.text = _derivedName();
    });
    _notifyChanged();
  }

  void _syncDerivedName() {
    // Mentre l'utente ha il campo sotto le dita non si tocca il controller:
    // riscriverlo cancellerebbe quello che sta digitando e sposterebbe il
    // cursore. Il ripristino del nome derivato avviene al blur.
    if (_nameFocusNode.hasFocus) return;
    if (_nameTouched) return;
    _nameController.text = _derivedName();
  }

  void _notifyChanged() {
    _syncDerivedName();

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
      name: _nameController.text.trim().isEmpty
          ? _derivedName()
          : _nameController.text.trim(),
    );
  }

  Future<void> _pickDateRange() async {
    final result = await Navigator.of(context).push<TripDateRange>(
      MaterialPageRoute(
        builder: (_) => TripDateRangeScreen(
          initialDeparture: _departureDateTime,
          initialReturn: _returnDateTime,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _departureDateTime = result.departureDate;
      _returnDateTime = result.returnDate;
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
        // ── Nome del viaggio ──────────────────────────────────────────
        Text(
          'trips.name_label'.tr(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.spacingXs),
        TextField(
          key: const Key('trip_name_field'),
          controller: _nameController,
          focusNode: _nameFocusNode,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.inputBorderRadius,
              ),
            ),
            // La matita dichiara che il nome precompilato è modificabile,
            // senza aggiungere testo.
            suffixIcon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          onChanged: (value) {
            _nameTouched = value.trim().isNotEmpty;
            _notifyChanged();
          },
        ),
        SizedBox(height: context.spacingMd),

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
                    child: DsErrorState(
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
              padding: context.cardPaddingHero,
              child: Row(
                children: [
                  // Icona-etichetta, non azione: grigia come le altre.
                  Icon(
                    Icons.calendar_month_outlined,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  SizedBox(width: context.spacingMd),
                  Expanded(
                    child:
                        (_departureDateTime != null || _returnDateTime != null)
                        ? Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'common.departure'.tr(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(_departureDateTime),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.spacingXs,
                                ),
                                child: Icon(
                                  Icons.arrow_forward,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 16,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'common.return'.tr(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(_returnDateTime),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'common.tap_to_set_dates'.tr(),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
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
            Icon(
              Icons.home_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 22,
            ),
            SizedBox(width: context.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'common.arrival_house'.tr(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getSelectedHouseName(houses),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
          Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 22),
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
