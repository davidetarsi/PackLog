// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:freezed_annotation/freezed_annotation.dart';

part 'suitcase_edit.freezed.dart';

/// Che cosa ha fatto l'utente alla proposta. [dbValue] è il valore nel
/// database (italiano).
enum SuitcaseEditAction {
  added('aggiunto'),
  removed('tolto'),
  copies('copie'),
  suggestionRemoved('suggerimento_tolto'),
  slotFilled('posto_riempito'),
  toBuy('da_comprare');

  const SuitcaseEditAction(this.dbValue);

  final String dbValue;
}

/// Da dove veniva l'oggetto toccato. [dbValue] è il valore nel database.
enum SuitcaseEditOrigin {
  proposal('proposta'),
  slot('posto'),
  kit('kit'),
  user('utente');

  const SuitcaseEditOrigin(this.dbValue);

  final String dbValue;
}

/// Una modifica dell'utente alla valigia proposta. Non porta mai il nome
/// scritto dall'utente: solo la scheda (o tipo e livello di un posto) e il
/// contesto del viaggio.
@freezed
class SuitcaseEdit with _$SuitcaseEdit {
  const factory SuitcaseEdit({
    required String id,
    required String tripId,

    /// SHA-256 di "<viaggio>:<oggetto>" (o "<viaggio>:slot:<posto>").
    required String itemKey,

    /// Utente che ha fatto la modifica (null = nessun utente: non si mette in coda).
    String? userId,
    required DateTime at,
    required SuitcaseEditAction action,
    required SuitcaseEditOrigin origin,
    int? copiesBefore,
    int? copiesAfter,
    @Default(<String, Object?>{}) Map<String, Object?> card,
    @Default(<String, Object?>{}) Map<String, Object?> context,
    String? generatorVersion,
    required bool analysisAllowed,
  }) = _SuitcaseEdit;
}
