import '../../luggages/model/luggage_model.dart';
import 'ai_packing.dart';
import 'pack_trip_job.dart';
import 'trip_model.dart';
import 'trip_weather.dart';

/// Una richiesta di valigia AI: il viaggio a cui si applica e ciò che serve a
/// generarla. Con [isNew] il viaggio non è ancora salvato: si scrive solo
/// quando la valigia arriva.
class AiPackingRequest {
  const AiPackingRequest({
    required this.trip,
    required this.isNew,
    required this.setup,
    required this.job,
    this.luggage,
    this.tripSource,
    this.weather,
  });

  final TripModel trip;
  final bool isNew;
  final AiPackingSetup setup;
  final PackTripJob job;

  /// Il bagaglio scelto nel foglio, se c'è.
  final LuggageModel? luggage;

  /// Da dove nasce il viaggio nuovo (`'new'` | `'reuse'`), per `trip_created`.
  final String? tripSource;

  /// Il meteo del viaggio dalla copia sul telefono all'avvio, se c'era: serve
  /// solo all'analytics (fasce di temperatura, giorni di pioggia).
  final TripWeather? weather;
}
