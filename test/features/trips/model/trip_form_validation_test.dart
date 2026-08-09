import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_form_validation.dart';

void main() {
  group('tripFormError', () {
    test('senza data di partenza il viaggio non è salvabile', () {
      // Senza partenza il viaggio resta "upcoming" per sempre e si parcheggia
      // in cima alla lista: vedi TripModel.status.
      expect(
        tripFormError(departureDateTime: null, returnDateTime: null),
        'trips.departure_date_required',
      );
    });

    test('la sola data di partenza basta', () {
      expect(
        tripFormError(
          departureDateTime: DateTime(2026, 9, 12),
          returnDateTime: null,
        ),
        isNull,
      );
    });

    test('la destinazione non è più obbligatoria', () {
      // Il weekend da un parente non ha bisogno di essere geolocalizzato.
      expect(
        tripFormError(
          departureDateTime: DateTime(2026, 9, 12),
          returnDateTime: DateTime(2026, 9, 15),
        ),
        isNull,
      );
    });

    test('un ritorno precedente alla partenza resta un errore', () {
      // Il controllo esisteva già, ma girava protetto da un null-check su
      // entrambe le date: con il ritorno facoltativo va riscritto.
      expect(
        tripFormError(
          departureDateTime: DateTime(2026, 9, 15),
          returnDateTime: DateTime(2026, 9, 12),
        ),
        'common.return_before_departure_error',
      );
    });
  });
}
