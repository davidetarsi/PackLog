import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/services/suitcase_outdated.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';

final _now = DateTime(2026, 11, 8);
final _departure = DateTime(2026, 12, 1, 8);

TripModel _trip({
  String name = 'Viaggio',
  DateTime? departure,
  DateTime? returnAt,
  List<TripLeg> legs = const [],
  List<String> transports = const [],
  AiPackingResult? aiResult,
}) => TripModel(
  id: 't1',
  name: name,
  departureDateTime: departure ?? _departure,
  returnDateTime: returnAt ?? DateTime(2026, 12, 10),
  legs: legs,
  transports: transports,
  aiResult: aiResult,
  createdAt: _now,
  updatedAt: _now,
);

AiPackingResult _resultFor(TripModel trip, {bool dismissed = false}) =>
    AiPackingResult(
      generatedAt: _now,
      houseId: 'h1',
      tripShape: AiTripShape.of(trip),
      changeNoticeDismissed: dismissed,
    );

TripModel _saved({bool dismissed = false}) {
  final base = _trip(
    legs: [TripLeg(id: 'l1', locationDisplayName: 'Oslo')],
    transports: ['aereo', 'treno'],
  );
  return base.copyWith(aiResult: _resultFor(base, dismissed: dismissed));
}

void main() {
  test('not_outdated_when_unchanged', () {
    expect(suitcaseOutdated(_saved(), now: _now), isFalse);
  });

  test('outdated_when_dates_change', () {
    final trip = _saved().copyWith(returnDateTime: DateTime(2026, 12, 12));
    expect(suitcaseOutdated(trip, now: _now), isTrue);
  });

  test('outdated_when_stops_change', () {
    final trip = _saved().copyWith(
      legs: [TripLeg(id: 'l1', locationDisplayName: 'Bergen')],
    );
    expect(suitcaseOutdated(trip, now: _now), isTrue);
  });

  test('outdated_when_transports_change', () {
    final trip = _saved().copyWith(transports: ['aereo']);
    expect(suitcaseOutdated(trip, now: _now), isTrue);
  });

  test('not_outdated_when_only_name_changes', () {
    final trip = _saved().copyWith(name: 'Altro nome');
    expect(suitcaseOutdated(trip, now: _now), isFalse);
  });

  test('not_outdated_without_shape', () {
    final trip = _saved().copyWith(
      aiResult: AiPackingResult(generatedAt: _now, houseId: 'h1'),
      transports: ['aereo'],
    );
    expect(suitcaseOutdated(trip, now: _now), isFalse);
  });

  test('not_outdated_when_dismissed', () {
    final trip = _saved(dismissed: true).copyWith(transports: ['aereo']);
    expect(suitcaseOutdated(trip, now: _now), isFalse);
  });

  test('not_outdated_after_departure', () {
    final trip = _saved().copyWith(transports: ['aereo']);
    expect(suitcaseOutdated(trip, now: _departure), isFalse);
    expect(
      suitcaseOutdated(trip, now: _departure.add(const Duration(days: 1))),
      isFalse,
    );
  });

  test('outdated_without_departure_counts_as_not_departed', () {
    final base = _saved();
    final trip = base.copyWith(departureDateTime: null, transports: ['aereo']);
    expect(suitcaseOutdated(trip, now: DateTime(2030)), isTrue);
  });

  test('outdated_when_destination_changes', () {
    final base = _saved().copyWith(
      destinationLocation: LocationSuggestionModel(
        placeId: 'p1',
        displayName: 'Oslo, Norvegia',
        city: 'Oslo',
        country: 'Norvegia',
      ),
    );
    final withShape = base.copyWith(aiResult: _resultFor(base));
    expect(suitcaseOutdated(withShape, now: _now), isFalse);
    final moved = withShape.copyWith(
      destinationLocation: LocationSuggestionModel(
        placeId: 'p2',
        displayName: 'Bergen, Norvegia',
        city: 'Bergen',
        country: 'Norvegia',
      ),
    );
    expect(suitcaseOutdated(moved, now: _now), isTrue);
  });

  test('old_json_without_new_fields_reads_and_is_not_outdated', () {
    final old = AiPackingResult.fromJson({
      'generatedAt': DateTime(2026, 10).toUtc().toIso8601String(),
      'houseId': 'h1',
    });
    expect(old.tripShape, isNull);
    expect(old.changeNoticeDismissed, isFalse);
    final trip = _saved().copyWith(aiResult: old, transports: ['aereo']);
    expect(suitcaseOutdated(trip, now: _now), isFalse);
  });

  test('json_round_trip_keeps_shape', () {
    final result = _saved().aiResult!;
    final back = AiPackingResult.fromJson(
      jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
    );
    expect(back.tripShape, result.tripShape);
    expect(back.changeNoticeDismissed, isFalse);
    expect(
      suitcaseOutdated(_saved().copyWith(aiResult: back), now: _now),
      isFalse,
    );
  });

  test('json_uses_camel_case_return_at', () {
    final json = _saved().aiResult!.tripShape!.toJson();
    expect(json.containsKey('returnAt'), isTrue);
    expect(json.containsKey('return_at'), isFalse);
    expect(AiTripShape.fromJson(json), _saved().aiResult!.tripShape);
  });

  test('house_rename_does_not_make_suitcase_outdated', () {
    LocationSuggestionModel casa(String nome) => LocationSuggestionModel(
      placeId: 'house_h1',
      displayName: nome,
      city: nome,
    );
    final base = _saved().copyWith(
      destinationHouseId: 'h1',
      destinationLocation: casa('Casa Milano'),
      legs: [
        TripLeg(id: 'l1', locationDisplayName: 'Casa al mare', houseId: 'h2'),
      ],
    );
    final withShape = base.copyWith(aiResult: _resultFor(base));
    final renamed = withShape.copyWith(
      destinationLocation: casa('Casa di Milano'),
      legs: [TripLeg(id: 'l1', locationDisplayName: 'Mare', houseId: 'h2')],
    );
    expect(suitcaseOutdated(renamed, now: _now), isFalse);
    final other = withShape.copyWith(destinationHouseId: 'h3');
    expect(suitcaseOutdated(other, now: _now), isTrue);
  });
}
