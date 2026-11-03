/// Ciò che serve a `pack-trip` per generare la valigia, e a mostrare l'attesa.
class PackTripJob {
  const PackTripJob({
    required this.body,
    required this.houseId,
    required this.title,
    required this.nights,
  });

  /// Corpo della richiesta a `pack-trip`.
  final Map<String, dynamic> body;

  /// Casa da cui arrivano i vestiti.
  final String houseId;

  /// Tappe del viaggio, come si leggono nell'attesa ("Islanda e Olanda").
  final String title;

  final int nights;

  /// Id delle attività scelte (catalogo), senza doppioni, nell'ordine delle
  /// tappe: le legge dal corpo della richiesta, destinazione o tappe.
  List<String> get activityIds {
    final trip = body['trip'];
    if (trip is! Map) return const [];
    final sources = [trip, ...?(trip['tappe'] as List?)?.whereType<Map>()];
    return {
      for (final source in sources)
        ...?(source['attivita'] as List?)?.whereType<String>(),
    }.toList();
  }
}
