/// Maps WMO Weather Interpretation Codes (0–99) to simplified inventory tags.
///
/// Reference: https://open-meteo.com/en/docs#weathervariables
/// The returned tags are used to populate [TripModel.weatherTags] and
/// downstream to drive AI-assisted packing suggestions.
///
/// Returns a new list every call (never mutates a constant).
List<String> mapWmoCodeToTags(int wmoCode) {
  return switch (wmoCode) {
    // ── Clear / Partly cloudy ─────────────────────────────────────────────
    0 => ['Sunny'],
    1 => ['Sunny'],
    2 => ['Cloudy'],
    3 => ['Cloudy'],

    // ── Fog ───────────────────────────────────────────────────────────────
    45 || 48 => ['Cloudy'],

    // ── Drizzle ───────────────────────────────────────────────────────────
    51 || 53 || 55 => ['Rain'],
    56 || 57 => ['Rain', 'Cold'],

    // ── Rain ──────────────────────────────────────────────────────────────
    61 || 63 || 65 => ['Rain'],
    66 || 67 => ['Rain', 'Cold'],

    // ── Snow ──────────────────────────────────────────────────────────────
    71 || 73 || 75 || 77 => ['Snow', 'Cold'],

    // ── Rain showers ──────────────────────────────────────────────────────
    80 || 81 || 82 => ['Rain'],

    // ── Snow showers ──────────────────────────────────────────────────────
    85 || 86 => ['Snow', 'Cold'],

    // ── Thunderstorm ──────────────────────────────────────────────────────
    95 || 96 || 99 => ['Rain', 'Windy'],

    // ── Unknown / future codes ────────────────────────────────────────────
    _ => ['Cloudy'],
  };
}
