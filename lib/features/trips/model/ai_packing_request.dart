import '../../luggages/model/luggage_model.dart';
import 'ai_packing.dart';
import 'pack_trip_job.dart';
import 'trip_model.dart';

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
  });

  final TripModel trip;
  final bool isNew;
  final AiPackingSetup setup;
  final PackTripJob job;

  /// Il bagaglio scelto nel foglio, se c'è.
  final LuggageModel? luggage;
}
