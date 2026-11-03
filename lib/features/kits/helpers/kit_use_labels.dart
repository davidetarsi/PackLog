import '../../../core/catalog/catalog_choices.dart';
import '../model/kit_model.dart';

/// Le etichette delle pillole d'uso di un kit: prima le attività, poi i mezzi,
/// nella lingua attiva del catalogo.
List<String> kitUseLabels(KitModel kit) => [
  for (final id in kit.activities) etichettaDi('activity', id),
  for (final id in kit.transports) etichettaDi('transport', id),
];
