import '../../../core/catalog/catalog_store.dart';
import '../../items/model/item_model.dart';
import '../../kits/helpers/kit_trip_plan.dart';
import '../../kits/model/kit_model.dart';
import '../../kits/repositories/kit_repository.dart';
import '../model/ai_packing.dart';
import '../model/trip_model.dart';

/// La riga del kit da mostrare in valigia: il kit, quanti oggetti sono già
/// dentro e cosa servirebbe per completarlo.
class KitRowState {
  const KitRowState({
    required this.kit,
    required this.taken,
    required this.total,
    required this.plan,
    required this.missing,
  });

  final KitModel kit;
  final int taken;
  final int total;

  /// Cosa cambia nel viaggio se si aggiungono i mancanti.
  final KitTripPlan plan;

  /// I mancanti con il nome e le copie che entrerebbero, nell'ordine del kit.
  final List<({String name, int copies})> missing;
}

/// La riga da mostrare, o `null`: la prima proposta senza risposta il cui kit
/// esiste ancora e ha almeno un mancante che la casa ha ancora. Un mancante
/// cancellato dalla casa si salta; le copie sono quelle del kit (il massimo
/// con quelle del viaggio, mai la somma, mai più di quelle della casa).
KitRowState? pickKitRow({
  required TripModel trip,
  required List<KitModel> kits,
  required List<ItemModel> houseItems,
}) {
  final result = trip.aiResult;
  if (result == null) return null;
  final byId = {for (final item in houseItems) item.id: item};
  for (final suggestion in result.kitSuggestions) {
    if (result.kitAnswers.containsKey(suggestion.kitId)) continue;
    final kit = kits.where((k) => k.id == suggestion.kitId).firstOrNull;
    if (kit == null) continue;
    final plan = planKitForTrip(
      kit: kit.copyWith(
        items: [
          for (final ref in suggestion.missing)
            KitItem(
              id: ref.itemId,
              kitId: kit.id,
              itemId: ref.itemId,
              copies: ref.copies,
            ),
        ],
      ),
      houseItems: houseItems,
      trip: trip,
    );
    final missing = [
      for (final item in plan.toAdd) (name: item.name, copies: item.quantity),
      for (final entry in plan.raised.entries)
        if (byId[entry.key] != null)
          (name: byId[entry.key]!.name, copies: entry.value),
    ];
    if (missing.isEmpty) continue;
    return KitRowState(
      kit: kit,
      taken: suggestion.taken,
      total: suggestion.total,
      plan: plan,
      missing: missing,
    );
  }
  return null;
}

/// Le attività di tutte le tappe (senza doppioni) e i mezzi del viaggio: gli
/// usi con cui il viaggio può imparare un kit.
List<String> tripUses(TripModel trip) => {
  for (final stop in trip.aiSetup?.stops.values ?? const <AiStopAnswers>[])
    ...stop.activities,
  ...trip.transports,
}.toList();

/// Il primo uso del viaggio che si può proporre di imparare per [kit]: ha
/// almeno [kKitLearnedAfterYes] sì, non è già nel kit e non è stato rifiutato.
String? learnCandidate(KitModel kit, List<String> uses) {
  for (final use in uses) {
    if ((kit.learned.yes[use] ?? 0) >= kKitLearnedAfterYes &&
        !kit.activities.contains(use) &&
        !kit.transports.contains(use) &&
        !kit.learned.no.contains(use)) {
      return use;
    }
  }
  return null;
}

/// Il dominio del catalogo di un uso: i mezzi stanno in `transport`.
String useDomain(String use) =>
    CatalogStore.current.find('transport', use) != null
    ? 'transport'
    : 'activity';

/// Il viaggio dopo "Aggiungili in valigia": gli oggetti del [plan] dentro, la
/// risposta salvata e il kit contato (se [counted]) per non contarlo due
/// volte se la valigia si rigenera.
TripModel applyKitAdded(
  TripModel trip,
  KitRowState row, {
  required bool counted,
}) {
  final withItems = applyKitTripPlan(trip, row.plan);
  return _answered(withItems, row.kit.id, 'added', counted: counted);
}

/// Il viaggio dopo la X: la risposta salvata, niente altro.
TripModel applyKitDismissed(TripModel trip, String kitId) => _answered(
  trip.copyWith(updatedAt: DateTime.now()),
  kitId,
  'dismissed',
  counted: false,
);

TripModel _answered(
  TripModel trip,
  String kitId,
  String answer, {
  required bool counted,
}) {
  final result = trip.aiResult!;
  return trip.copyWith(
    aiResult: result.copyWith(
      kitAnswers: {...result.kitAnswers, kitId: answer},
      kitLearnCounted: counted
          ? [...result.kitLearnCounted, kitId]
          : result.kitLearnCounted,
    ),
  );
}
