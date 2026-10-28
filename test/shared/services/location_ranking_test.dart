import 'package:flutter_test/flutter_test.dart';

import 'package:pack_log/shared/model/model.dart';
import 'package:pack_log/shared/services/location_ranking.dart';

LocationSuggestionModel _place(String name, LocationType type) =>
    LocationSuggestionModel(
      placeId: name,
      displayName: name,
      name: name,
      locationType: type,
    );

List<String> _names(List<LocationSuggestionModel> list) => [
  for (final s in list) s.name!,
];

void main() {
  test('il nome esatto viene prima, anche se Geoapify lo dà dopo', () {
    final ranked = rankLocationSuggestions('Milano', [
      _place('Lombardia', LocationType.state),
      _place('Milano Marittima', LocationType.city),
      _place('Milano', LocationType.city),
    ]);
    expect(_names(ranked), ['Milano', 'Milano Marittima', 'Lombardia']);
  });

  test('a pari corrispondenza le città vengono prima delle regioni', () {
    final ranked = rankLocationSuggestions('Ve', [
      _place('Veneto', LocationType.state),
      _place('Venezia', LocationType.city),
      _place('Verona', LocationType.city),
    ]);
    expect(_names(ranked), ['Venezia', 'Verona', 'Veneto']);
  });

  test('una nazione scritta per intero resta prima', () {
    final ranked = rankLocationSuggestions('italia', [
      _place('Italia', LocationType.country),
      _place('Italiano', LocationType.city),
    ]);
    expect(_names(ranked), ['Italia', 'Italiano']);
  });

  test('accenti e maiuscole non contano', () {
    final ranked = rankLocationSuggestions('forli', [
      _place('Forlimpopoli', LocationType.city),
      _place('Forlì', LocationType.city),
    ]);
    expect(_names(ranked), ['Forlì', 'Forlimpopoli']);
  });

  test("a parità resta l'ordine di Geoapify", () {
    final ranked = rankLocationSuggestions('San', [
      _place('Sanremo', LocationType.city),
      _place('Santiago', LocationType.city),
    ]);
    expect(_names(ranked), ['Sanremo', 'Santiago']);
  });
}
