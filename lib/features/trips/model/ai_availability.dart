import '../../houses/model/house_model.dart';
import '../../../shared/widgets/create_sheet.dart';
import 'trip_model.dart';
import 'trip_weather.dart';

/// Se la valigia AI si può chiedere per un viaggio. Chi la chiede spende un
/// credito: un viaggio che non ha un piano valido non lo spende.
sealed class AiAvailability {
  const AiAvailability();
}

/// Il piano del viaggio è pronto: le sue tappe sono quelle del foglio.
class AiAvailable extends AiAvailability {
  const AiAvailable(this.plan);

  final TripWeatherRequest plan;
}

/// Il viaggio non può avere la valigia AI, per [reason].
class AiUnavailable extends AiAvailability {
  const AiUnavailable(this.reason);

  final WeatherUnavailable reason;

  /// Il testo che spiega il motivo: `trips.ai.unavailable.<motivo>`.
  String get messageKey => 'trips.ai.unavailable.${reason.name}';
}

/// La disponibilità di [trip] a partire da [today]. Usa lo stesso piano del
/// meteo: stesse tappe, stessi limiti (60 giorni, 8 tappe, coordinate).
AiAvailability aiAvailabilityOf(
  TripModel trip, {
  required List<HouseModel> houses,
  required DateTime today,
}) {
  final plan = planTripWeather(trip, houses: houses, today: today);
  return switch (plan) {
    TripWeatherRequest() => AiAvailable(plan),
    TripWeatherNotPossible(:final reason) => AiUnavailable(reason),
  };
}

/// La casa da cui prendere i vestiti proposta per [trip]: la principale, a
/// meno che non sia la meta del viaggio. In quel caso la prima altra casa; se
/// non ce n'è un'altra, resta la principale.
HouseModel? proposedPackingHouse(List<HouseModel> houses, TripModel trip) {
  final primary = defaultDestinationHouse(houses);
  if (primary == null) return null;
  if (primary.id != trip.destinationHouseId) return primary;
  return houses.where((house) => house.id != primary.id).firstOrNull ?? primary;
}
