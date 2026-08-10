import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_form_validation.dart';

void main() {
  /// Un viaggio valido "di base": nome dalla destinazione e data di partenza.
  /// I test sotto cambiano un pezzo alla volta rispetto a questo.
  String? errorFor({
    String? name = 'Roma',
    bool hasDestination = true,
    DateTime? departure,
    DateTime? returnDate,
  }) => tripFormError(
    name: name,
    hasDestination: hasDestination,
    departureDateTime: departure ?? DateTime(2026, 9, 12),
    returnDateTime: returnDate,
  );

  group('tripFormError — identità del viaggio', () {
    test('senza nome e senza destinazione non è salvabile', () {
      // Un viaggio deve poter essere riconosciuto in lista: senza nessuno dei
      // due non ha nulla da mostrare.
      expect(
        tripFormError(
          name: null,
          hasDestination: false,
          departureDateTime: DateTime(2026, 9, 12),
          returnDateTime: null,
        ),
        'trips.name_or_destination_required',
      );
    });

    test('il solo nome basta, senza destinazione', () {
      // Il weekend da un parente: nessuna geolocalizzazione, ma un'identità sì.
      expect(errorFor(name: 'Da mio fratello', hasDestination: false), isNull);
    });

    test('la sola destinazione basta, senza nome scritto a mano', () {
      // Il nome lo prende dalla destinazione stessa.
      expect(errorFor(name: null, hasDestination: true), isNull);
    });

    test('un nome fatto di soli spazi non conta come nome', () {
      expect(
        errorFor(name: '   ', hasDestination: false),
        'trips.name_or_destination_required',
      );
    });

    test(
      'la mancanza di identità viene segnalata prima della data mancante',
      () {
        // Se manca tutto, il primo messaggio è quello che identifica il
        // viaggio: chiedere la data di un viaggio che non esiste ancora è un
        // ordine innaturale.
        expect(
          tripFormError(
            name: null,
            hasDestination: false,
            departureDateTime: null,
            returnDateTime: null,
          ),
          'trips.name_or_destination_required',
        );
      },
    );
  });

  group('tripFormError — date', () {
    test('senza data di partenza il viaggio non è salvabile', () {
      // Senza partenza il viaggio resta "upcoming" per sempre e si parcheggia
      // in cima alla lista: vedi TripModel.status.
      expect(
        tripFormError(
          name: 'Roma',
          hasDestination: true,
          departureDateTime: null,
          returnDateTime: null,
        ),
        'trips.departure_date_required',
      );
    });

    test('la sola data di partenza basta', () {
      expect(errorFor(returnDate: null), isNull);
    });

    test('un ritorno precedente alla partenza resta un errore', () {
      expect(
        errorFor(
          departure: DateTime(2026, 9, 15),
          returnDate: DateTime(2026, 9, 12),
        ),
        'common.return_before_departure_error',
      );
    });
  });
}
