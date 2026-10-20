import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_section_title.dart';
import '../../../model/trip_weather.dart';
import '../../../providers/trip_weather_provider.dart';

/// Da qui il vento si nomina nella riga della tappa.
const _kWindyKmh = 40.0;

/// Da qui l'UV si nomina nella riga della tappa (scala OMS: "molto alto").
const _kHighUv = 8.0;

/// Sotto questa massima media la tappa ha l'icona del freddo.
const _kColdMaxC = 3.0;

/// Quota di giorni di pioggia da cui l'icona è la pioggia, e da cui è nuvoloso.
const _kRainyShare = 0.5;
const _kCloudyShare = 0.2;

/// Sezione "Meteo" della pagina valigia: una riga per tappa con temperature e
/// pioggia, e sotto da dove viene il meteo con "Aggiorna".
///
/// Per un viaggio senza meteo possibile (passato, senza date) non mostra
/// niente, nemmeno il titolo.
class PackWeatherSection extends ConsumerWidget {
  const PackWeatherSection({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = tripWeatherNotifierProvider(tripId);
    final weatherAsync = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    final Widget? body = weatherAsync.when(
      // Un viaggio che cambia rilegge la cache: il meteo di prima resta finché
      // non c'è il nuovo, senza tornare al caricamento.
      skipLoadingOnReload: true,
      loading: () => const _WeatherLoading(),
      error: (_, _) => _WeatherFooter(
        text: 'trips.weather.failed'.tr(),
        onRefresh: notifier.refresh,
      ),
      data: (state) => switch (state) {
        TripWeatherReady(:final weather) => _WeatherCard(
          weather: weather,
          onRefresh: notifier.refresh,
        ),
        TripWeatherNotAvailable(:final reason) =>
          reason.isShown
              ? _WeatherFooter(text: 'trips.weather.not_available'.tr())
              : null,
        TripWeatherCapReached() => _WeatherFooter(
          text: 'trips.weather.cap_reached'.tr(),
        ),
        TripWeatherFailed() => _WeatherFooter(
          text: 'trips.weather.failed'.tr(),
          onRefresh: notifier.refresh,
        ),
      },
    );
    if (body == null) return const SizedBox.shrink();

    return Column(
      key: const Key('pack_weather'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [DsSectionTitle('trips.weather.title'.tr()), body],
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.weather, required this.onRefresh});

  final TripWeather weather;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeatherSurface(
          child: Column(
            children: [
              for (var i = 0; i < weather.stops.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _StopRow(stop: weather.stops[i]),
              ],
            ],
          ),
        ),
        _WeatherFooter(text: _sourceLine(context), onRefresh: onRefresh),
      ],
    );
  }

  /// "Previsione · aggiornata alle 10:32", "Media degli ultimi 5 anni · …".
  String _sourceLine(BuildContext context) {
    final source = switch (weather.source) {
      WeatherSource.forecast => 'trips.weather.source_forecast'.tr(),
      WeatherSource.climate => 'trips.weather.source_climate'.plural(
        weather.years ?? 0,
      ),
      null => 'trips.weather.source_mixed'.plural(weather.years ?? 0),
    };
    final locale = context.locale.toString();
    final fetched = weather.fetchedAt;
    final now = DateTime.now();
    final sameDay =
        fetched.year == now.year &&
        fetched.month == now.month &&
        fetched.day == now.day;
    final updated = sameDay
        ? 'trips.weather.updated_at'.tr(
            args: [DateFormat.Hm(locale).format(fetched)],
          )
        : 'trips.weather.updated_on'.tr(
            args: [DateFormat('d MMM', locale).format(fetched)],
          );
    return '$source · $updated';
  }
}

/// Una tappa: icona del tempo, nome e dettagli, minime e massime a destra.
class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop});

  final StopWeather stop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final min = stop.tempMin;
    final max = stop.tempMax;

    return Padding(
      padding: EdgeInsets.all(context.spacingMd),
      child: Row(
        children: [
          Icon(
            _icon(stop),
            size: context.iconSizeMd,
            color: cs.onSurfaceVariant,
          ),
          SizedBox(width: context.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  _details(context),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (min != null && max != null) ...[
            SizedBox(width: context.spacingSm),
            Text(
              'trips.weather.temps'.tr(
                args: [min.round().toString(), max.round().toString()],
              ),
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  /// "29 ott – 1 nov · 2 giorni di pioggia · vento fino a 45 km/h".
  String _details(BuildContext context) {
    final locale = context.locale.toString();
    final format = DateFormat('d MMM', locale);
    final parts = <String>[
      stop.days == 1
          ? format.format(stop.from)
          : '${format.format(stop.from)} – ${format.format(stop.to)}',
    ];
    final rainDays = stop.rainDays;
    if (rainDays != null) {
      parts.add('trips.weather.rain_days'.plural(rainDays.round()));
    }
    final wind = stop.windMaxKmh;
    if (wind != null && wind >= _kWindyKmh) {
      parts.add('trips.weather.wind'.tr(args: [wind.round().toString()]));
    }
    final uv = stop.uvMax;
    if (uv != null && uv >= _kHighUv) parts.add('trips.weather.uv_high'.tr());
    return parts.join(' · ');
  }

  static IconData _icon(StopWeather stop) {
    final max = stop.tempMax;
    if (max != null && max < _kColdMaxC) return Icons.ac_unit;
    final share = (stop.rainDays ?? 0) / stop.days;
    if (share >= _kRainyShare) return Icons.water_drop_outlined;
    if (share >= _kCloudyShare) return Icons.cloud_outlined;
    return Icons.wb_sunny_outlined;
  }
}

class _WeatherLoading extends StatelessWidget {
  const _WeatherLoading();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return _WeatherSurface(
      child: Padding(
        padding: EdgeInsets.all(context.spacingMd),
        child: Row(
          children: [
            SizedBox.square(
              dimension: context.iconSizeMd,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: context.spacingMd),
            Text(
              'trips.weather.loading'.tr(),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riga di testo secondario con "Aggiorna" a destra, se c'è: sotto le tappe
/// dice da dove viene il meteo, da sola è il messaggio discreto al loro posto.
class _WeatherFooter extends StatelessWidget {
  const _WeatherFooter({required this.text, this.onRefresh});

  final String text;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(left: context.spacingSm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          if (onRefresh != null)
            IconButton(
              key: const Key('pack_weather_refresh'),
              tooltip: 'trips.weather.refresh'.tr(),
              onPressed: onRefresh,
              icon: Icon(
                Icons.refresh,
                size: context.iconSizeSm,
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _WeatherSurface extends StatelessWidget {
  const _WeatherSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
