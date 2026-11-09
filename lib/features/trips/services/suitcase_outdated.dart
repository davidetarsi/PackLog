import '../model/ai_packing.dart';
import '../model/trip_model.dart';

/// La valigia AI non va più bene: il viaggio (date, tappe, mezzi) è cambiato
/// da quando è stata fatta, il viaggio non è ancora partito e l'utente non ha
/// chiuso l'avviso. Una valigia senza forma (vecchia) non è mai fuori data.
bool suitcaseOutdated(TripModel trip, {required DateTime now}) {
  final result = trip.aiResult;
  final shape = result?.tripShape;
  if (result == null || shape == null || result.changeNoticeDismissed) {
    return false;
  }
  if (!trip.notDepartedAt(now)) return false;
  return shape != AiTripShape.of(trip);
}
