import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';

void main() {
  group('TripLeg', () {
    test('serializza in snake_case, come il resto del payload remoto', () {
      final leg = TripLeg(
        id: 'leg-1',
        locationDisplayName: 'Firenze, Italia',
        from: DateTime.utc(2026, 9, 13),
        to: DateTime.utc(2026, 9, 14),
      );

      final json = leg.toJson();

      expect(json['id'], 'leg-1');
      expect(json['location_display_name'], 'Firenze, Italia');
      expect(json['from'], '2026-09-13T00:00:00.000Z');
      expect(json['to'], '2026-09-14T00:00:00.000Z');
    });

    test('le date attraversano il round-trip senza spostarsi nel tempo', () {
      // Il fuso è la parte che si rompe in silenzio: la data esce in UTC e
      // rientra in locale, ma deve restare lo stesso istante.
      final leg = TripLeg(
        id: 'leg-2',
        locationDisplayName: 'Bologna',
        from: DateTime(2026, 9, 13, 8, 30),
      );

      final restored = TripLeg.fromJson(leg.toJson());

      expect(restored.from!.isAtSameMomentAs(leg.from!), isTrue);
      expect(restored.to, isNull);
    });

    test('coordinate, paese e casa attraversano il round-trip', () {
      final leg = TripLeg(
        id: 'leg-4',
        locationDisplayName: 'Sintra, Portogallo',
        lat: 38.7978,
        lon: -9.3881,
        country: 'Portogallo',
        houseId: 'casa-1',
      );

      final json = leg.toJson();

      expect(json['lat'], 38.7978);
      expect(json['lon'], -9.3881);
      expect(json['country'], 'Portogallo');
      expect(json['house_id'], 'casa-1');
      expect(TripLeg.fromJson(json), leg);
    });

    test('senza coordinate, paese e casa i campi nuovi restano null', () {
      final leg = TripLeg.fromJson({
        'id': 'leg-5',
        'location_display_name': 'Siena',
      });

      expect(leg.lat, isNull);
      expect(leg.lon, isNull);
      expect(leg.country, isNull);
      expect(leg.houseId, isNull);
    });

    test('un JSON vecchio, con solo le quattro chiavi storiche, si legge', () {
      final leg = TripLeg.fromJson({
        'id': 'leg-6',
        'location_display_name': 'Bologna, Italia',
        'from': '2026-09-13T00:00:00.000Z',
        'to': '2026-09-14T00:00:00.000Z',
      });

      expect(leg.locationDisplayName, 'Bologna, Italia');
      expect(leg.from, isNotNull);
      expect(leg.to, isNotNull);
      expect(leg.houseId, isNull);
    });

    test('una tappa senza date è valida', () {
      final json = {'id': 'leg-3', 'location_display_name': 'Siena'};

      final leg = TripLeg.fromJson(json);

      expect(leg.locationDisplayName, 'Siena');
      expect(leg.from, isNull);
      expect(leg.to, isNull);
    });
  });
}
