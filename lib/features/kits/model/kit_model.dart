import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'kit_model.freezed.dart';

/// Un kit: un gruppo logico di oggetti della casa che entrano in valigia
/// sciolti (es. "Sci", "Kit aereo").
@freezed
abstract class KitModel with _$KitModel {
  const factory KitModel({
    required String id,
    required String houseId,
    required String name,

    /// Id delle attività del catalogo per cui il kit entra da solo.
    @Default(<String>[]) List<String> activities,

    /// Id dei mezzi del catalogo (dominio `transport`) per cui entra da solo.
    @Default(<String>[]) List<String> transports,
    @Default(KitLearned()) KitLearned learned,
    @Default(<KitItem>[]) List<KitItem> items,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _KitModel;
}

/// Una riga del kit: un oggetto della casa con le copie che il kit porta.
@freezed
abstract class KitItem with _$KitItem {
  const factory KitItem({
    required String id,
    required String kitId,
    required String itemId,
    @Default(1) int copies,
  }) = _KitItem;
}

/// I collegamenti imparati dall'uso: quante volte l'utente ha detto sì al kit
/// in un viaggio con quell'attività o mezzo (chiave = id), e i rifiuti.
@freezed
abstract class KitLearned with _$KitLearned {
  const KitLearned._();

  const factory KitLearned({
    @Default(<String, int>{}) Map<String, int> yes,
    @Default(<String>[]) List<String> no,
  }) = _KitLearned;

  /// Da `{"yes": {"trekking": 2}, "no": ["mare"]}`; un JSON rotto vale vuoto.
  factory KitLearned.fromJsonString(String? source) {
    if (source == null || source.isEmpty) return const KitLearned();
    try {
      final json = jsonDecode(source);
      if (json is! Map) return const KitLearned();
      final yes = json['yes'];
      final no = json['no'];
      return KitLearned(
        yes: yes is Map
            ? {
                for (final e in yes.entries)
                  if (e.value is num)
                    e.key.toString(): (e.value as num).toInt(),
              }
            : const {},
        no: no is List ? [for (final e in no) e.toString()] : const [],
      );
    } on FormatException {
      return const KitLearned();
    }
  }

  String toJsonString() => jsonEncode({'yes': yes, 'no': no});
}
