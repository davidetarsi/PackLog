/// Deterministic packing quota calculator.
///
/// Computes the minimum number of items per clothing type based solely on
/// trip duration and primary vibe. The output is used as the "base layer"
/// for the Smart Packing Recommender before any AI enrichment.
///
/// This class is **pure**: it holds no state, makes no I/O calls and is
/// safe to instantiate on any isolate.
class PackingBlueprintEngine {
  final int tripDurationDays;
  final String? primaryVibe;

  const PackingBlueprintEngine({
    required this.tripDurationDays,
    this.primaryVibe,
  }) : assert(tripDurationDays >= 0, 'tripDurationDays must be ≥ 0');

  /// Returns the minimum packing quotas keyed by clothing type.
  ///
  /// Keys are intentionally lowercase English identifiers so they can be
  /// matched against [ClothingAnalysisResult.category] values and
  /// [TripModel.primaryVibe] strings without locale-dependent transforms.
  ///
  /// ```
  /// underwear_and_socks → days + 1
  /// tops               → (days / 1.5).ceil()
  /// bottoms            → (days / 2.5).ceil()
  /// outerwear          → 1 if < 4 days, else 2
  /// shoes              → 1 if < 4 days, else 2
  /// ```
  Map<String, int> calculateBaseQuotas() {
    return {
      'underwear_and_socks': tripDurationDays + 1,
      'tops': (tripDurationDays / 1.5).ceil(),
      'bottoms': (tripDurationDays / 2.5).ceil(),
      'outerwear': tripDurationDays < 4 ? 1 : 2,
      // Usually 1 comfortable pair + 1 pair suited to the vibe when trip is
      // long enough to justify the extra weight.
      'shoes': tripDurationDays < 4 ? 1 : 2,
    };
  }

  /// Returns the total number of distinct clothing items required.
  int get totalItemCount => calculateBaseQuotas().values.fold(0, (s, v) => s + v);

  @override
  String toString() =>
      'PackingBlueprintEngine(days: $tripDurationDays, vibe: $primaryVibe)';
}
