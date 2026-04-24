import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/trip_model.dart';
import '../repositories/trip_repository.dart';

part 'trip_similarity_service.g.dart';

/// Maximum number of similar trips returned by [findSimilarPastTrips].
const _kTopK = 3;

/// Finds past trips that are contextually similar to a given trip for use
/// as few-shot context when calling the GPT packing recommendation later.
///
/// **Scoring heuristic** (higher = more similar):
/// - +2 if [primaryVibe] matches exactly.
/// - +1 for each overlapping tag in [weatherTags].
///
/// Only completed or upcoming trips that are *not* the current trip are
/// considered. Trips with score 0 are included if fewer than [_kTopK] others
/// are available, ensuring the caller always receives a non-empty list when
/// any past trips exist.
class TripSimilarityService {
  final TripRepository _repository;

  const TripSimilarityService(this._repository);

  /// Returns up to [_kTopK] past [TripModel]s sorted by similarity score
  /// (descending) relative to [currentTrip].
  ///
  /// The [currentTrip] is excluded from results even if it is already saved
  /// in the database (matched by id).
  Future<List<TripModel>> findSimilarPastTrips(TripModel currentTrip) async {
    final allTrips = await _repository.getAllTrips();

    final scored = allTrips
        .where((t) => t.id != currentTrip.id)
        .map((t) => (trip: t, score: _score(currentTrip, t)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(_kTopK).map((e) => e.trip).toList();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Computes a non-negative similarity score between [reference] and [candidate].
  int _score(TripModel reference, TripModel candidate) {
    var score = 0;

    if (reference.primaryVibe != null &&
        reference.primaryVibe == candidate.primaryVibe) {
      score += 2;
    }

    if (reference.weatherTags.isNotEmpty && candidate.weatherTags.isNotEmpty) {
      final refSet = reference.weatherTags.toSet();
      score += candidate.weatherTags.where(refSet.contains).length;
    }

    return score;
  }
}

@riverpod
TripSimilarityService tripSimilarityService(Ref ref) {
  return TripSimilarityService(ref.watch(tripRepositoryProvider));
}
