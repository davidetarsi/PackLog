// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:freezed_annotation/freezed_annotation.dart';
import '../../items/model/item_model.dart';

part 'draft_item.freezed.dart';
part 'draft_item.g.dart';

/// Rappresenta un item temporaneo prima del salvataggio nel database.
/// 
/// Utilizzato durante il flusso di creazione massiva per permettere
/// all'utente di modificare nome, categoria e quantità prima di confermare.
@freezed
class DraftItem with _$DraftItem {
  const DraftItem._();

  factory DraftItem({
    /// ID univoco (UUID) per identificare il draft
    required String id,

    /// Nome dell'oggetto
    required String name,

    /// Categoria dell'oggetto
    required ItemCategory category,

    /// Quantità (default: 1, minimo: 1)
    @Default(1) int quantity,

    /// Indice di inserimento per preservare l'ordine originale nella UI
    /// (previene che gli item saltino di posizione quando vengono modificati)
    @Default(0) int insertionIndex,
  }) = _DraftItem;

  /// Restituisce il nome normalizzato per il confronto e il merge.
  /// 
  /// Usato per identificare item duplicati durante l'aggregazione dei template.
  String get normalizedName => name.toLowerCase().trim();

  factory DraftItem.fromJson(Map<String, dynamic> json) =>
      _$DraftItemFromJson(json);
}
