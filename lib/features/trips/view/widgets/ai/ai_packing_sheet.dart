import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_button.dart';
import '../../../../../shared/widgets/ds_form_sheet.dart';
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
import 'ai_choice_pill.dart';
import 'ai_stop_form.dart';

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

  /// Il bagaglio scelto, o quello salvato, o il primo del viaggio, o il primo
  /// dell'utente.
  LuggageModel? _luggageOf(List<LuggageModel> luggages) {
    for (final luggage in luggages) {
      if (luggage.id == _luggageId) return luggage;
    }
    for (final luggage in luggages) {
      if (luggage.id == widget.trip.aiSetup?.luggageId) return luggage;
    }
    final onTrip = {for (final luggage in widget.trip.luggages) luggage.id};
    return luggages
            .where((luggage) => onTrip.contains(luggage.id))
            .firstOrNull ??
        luggages.firstOrNull;
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
        ? const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        : houseList.isEmpty
        ? Text(
            'trips.ai.no_houses'.tr(),
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Block(
                title: 'trips.ai.house_title'.tr(),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final house in houseList)
                      AiChoicePill(
                        label: house.displayName,
                        selected: house.id == chosenHouse?.id,
                        onTap: () => setState(() => _houseId = house.id),
                      ),
                  ],
                ),
              ),
              _Block(
                title: 'trips.ai.luggage_title'.tr(),
                child: luggageList.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurface,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text('trips.ai.new_luggage'.tr()),
                          onPressed: () async {
                            final created = await showAddEditLuggageSheet(
                              context,
                            );
                            if (created != null && mounted) {
                              setState(() => _luggageId = created.id);
                            }
                          },
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final luggage in luggageList)
                            AiChoicePill(
                              label: luggage.name,
                              selected: luggage.id == chosenLuggage?.id,
                              onTap: () =>
                                  setState(() => _luggageId = luggage.id),
                            ),
                        ],
                      ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 16),
              if (_multi) ...[
                Text(
                  'trips.ai.stop_progress'.tr(
                    args: ['${_cur + 1}', '${_stops.length}', stop.name],
                  ),
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < _stops.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: i <= _cur ? cs.onSurface : cs.outlineVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                if (_stopWeather(weather, stop) case final day?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _StopWeatherCard(stop: day),
                  ),
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

/// Un blocco del foglio: titolo e contenuto.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// La scheda meteo di una tappa, dai dati già pronti di `trip-weather`.
class _StopWeatherCard extends StatelessWidget {
  const _StopWeatherCard({required this.stop});

  final StopWeather stop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final locale = context.locale.toString();
    final format = DateFormat('d MMM', locale);
    final rainDays = stop.rainDays?.round();
    final min = stop.tempMin;
    final max = stop.tempMax;
    final details = [
      '${format.format(stop.from)} – ${format.format(stop.to)}',
      if (rainDays != null) 'trips.weather.rain_days'.plural(rainDays),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.groupSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.name,
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  details,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (min != null && max != null)
            Text(
              'trips.weather.temps'.tr(
                args: [min.round().toString(), max.round().toString()],
              ),
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.groupSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'trips.ai.incomplete'.tr(args: [stop.name]),
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (copyFrom != null)
                OutlinedButton(
                  onPressed: onCopy,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    side: BorderSide(color: cs.outline),
                  ),
                  child: Text('trips.ai.copy_from'.tr(args: [copyFrom!.name])),
                ),
              OutlinedButton(
                onPressed: onGo,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Text('trips.ai.go_to_stop'.tr()),
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
    this.ctaIcon,
    this.warning,
    this.back,
  });

  final String ctaLabel;
  final VoidCallback onCta;
  final IconData? ctaIcon;
  final Widget? warning;
  final VoidCallback? back;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        0,
        context.spacingMd,
        context.spacingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (warning != null) ...[warning!, const SizedBox(height: 12)],
          Row(
            children: [
              if (back != null)
                TextButton(
                  onPressed: back,
                  style: TextButton.styleFrom(foregroundColor: cs.onSurface),
                  child: Text('trips.ai.back'.tr()),
                ),
              Expanded(
                child: DsButton(
                  label: ctaLabel,
                  icon: ctaIcon,
                  onPressed: onCta,
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
