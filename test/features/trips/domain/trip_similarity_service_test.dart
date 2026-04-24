import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/trips/domain/trip_similarity_service.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';

class MockTripRepository extends Mock implements TripRepository {}

TripModel _makeTrip({
  required String id,
  String? vibe,
  List<String> weatherTags = const [],
}) {
  return TripModel(
    id: id,
    name: 'Trip $id',
    primaryVibe: vibe,
    weatherTags: weatherTags,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

void main() {
  late MockTripRepository mockRepo;
  late TripSimilarityService service;

  setUp(() {
    mockRepo = MockTripRepository();
    service = TripSimilarityService(mockRepo);
  });

  group('TripSimilarityService - findSimilarPastTrips', () {
    test('excludes the current trip from results', () async {
      final current = _makeTrip(id: 'current', vibe: 'leisure');
      final other = _makeTrip(id: 'other', vibe: 'leisure');

      when(() => mockRepo.getAllTrips()).thenAnswer(
        (_) async => [current, other],
      );

      final result = await service.findSimilarPastTrips(current);

      expect(result.any((t) => t.id == 'current'), isFalse);
      expect(result.any((t) => t.id == 'other'), isTrue);
    });

    test('returns at most 3 trips (kTopK)', () async {
      final current = _makeTrip(id: 'c', vibe: 'leisure');
      final others = List.generate(
        6,
        (i) => _makeTrip(id: 'trip-$i', vibe: 'leisure'),
      );

      when(() => mockRepo.getAllTrips()).thenAnswer(
        (_) async => [current, ...others],
      );

      final result = await service.findSimilarPastTrips(current);
      expect(result.length, lessThanOrEqualTo(3));
    });

    test('returns empty list when only the current trip exists', () async {
      final current = _makeTrip(id: 'only');

      when(() => mockRepo.getAllTrips()).thenAnswer((_) async => [current]);

      final result = await service.findSimilarPastTrips(current);
      expect(result, isEmpty);
    });

    test('higher score for matching vibe and overlapping weather tags', () async {
      final current = _makeTrip(
        id: 'c',
        vibe: 'beach',
        weatherTags: ['Hot', 'Sunny'],
      );

      // Score = 2 (vibe) + 2 (both weather tags overlap) = 4
      final bestMatch = _makeTrip(
        id: 'best',
        vibe: 'beach',
        weatherTags: ['Hot', 'Sunny'],
      );

      // Score = 2 (vibe) + 0 = 2
      final vibeOnly = _makeTrip(id: 'vibe-only', vibe: 'beach');

      // Score = 0 + 1 = 1
      final weatherOnly = _makeTrip(
        id: 'weather-only',
        weatherTags: ['Sunny'],
      );

      // Score = 0
      final noMatch = _makeTrip(id: 'no-match');

      when(() => mockRepo.getAllTrips()).thenAnswer(
        (_) async => [current, bestMatch, vibeOnly, weatherOnly, noMatch],
      );

      final result = await service.findSimilarPastTrips(current);

      expect(result.isNotEmpty, isTrue);
      // Best match should be ranked first
      expect(result.first.id, equals('best'));
    });

    test('vibe mismatch scores 0 for vibe component', () async {
      final current = _makeTrip(id: 'c', vibe: 'adventure');
      final differentVibe = _makeTrip(id: 'x', vibe: 'business');
      final noVibe = _makeTrip(id: 'y');

      when(() => mockRepo.getAllTrips()).thenAnswer(
        (_) async => [current, differentVibe, noVibe],
      );

      final result = await service.findSimilarPastTrips(current);
      // Neither trip scores for vibe; result should contain both with score 0
      expect(result.length, equals(2));
    });

    test('null vibe does not match a non-null vibe', () async {
      final current = _makeTrip(id: 'c', vibe: null);
      final withVibe = _makeTrip(id: 'v', vibe: 'leisure');

      when(() => mockRepo.getAllTrips()).thenAnswer(
        (_) async => [current, withVibe],
      );

      final result = await service.findSimilarPastTrips(current);
      // Should still return the trip, just with score 0
      expect(result.length, equals(1));
      expect(result.first.id, equals('v'));
    });

    test('weather tag overlap counts individual overlapping tags', () async {
      final current = _makeTrip(
        id: 'c',
        weatherTags: ['Rain', 'Cold', 'Windy'],
      );

      // 2 overlapping tags
      final twoOverlap = _makeTrip(
        id: 'two',
        weatherTags: ['Rain', 'Cold'],
      );

      // 1 overlapping tag
      final oneOverlap = _makeTrip(
        id: 'one',
        weatherTags: ['Rain', 'Sunny'],
      );

      when(() => mockRepo.getAllTrips()).thenAnswer(
        (_) async => [current, twoOverlap, oneOverlap],
      );

      final result = await service.findSimilarPastTrips(current);
      expect(result.first.id, equals('two'),
          reason: '2 overlapping tags should rank higher than 1');
    });
  });
}
