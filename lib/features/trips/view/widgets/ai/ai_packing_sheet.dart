import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_button.dart';
import '../../../../../shared/widgets/ds_choice_group.dart';
import '../../../../../shared/widgets/ds_field_label.dart';
import '../../../../../shared/widgets/ds_form_sheet.dart';
import '../../../../../shared/widgets/ds_link_button.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../../houses/model/house_model.dart';
import '../../../../houses/providers/house_provider.dart';
import '../../../../luggages/model/luggage_model.dart';
import '../../../../luggages/providers/luggage_provider.dart';
import '../../../../luggages/view/add_edit_luggage_screen.dart';
import '../../../model/ai_availability.dart';
import '../../../model/ai_packing.dart';
import '../../../model/pack_trip_request.dart';
import '../../../model/trip_model.dart';
import '../../../model/trip_weather.dart';
import '../../../providers/trip_weather_provider.dart';
import '../pack/pack_weather.dart';
import 'ai_stop_form.dart';
import '../../../../../shared/widgets/ds_divider.dart';
import '../../../../../shared/widgets/ds_glass_band.dart';

/// Il foglio "Valigia con AI". Restituisce le risposte con "Prepara la
/// valigia", null se si chiude. Non salva nulla: lo fa il chiamante.
Future<AiPackingSetup?> showAiPackingSheet(
  BuildContext context, {
  required TripModel trip,
  required TripWeatherRequest plan,
}) => showDsFormSheet<AiPackingSetup>(
  context,
  builder: (_) => AiPackingSheet(trip: trip, plan: plan),
);

/// Il foglio, con le risposte di partenza prese da [TripModel.aiSetup].
class AiPackingSheet extends ConsumerStatefulWidget {
  const AiPackingSheet({super.key, required this.trip, required this.plan});

  final TripModel trip;
  final TripWeatherRequest plan;

  @override
  ConsumerState<AiPackingSheet> createState() => _AiPackingSheetState();
}

class _AiPackingSheetState extends ConsumerState<AiPackingSheet> {
  late final List<AiStop> _stops = aiStopsOf(widget.plan);

  /// Scelte fatte nel foglio; null = si usa quella salvata o la proposta.
  String? _houseId;
  String? _luggageId;

  /// Risposte per chiave di tappa.
  final Map<String, AiStopAnswers> _answers = {};

  /// Tappa mostrata nello stepper.
  int _cur = 0;

  /// Avviso di tappa incompleta già mostrato: il secondo tocco chiude.
  bool _warned = false;

  @override
  void initState() {
    super.initState();
    final setup = widget.trip.aiSetup;
    _houseId = setup?.houseId;
    _luggageId = setup?.luggageId;
    if (setup != null) _answers.addAll(setup.stops);
  }

  bool get _multi => _stops.length > 1;

  AiStopAnswers _answersOf(AiStop stop) =>
      _answers[stop.key] ?? const AiStopAnswers();

  void _update(AiStop stop, AiStopAnswers answers) {
    setState(() {
      _answers[stop.key] = answers;
      _warned = false;
    });
  }

  /// La casa scelta, o quella salvata se ancora c'è, o la proposta.
  HouseModel? _houseOf(List<HouseModel> houses) {
    for (final house in houses) {
      if (house.id == _houseId) return house;
    }
    final saved = widget.trip.aiSetup?.houseId;
    for (final house in houses) {
      if (house.id == saved) return house;
    }
    return proposedPackingHouse(houses, widget.trip);
  }

  /// Il bagaglio scelto, o quello salvato, o il primo del viaggio. Senza
  /// bagagli sul viaggio non si preseleziona niente.
  LuggageModel? _luggageOf(List<LuggageModel> luggages) {
    for (final luggage in luggages) {
      if (luggage.id == _luggageId) return luggage;
    }
    for (final luggage in luggages) {
      if (luggage.id == widget.trip.aiSetup?.luggageId) return luggage;
    }
    // Il primo dei bagagli del viaggio, nell'ordine del viaggio, che l'utente ha ancora.
    for (final onTrip in widget.trip.luggages) {
      final match = luggages
          .where((luggage) => luggage.id == onTrip.id)
          .firstOrNull;
      if (match != null) return match;
    }
    return null;
  }

  /// Prima tappa che manca di attività o alloggio, oppure -1.
  int get _incompleteIndex {
    if (!_multi) return -1;
    return _stops.indexWhere((stop) => _answersOf(stop).isIncomplete);
  }

  /// Dalla seconda tappa, se la tappa è intatta: la compilata più vicina prima
  /// di lei, altrimenti la prima dopo.
  int get _copySourceIndex {
    if (_cur == 0 || !_answersOf(_stops[_cur]).isUntouched) return -1;
    for (var i = _cur - 1; i >= 0; i--) {
      if (!_answersOf(_stops[i]).isIncomplete) return i;
    }
    for (var i = _cur + 1; i < _stops.length; i++) {
      if (!_answersOf(_stops[i]).isIncomplete) return i;
    }
    return -1;
  }

  void _finish(List<HouseModel> houses, List<LuggageModel> luggages) {
    Navigator.pop(
      context,
      AiPackingSetup(
        houseId: _houseOf(houses)?.id,
        luggageId: _luggageOf(luggages)?.id,
        stops: {for (final stop in _stops) stop.key: _answersOf(stop)},
      ),
    );
  }

  void _prepare(List<HouseModel> houses, List<LuggageModel> luggages) {
    if (_incompleteIndex >= 0 && !_warned) {
      setState(() => _warned = true);
      return;
    }
    _finish(houses, luggages);
  }

  @override
  Widget build(BuildContext context) {
    final houses = ref.watch(houseNotifierProvider);
    final luggages = ref.watch(luggageNotifierProvider);
    final weather = ref
        .watch(tripWeatherNotifierProvider(widget.trip.id))
        .valueOrNull;
    final houseList = houses.valueOrNull ?? const <HouseModel>[];
    final luggageList = luggages.valueOrNull ?? const <LuggageModel>[];
    final loading =
        (houses.isLoading && !houses.hasValue) ||
        (luggages.isLoading && !luggages.hasValue);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final stop = _stops[_cur];
    final isLast = _cur == _stops.length - 1;
    final incomplete = _incompleteIndex;
    final chosenHouse = _houseOf(houseList);
    final chosenLuggage = _luggageOf(luggageList);

    final body = loading
        ? Padding(
            padding: EdgeInsets.all(context.spacingLg),
            child: const Center(child: CircularProgressIndicator()),
          )
        : houseList.isEmpty
        ? Text(
            'trips.ai.no_houses'.tr(),
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsChoiceGroup<HouseModel>(
                title: 'trips.ai.house_title'.tr(),
                options: houseList,
                labelOf: (house) => house.displayName,
                selected: {?chosenHouse},
                onChanged: (chosen) =>
                    setState(() => _houseId = chosen.first.id),
              ),
              if (luggageList.isEmpty) ...[
                DsFieldLabel.prominent('trips.ai.luggage_title'.tr()),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DsLinkButton(
                    icon: Icons.add,
                    label: 'trips.ai.new_luggage'.tr(),
                    onPressed: () async {
                      final created = await showAddEditLuggageSheet(context);
                      if (created != null && mounted) {
                        setState(() => _luggageId = created.id);
                      }
                    },
                  ),
                ),
              ] else
                DsChoiceGroup<LuggageModel>(
                  title: 'trips.ai.luggage_title'.tr(),
                  options: luggageList,
                  labelOf: (luggage) => luggage.name,
                  selected: {?chosenLuggage},
                  onChanged: (chosen) =>
                      setState(() => _luggageId = chosen.first.id),
                ),
              SizedBox(height: context.spacingLg),
              const DsDivider(),
              if (_multi) ...[
                SizedBox(height: context.spacingMd),
                Text(
                  'trips.ai.stop_progress'.tr(
                    args: ['${_cur + 1}', '${_stops.length}', stop.name],
                  ),
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
                SizedBox(height: context.spacingSm),
                Row(
                  children: [
                    for (var i = 0; i < _stops.length; i++) ...[
                      if (i > 0) SizedBox(width: context.spacingXs),
                      Expanded(
                        child: Container(
                          height: AppConstants.progressSegmentHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppConstants.progressSegmentHeight / 2,
                            ),
                            color: i <= _cur ? cs.onSurface : cs.outlineVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_stopWeather(weather, stop) case final day?) ...[
                  SizedBox(height: context.spacingMd),
                  WeatherStopCard(stop: day),
                ],
              ],
              AiStopForm(
                answers: _answersOf(stop),
                stopName: _multi ? stop.name : null,
                copyFromName: _copySourceIndex >= 0
                    ? _stops[_copySourceIndex].name
                    : null,
                onCopy: _copySourceIndex >= 0
                    ? () => _update(stop, _answersOf(_stops[_copySourceIndex]))
                    : null,
                onChanged: (answers) => _update(stop, answers),
              ),
            ],
          );

    return DsFormSheet(
      title: 'trips.ai.title'.tr(),
      footer: loading || houseList.isEmpty
          ? null
          : _Footer(
              warning: _warned && incomplete >= 0
                  ? _IncompleteWarning(
                      stop: _stops[incomplete],
                      copyFrom: _firstComplete(incomplete),
                      onCopy: () {
                        final source = _firstComplete(incomplete);
                        if (source == null) return;
                        _update(_stops[incomplete], _answersOf(source));
                      },
                      onGo: () => setState(() {
                        _cur = incomplete;
                        _warned = false;
                      }),
                    )
                  : null,
              back: _multi && _cur > 0
                  ? () => setState(() {
                      _cur -= 1;
                      _warned = false;
                    })
                  : null,
              ctaLabel: isLast || !_multi
                  ? 'trips.ai.prepare'.tr()
                  : 'trips.ai.next'.tr(args: [_stops[_cur + 1].name]),
              primary: !_multi || isLast,
              ctaIcon: isLast ? Icons.auto_awesome : null,
              onCta: () => isLast || !_multi
                  ? _prepare(houseList, luggageList)
                  : setState(() {
                      _cur += 1;
                      _warned = false;
                    }),
            ),
      child: body,
    );
  }

  /// Prima tappa compilata, diversa da [except]: da lì copia l'avviso.
  AiStop? _firstComplete(int except) {
    for (var i = 0; i < _stops.length; i++) {
      if (i == except) continue;
      if (!_answersOf(_stops[i]).isIncomplete) return _stops[i];
    }
    return null;
  }

  /// La scheda meteo della tappa: la prima tratta se la tappa ha più periodi.
  StopWeather? _stopWeather(TripWeatherState? state, AiStop stop) {
    if (state is! TripWeatherReady) return null;
    final index = widget.plan.stops.indexWhere((s) => s.stopKey == stop.key);
    if (index < 0 || index >= state.weather.stops.length) return null;
    return state.weather.stops[index];
  }
}

/// L'avviso sopra il bottone: una tappa non è compilata.
class _IncompleteWarning extends StatelessWidget {
  const _IncompleteWarning({
    required this.stop,
    required this.copyFrom,
    required this.onCopy,
    required this.onGo,
  });

  final AiStop stop;
  final AiStop? copyFrom;
  final VoidCallback onCopy;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      key: const Key('ai_incomplete_warning'),
      padding: EdgeInsets.all(context.spacingMd),
      decoration: BoxDecoration(
        color: context.groupSurface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        // Neutro: nel foglio l'unico arancio è il bottone in fondo.
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'trips.ai.incomplete'.tr(args: [stop.name]),
            style: tt.bodyMedium,
          ),
          SizedBox(height: context.spacingSm),
          Wrap(
            spacing: context.spacingSm,
            runSpacing: context.spacingSm,
            children: [
              if (copyFrom != null)
                DsButton(
                  variant: DsButtonVariant.neutral,
                  onPressed: onCopy,
                  label: 'trips.ai.copy_from'.tr(args: [copyFrom!.name]),
                ),
              DsButton(
                variant: DsButtonVariant.neutral,
                onPressed: onGo,
                label: 'trips.ai.go_to_stop'.tr(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Il piè del foglio: avviso, "Indietro" e l'unico bottone arancio.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.ctaLabel,
    required this.onCta,
    required this.primary,
    this.ctaIcon,
    this.warning,
    this.back,
  });

  final String ctaLabel;
  final VoidCallback onCta;

  /// Vero solo per "Prepara la valigia": l'unico bottone arancio del foglio.
  final bool primary;
  final IconData? ctaIcon;
  final Widget? warning;
  final VoidCallback? back;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        DsGlassBand.topGap(context),
        context.spacingMd,
        context.spacingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (warning != null) ...[
            warning!,
            SizedBox(height: context.spacingMd),
          ],
          Row(
            children: [
              if (back != null)
                DsTextButton(onPressed: back, label: 'trips.ai.back'.tr()),
              Expanded(
                child: primary
                    ? DsButton(
                        label: ctaLabel,
                        icon: ctaIcon,
                        onPressed: onCta,
                        expand: true,
                      )
                    // Secondario: "Avanti" non è l'azione principale del foglio.
                    : DsButton(
                        variant: DsButtonVariant.neutral,
                        onPressed: onCta,
                        label: ctaLabel,
                        expand: true,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
