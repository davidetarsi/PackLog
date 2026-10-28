import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/ds_empty_state.dart';
import '../model/trip_weather.dart';
import '../providers/trip_weather_provider.dart';
import 'widgets/pack/weather_icons.dart';
import '../../../shared/widgets/ds_divider.dart';

/// Il meteo dei prossimi giorni di una tappa: per ogni giorno il riepilogo e
/// le sei fasce di quattro ore, con icona, temperatura media e pioggia.
///
/// Si apre toccando una tappa nella sezione meteo della pagina valigia; legge
/// lo stesso meteo, quindi non fa chiamate.
class TripWeatherScreen extends ConsumerWidget {
  const TripWeatherScreen({
    super.key,
    required this.tripId,
    required this.stopIndex,
  });

  final String tripId;
  final int stopIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tripWeatherNotifierProvider(tripId)).valueOrNull;
    final weather = state is TripWeatherReady ? state.weather : null;
    final stop = weather != null && stopIndex < weather.stops.length
        ? weather.stops[stopIndex]
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(stop?.name ?? 'trips.weather.title'.tr())),
      body: stop == null || stop.forecastDays.isEmpty
          ? DsEmptyState(
              icon: Icons.cloud_outlined,
              title: 'trips.weather.detail_missing'.tr(),
            )
          : _DaysList(stop: stop, fetchedAt: weather!.fetchedAt),
    );
  }
}

class _DaysList extends StatelessWidget {
  const _DaysList({required this.stop, required this.fetchedAt});

  final StopWeather stop;
  final DateTime fetchedAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final locale = context.locale.toString();
    final later = stop.days - stop.forecastDays.length;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        context.spacingSm,
        context.spacingMd,
        context.spacingLg,
      ),
      children: [
        for (final day in stop.forecastDays) ...[
          _DayCard(day: day),
          SizedBox(height: context.spacingMd),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spacingSm),
          child: Text(
            [
              if (later > 0) 'trips.weather.detail_later'.plural(later),
              'trips.weather.detail_footer'.tr(
                args: [DateFormat.Hm(locale).format(fetchedAt)],
              ),
            ].join(' '),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Un giorno: data, icona e minime e massime; sotto pioggia e vento; in fondo
/// le sei fasce in fila.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final DayWeather day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final locale = context.locale.toString();
    final min = day.tempMin;
    final max = day.tempMax;
    final date = DateFormat('EEEE d MMMM', locale).format(day.date);

    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(context.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  weatherCodeIcon(day.code),
                  size: context.iconSizeMd,
                  color: cs.onSurfaceVariant,
                ),
                SizedBox(width: context.spacingMd),
                Expanded(
                  child: Text(
                    toBeginningOfSentenceCase(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.title,
                  ),
                ),
                if (min != null && max != null)
                  Text(
                    'trips.weather.temps'.tr(
                      args: [min.round().toString(), max.round().toString()],
                    ),
                    style: tt.titleMedium?.title,
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(
                top: context.spacingXs,
                left: context.iconSizeMd + context.spacingMd,
              ),
              child: Text(
                _details(),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            if (day.bands.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.spacingMd),
                child: const DsDivider(),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final band in day.bands)
                    Expanded(child: _BandColumn(band: band)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "pioggia 80% · 2,5 mm · vento fino a 33 km/h".
  String _details() {
    final parts = <String>[];
    final probability = day.rainProbability;
    if (probability != null) {
      parts.add('trips.weather.rain_probability'.tr(args: ['$probability']));
    }
    final mm = day.rainMm;
    if (mm != null && mm > 0) {
      parts.add(
        'trips.weather.rain_mm'.tr(args: [NumberFormat('0.#').format(mm)]),
      );
    }
    final wind = day.windMaxKmh;
    if (wind != null) {
      parts.add('trips.weather.wind'.tr(args: [wind.round().toString()]));
    }
    return parts.join(' · ');
  }
}

/// Una fascia: ore, icona, temperatura media e probabilità di pioggia.
class _BandColumn extends StatelessWidget {
  const _BandColumn({required this.band});

  final BandWeather band;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final temp = band.temp;
    final probability = band.rainProbability;
    // La luna per le fasce di notte, dalle 20 alle 4.
    final night = band.startHour >= 20 || band.endHour <= 4;

    return Column(
      children: [
        Text(
          'trips.weather.band'.tr(
            args: ['${band.startHour}', '${band.endHour}'],
          ),
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        SizedBox(height: context.spacingXs),
        Icon(
          weatherCodeIcon(band.code, night: night),
          size: context.iconSizeMd,
          color: cs.onSurfaceVariant,
        ),
        SizedBox(height: context.spacingXs),
        Text(
          temp == null
              ? '–'
              : 'trips.weather.temp'.tr(args: [temp.round().toString()]),
          style: tt.bodyLarge?.strong,
        ),
        Text(
          probability == null
              ? ''
              : 'trips.weather.percent'.tr(args: ['$probability']),
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
