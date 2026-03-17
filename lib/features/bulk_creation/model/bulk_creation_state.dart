// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:freezed_annotation/freezed_annotation.dart';
import 'draft_item.dart';
import 'user_gender.dart';

part 'bulk_creation_state.freezed.dart';
part 'bulk_creation_state.g.dart';

/// Stato della creazione massiva di item da template.
/// 
/// Gestisce:
/// - Selezione del genere utente (per filtrare item dei template)
/// - Selezione dei template di viaggio
/// - Lista di DraftItem (aggregati dai template e modificabili dall'utente)
/// - Casa e spazio di destinazione
@freezed
class BulkCreationState with _$BulkCreationState {
  const BulkCreationState._();

  factory BulkCreationState({
    /// Genere dell'utente per filtrare i template
    @Default(UserGender.neutral) UserGender gender,

    /// Chiavi dei template selezionati
    @Default({}) Set<String> selectedTemplateKeys,

    /// Item derivati dai template selezionati (rigenerati automaticamente)
    @Default([]) List<DraftItem> templateDerivedItems,

    /// Item aggiunti manualmente dall'utente (mai toccati dalla logica dei template)
    @Default([]) List<DraftItem> manualItems,

    /// ID della casa di destinazione (dove verranno creati gli item reali)
    String? targetHouseId,

    /// ID dello spazio di destinazione (opzionale)
    String? targetSpaceId,
  }) = _BulkCreationState;

  /// Restituisce tutti gli item da visualizzare (template + manuali).
  List<DraftItem> get allItems => [...templateDerivedItems, ...manualItems];

  /// Verifica se ci sono item da salvare.
  bool get hasItems => allItems.isNotEmpty;

  /// Conta il numero totale di item (sommando le quantità).
  int get totalItemsCount {
    return allItems.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  factory BulkCreationState.fromJson(Map<String, dynamic> json) =>
      _$BulkCreationStateFromJson(json);
}
