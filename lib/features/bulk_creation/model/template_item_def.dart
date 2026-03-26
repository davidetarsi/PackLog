import '../../items/model/item_model.dart';
import 'user_gender.dart';

/// Definizione di un item all'interno di un template di viaggio.
/// 
/// Rappresenta un oggetto "tipico" per un certo tipo di viaggio,
/// con la possibilità di filtrarlo per genere dell'utente.
class TemplateItemDef {
  /// Nome dell'oggetto
  final String name;

  /// Categoria dell'oggetto
  final ItemCategory category;

  /// Quantità di default suggerita
  final int defaultQuantity;

  /// Generi a cui questo oggetto si applica.
  /// 
  /// Se `null`, l'oggetto è universale (si applica a tutti i generi).
  /// Se specificato, l'oggetto verrà incluso solo per i generi indicati.
  /// 
  /// Esempi:
  /// - `[UserGender.female]`: Solo per utenti femminili (es. Bikini)
  /// - `[UserGender.male]`: Solo per utenti maschili (es. Rasoio elettrico)
  /// - `null`: Per tutti (es. Spazzolino da denti)
  final List<UserGender>? targetGenders;

  const TemplateItemDef({
    required this.name,
    required this.category,
    this.defaultQuantity = 1,
    this.targetGenders,
  });

  /// Verifica se questo item è applicabile al genere specificato.
  bool isApplicableForGender(UserGender gender) {
    // Se targetGenders è null, l'item è universale
    if (targetGenders == null) {
      return true;
    }

    // Se il genere è neutral, include sempre l'item
    if (gender == UserGender.neutral) {
      return true;
    }

    // Altrimenti, verifica che il genere sia nella lista
    return targetGenders!.contains(gender);
  }
}
