import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../items/providers/item_provider.dart';
import '../../../model/pack_trip_job.dart';
import '../../../model/pack_wait_facts.dart';
import '../../../providers/trip_weather_provider.dart';

/// Le righe dell'attesa con ciò che l'app ha già: la stima meteo del viaggio e
/// i capi della casa. Si aggiornano da sole se un dato arriva mentre si aspetta.
PackWaitFacts watchWaitFacts(
  WidgetRef ref, {
  required String tripId,
  required PackTripJob job,
}) {
  final weather = ref.watch(tripWeatherNotifierProvider(tripId)).valueOrNull;
  final items = ref.watch(itemNotifierProvider(job.houseId)).valueOrNull;
  return packWaitFacts(
    job: job,
    weather: weather is TripWeatherReady ? weather.weather : null,
    itemCount: items?.length,
  );
}
