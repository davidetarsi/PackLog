// Nessun import Flutter/Material: il Notifier è testabile come puro Dart.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/trip_date_range.dart';

part 'date_range_selection_provider.g.dart';

/// Notifier ephemero per la selezione di un range di date di viaggio.
///
/// AutoDispose per default: si auto-distrugge quando la schermata è
/// rimossa dal widget tree (nessun memory leak).
///
/// **Regole di selezione:**
/// 1. Nessuna data → tap imposta la partenza.
/// 2. Solo partenza, tap su data > partenza → imposta il ritorno.
/// 3. Solo partenza, tap su data ≤ partenza → reset e nuova partenza.
/// 4. Range completo → reset e nuova partenza.
@riverpod
class DateRangeSelectionNotifier extends _$DateRangeSelectionNotifier {
  @override
  TripDateRange build({DateTime? initialDeparture, DateTime? initialReturn}) {
    return TripDateRange(
      departureDate: initialDeparture != null
          ? _dateOnly(initialDeparture)
          : null,
      returnDate: initialReturn != null ? _dateOnly(initialReturn) : null,
    );
  }

  /// Gestisce il tap su un giorno del calendario.
  void onDaySelected(DateTime date) {
    final tapped = _dateOnly(date);
    final s = state;

    if (s.isComplete) {
      // Regola 4: range completo → reset con nuova partenza
      state = TripDateRange(departureDate: tapped);
      return;
    }

    if (s.departureDate == null) {
      // Regola 1: nessuna data → imposta partenza
      state = TripDateRange(departureDate: tapped);
      return;
    }

    // Solo partenza impostata
    if (tapped.isAfter(s.departureDate!)) {
      // Regola 2: data valida per il ritorno
      state = s.copyWith(returnDate: tapped);
    } else {
      // Regola 3: data ≤ partenza → reset e nuova partenza
      state = TripDateRange(departureDate: tapped);
    }
  }

  /// Azzera completamente la selezione.
  void clear() => state = const TripDateRange();

  /// Normalizza a mezzanotte per eliminare componenti ora/minuto/secondo.
  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
