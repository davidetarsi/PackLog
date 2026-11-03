import '../../../core/catalog/catalog_store.dart';
import '../model/kit_model.dart';
import '../model/kit_uses.dart';

/// Le pillole d'uso scelte per un kit mentre si scrive: quelle toccate
/// dall'utente, quelle che PackLog ha riconosciuto dal nome e quelle
/// riconosciute che l'utente ha tolto (il nome riscritto non le rimette).
///
/// Il riconoscimento dal nome avviene solo nel kit nuovo: il collegamento
/// poi si salva nel kit, e la valigia non indovina più niente dal nome.
class KitUsesChoice {
  const KitUsesChoice({
    this.chosen = const {},
    this.guessed = const {},
    this.dismissed = const {},
  });

  /// Gli usi già nel kit.
  factory KitUsesChoice.of(KitModel kit) =>
      KitUsesChoice(chosen: {...kit.activities, ...kit.transports});

  /// Toccate dall'utente o già nel kit.
  final Set<String> chosen;

  /// Riconosciute dal nome.
  final Set<String> guessed;

  /// Riconosciute e tolte dall'utente.
  final Set<String> dismissed;

  /// Le riconosciute ancora in piedi: quelle della frase "l'ho scelto io".
  Set<String> get proposed => guessed.difference(dismissed).difference(chosen);

  Set<String> get selected => {...chosen, ...proposed};

  List<String> get activities => [
    for (final id in selected)
      if (!_isTransport(id)) id,
  ];

  List<String> get transports => [
    for (final id in selected)
      if (_isTransport(id)) id,
  ];

  KitUsesChoice withName(String name) {
    final uses = usesFromName(name, CatalogStore.current);
    return KitUsesChoice(
      chosen: chosen,
      guessed: {...uses.activities, ...uses.transports},
      dismissed: dismissed,
    );
  }

  KitUsesChoice toggle(String id) {
    if (selected.contains(id)) {
      return KitUsesChoice(
        chosen: {...chosen}..remove(id),
        guessed: guessed,
        dismissed: guessed.contains(id) ? {...dismissed, id} : dismissed,
      );
    }
    return KitUsesChoice(
      chosen: {...chosen, id},
      guessed: guessed,
      dismissed: {...dismissed}..remove(id),
    );
  }

  static bool _isTransport(String id) =>
      CatalogStore.current.find('transport', id) != null;
}
