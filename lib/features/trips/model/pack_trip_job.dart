import '../../luggages/model/luggage_model.dart';

/// Ciò che serve a `pack-trip` per generare la valigia, e a mostrare l'attesa.
class PackTripJob {
  const PackTripJob({
    required this.body,
    required this.houseId,
    required this.title,
    required this.nights,
    this.isRegeneration = false,
    this.setupChanged = const [],
    this.luggage,
  });

  /// Corpo della richiesta a `pack-trip`.
  final Map<String, dynamic> body;

  /// Casa da cui arrivano i vestiti.
  final String houseId;

  /// Tappe del viaggio, come si leggono nell'attesa ("Islanda e Olanda").
  final String title;

  final int nights;

  /// Il viaggio aveva già una valigia AI: questa la sostituisce.
  final bool isRegeneration;

  /// Risposte del foglio cambiate dalla generazione precedente (vedi
  /// `setupChangedFields`), per l'analytics.
  final List<String> setupChanged;

  /// Il bagaglio scelto nel foglio, per il contesto dell'analytics.
  final LuggageModel? luggage;

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
