// ignore_for_file: non_abstract_class_inherits_abstract_member, invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_packing.freezed.dart';
part 'ai_packing.g.dart';

/// Risposte date per una singola tappa.
@freezed
class AiStopAnswers with _$AiStopAnswers {
  const AiStopAnswers._();

  const factory AiStopAnswers({
    /// Id delle attività (dominio `activity` del catalogo). Si conservano anche
    /// quelli che il catalogo non conosce più: il viaggio non perde nulla.
    @Default(<String>[]) List<String> activities,

    /// Id dell'alloggio (dominio `stay` del catalogo).
    String? stay,
    @Default(false) bool washer,
  }) = _AiStopAnswers;

  /// Nessuna attività, nessun alloggio, lavatrice spenta.
  bool get isUntouched => activities.isEmpty && stay == null && !washer;

  /// Manca almeno un'attività o l'alloggio.
  bool get isIncomplete => activities.isEmpty || stay == null;

  factory AiStopAnswers.fromJson(Map<String, dynamic> json) =>
      _$AiStopAnswersFromJson(json);
}

/// Scelte della valigia AI: casa, bagaglio e risposte per tappa. La chiave di
/// [stops] è lo `stopKey` della tappa.
@freezed
class AiPackingSetup with _$AiPackingSetup {
  @JsonSerializable(explicitToJson: true)
  const factory AiPackingSetup({
    String? houseId,
    String? luggageId,
    @Default(<String, AiStopAnswers>{}) Map<String, AiStopAnswers> stops,
  }) = _AiPackingSetup;

  factory AiPackingSetup.fromJson(Map<String, dynamic> json) =>
      _$AiPackingSetupFromJson(json);
}

/// Motivo di un oggetto proposto, in una frase.
@freezed
class AiReason with _$AiReason {
  const factory AiReason({
    required String code,
    required String label,
    required String sentence,
  }) = _AiReason;

  factory AiReason.fromJson(Map<String, dynamic> json) =>
      _$AiReasonFromJson(json);
}

/// Oggetto proposto dalla valigia AI.
@freezed
class AiPackedItem with _$AiPackedItem {
  @JsonSerializable(explicitToJson: true)
  const factory AiPackedItem({
    required String itemId,
    required int quantity,
    @Default(false) bool inDeparture,
    required AiReason reason,
  }) = _AiPackedItem;

  factory AiPackedItem.fromJson(Map<String, dynamic> json) =>
      _$AiPackedItemFromJson(json);
}

/// Livello di un avviso. Il JSON usa i valori italiani.
enum AiWarningLevel {
  @JsonValue('importante')
  important,
  @JsonValue('utile')
  useful,
}

/// Avviso generato dalla valigia AI. [search] è una query facoltativa per
/// cercare il pezzo mancante.
@freezed
class AiWarning with _$AiWarning {
  const factory AiWarning({
    required String id,
    required String code,
    required AiWarningLevel level,
    required String title,
    required String why,
    String? search,
  }) = _AiWarning;

  factory AiWarning.fromJson(Map<String, dynamic> json) =>
      _$AiWarningFromJson(json);
}

/// Punto del riepilogo "perché": titolo, frasi e oggetti collegati.
@freezed
class AiReasonPoint with _$AiReasonPoint {
  const factory AiReasonPoint({
    required String code,
    required String title,
    @Default(<String>[]) List<String> sentences,
    @Default(<String>[]) List<String> items,
  }) = _AiReasonPoint;

  factory AiReasonPoint.fromJson(Map<String, dynamic> json) =>
      _$AiReasonPointFromJson(json);
}

/// Risultato della generazione, salvato con il viaggio.
@freezed
class AiPackingResult with _$AiPackingResult {
  const AiPackingResult._();

  @JsonSerializable(explicitToJson: true)
  const factory AiPackingResult({
    @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
    required DateTime generatedAt,
    required String houseId,
    @Default(<AiPackedItem>[]) List<AiPackedItem> proposal,
    @JsonKey(fromJson: _warningsFromJson)
    @Default(<AiWarning>[])
    List<AiWarning> warnings,
    @Default(<AiReasonPoint>[]) List<AiReasonPoint> reasons,
    @Default(<String>[]) List<String> dismissedWarnings,
  }) = _AiPackingResult;

  /// Avvisi non ancora chiusi dall'utente.
  List<AiWarning> get openWarnings => warnings
      .where((warning) => !dismissedWarnings.contains(warning.id))
      .toList();

  factory AiPackingResult.fromJson(Map<String, dynamic> json) =>
      _$AiPackingResultFromJson(json);
}

/// Avvisi con un livello sconosciuto si scartano prima del parsing.
const _knownWarningLevels = {'importante', 'utile'};

List<AiWarning> _warningsFromJson(List<dynamic>? raw) {
  if (raw == null) return const [];
  return [
    for (final value in raw)
      if (value is Map<String, dynamic> &&
          _knownWarningLevels.contains(value['level']))
        AiWarning.fromJson(value),
  ];
}

/// Le date escono in UTC e rientrano in locale, come in `trip_leg.dart`.
String _dateToJson(DateTime value) => value.toUtc().toIso8601String();

DateTime _dateFromJson(String value) => DateTime.parse(value).toLocal();
