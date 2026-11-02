import 'package:easy_localization/easy_localization.dart';

import '../../../core/catalog/catalog_choices.dart';
import 'pack_trip_job.dart';
import 'trip_weather.dart';

/// Le righe col dato vero sotto i tre passi dell'attesa. Un dato che manca
/// lascia la riga a `null`: allora non compare.
class PackWaitFacts {
  const PackWaitFacts({this.weather, this.wardrobe, this.check});

  final String? weather;
  final String? wardrobe;
  final String? check;

  /// La riga del passo [step] (0 meteo, 1 armadio, 2 cosa manca).
  String? forStep(int step) => switch (step) {
    0 => weather,
    1 => wardrobe,
    _ => check,
  };
}

/// Costruisce le righe dai dati che l'app ha già: la stima meteo del viaggio,
/// i capi della casa scelta e la richiesta. Nessun testo viene dal server.
PackWaitFacts packWaitFacts({
  required PackTripJob job,
  required TripWeather? weather,
  required int? itemCount,
}) => PackWaitFacts(
  weather: _weatherLine(weather),
  wardrobe: switch (itemCount) {
    null => null,
    0 => 'trips.ai.wait.fact_wardrobe_empty'.tr(),
    final n => 'trips.ai.wait.fact_wardrobe'.plural(n),
  },
  check: _checkLine(job),
);

String? _weatherLine(TripWeather? weather) {
  if (weather == null) return null;
  final mins = [for (final s in weather.stops) ?s.tempMin];
  final maxs = [for (final s in weather.stops) ?s.tempMax];
  if (mins.isEmpty || maxs.isEmpty) return null;
  final range = 'trips.ai.wait.fact_weather'.tr(
    args: [
      mins.reduce((a, b) => a < b ? a : b).round().toString(),
      maxs.reduce((a, b) => a > b ? a : b).round().toString(),
    ],
  );
  final rainDays = weather.stops
      .fold<double>(0, (sum, s) => sum + (s.rainDays ?? 0))
      .round();
  if (rainDays <= 0) return range;
  return '$range, ${'trips.ai.wait.fact_rain'.plural(rainDays)}';
}

String? _checkLine(PackTripJob job) {
  final labels = [
    for (final id in job.activityIds) etichettaDi('activity', id),
  ];
  final nights = job.nights > 0
      ? 'trips.ai.wait.nights'.plural(job.nights)
      : null;
  final activities = switch (labels.length) {
    0 => null,
    1 => labels.first,
    2 => 'trips.ai.wait.fact_and'.tr(args: labels),
    _ => 'trips.ai.wait.fact_and_more'.tr(args: labels.take(2).toList()),
  };
  if (activities == null) return nights;
  if (nights == null) return activities;
  return 'trips.ai.wait.fact_check'.tr(args: [activities, nights]);
}
