// ignore_for_file: non_abstract_class_inherits_abstract_member, invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../items/model/item_model.dart';
import 'trip_model.dart';

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

/// Livello di un posto. Il JSON usa i valori italiani.
enum AiSlotLevel {
  @JsonValue('importante')
  important,
  @JsonValue('utile')
  useful;

  /// Valore italiano, lo stesso del JSON.
  String get dbValue => switch (this) {
    AiSlotLevel.important => 'importante',
    AiSlotLevel.useful => 'utile',
  };
}

/// Posto della valigia: un oggetto che serve al viaggio e che l'utente può
/// riempire con uno dei suoi. Vive solo dentro [AiPackingResult], mai
/// nell'inventario.
@freezed
class AiSlot with _$AiSlot {
  const AiSlot._();

  const factory AiSlot({
    required String id,

    /// Tipo del catalogo. Bisogni distinti possono chiedere lo stesso tipo.
    required String type,
    required ItemCategory category,
    required AiSlotLevel level,
    required String name,

    /// Copie proposte all'inizio.
    required int copies,

    /// Copie ancora da riempire; 0 = il posto è sparito.
    required int remaining,
    String? reason,
    required String addLabel,

    /// Etichetta grammaticale del pulsante acquisti; assente nei vecchi payload.
    String? boughtLabel,

    /// Quantità aggiunte a questa richiesta, per id oggetto del viaggio.
    @Default(<String, int>{}) Map<String, int> addedItems,
    @Default(false) bool toBuy,
    @Default(false) bool checked,

    /// Tolto dall'utente: il posto non conta più, ma resta nel risultato.
    @Default(false) bool removed,
  }) = _AiSlot;

  bool get isOpen => remaining > 0 && !removed;

  /// Posto aperto che sta in valigia: una proposta da comprare no.
  bool get inSuitcase => isOpen && !(level == AiSlotLevel.useful && toBuy);

  factory AiSlot.fromJson(Map<String, dynamic> json) => _$AiSlotFromJson(json);
}

/// Informazione sul viaggio (lavanderia, bagaglio pieno...) con testi del
/// server.
@freezed
class AiTripNote with _$AiTripNote {
  const factory AiTripNote({
    required String code,
    required String title,
    required String why,
  }) = _AiTripNote;

  factory AiTripNote.fromJson(Map<String, dynamic> json) =>
      _$AiTripNoteFromJson(json);
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

/// Un oggetto della casa con le copie, come lo chiedono i kit (`mancanti`).
@freezed
class KitItemRef with _$KitItemRef {
  const factory KitItemRef({required String itemId, @Default(1) int copies}) =
      _KitItemRef;

  factory KitItemRef.fromJson(Map<String, dynamic> json) =>
      _$KitItemRefFromJson(json);
}

/// Un kit sotto soglia: [taken] oggetti su [total] sono già in valigia, e
/// [missing] sono quelli da aggiungere.
@freezed
class AiKitSuggestion with _$AiKitSuggestion {
  @JsonSerializable(explicitToJson: true)
  const factory AiKitSuggestion({
    required String kitId,
    required int taken,
    required int total,
    @Default(<KitItemRef>[]) List<KitItemRef> missing,
  }) = _AiKitSuggestion;

  factory AiKitSuggestion.fromJson(Map<String, dynamic> json) =>
      _$AiKitSuggestionFromJson(json);
}

/// Un oggetto che la funzione ha messo in valigia perché il kit [kitId] entra
/// da solo nel viaggio.
@freezed
class AiKitAdded with _$AiKitAdded {
  const factory AiKitAdded({
    required String kitId,
    required String itemId,
    @Default(1) int copies,
  }) = _AiKitAdded;

  factory AiKitAdded.fromJson(Map<String, dynamic> json) =>
      _$AiKitAddedFromJson(json);
}

/// Una tappa come era quando la valigia è stata fatta.
@freezed
class AiTripShapeStop with _$AiTripShapeStop {
  const factory AiTripShapeStop({
    required String name,
    @JsonKey(fromJson: _optDateFromJson, toJson: _optDateToJson) DateTime? from,
    @JsonKey(fromJson: _optDateFromJson, toJson: _optDateToJson) DateTime? to,
  }) = _AiTripShapeStop;

  factory AiTripShapeStop.fromJson(Map<String, dynamic> json) =>
      _$AiTripShapeStopFromJson(json);
}

/// La forma del viaggio per cui è fatta la valigia: date, tappe e mezzi.
/// Il nome e il resto non contano: confrontandola con il viaggio di oggi si
/// capisce se la valigia è ancora quella giusta.
@freezed
class AiTripShape with _$AiTripShape {
  const AiTripShape._();

  @JsonSerializable(explicitToJson: true)
  const factory AiTripShape({
    @JsonKey(fromJson: _optDateFromJson, toJson: _optDateToJson)
    DateTime? departure,
    @JsonKey(fromJson: _optDateFromJson, toJson: _optDateToJson)
    DateTime? returnAt,
    @Default(<AiTripShapeStop>[]) List<AiTripShapeStop> stops,
    @Default(<String>[]) List<String> transports,
  }) = _AiTripShape;

  /// La forma di [trip]: la destinazione (se c'è) e poi le tappe, in ordine;
  /// i mezzi senza ordine. Una casa si riconosce dal suo id: il nome si può
  /// cambiare senza cambiare il viaggio.
  factory AiTripShape.of(TripModel trip) {
    final destination = trip.destinationHouseId ?? trip.destinationDisplayName;
    return AiTripShape(
      departure: trip.departureDateTime?.toLocal(),
      returnAt: trip.returnDateTime?.toLocal(),
      stops: [
        if (destination != null) AiTripShapeStop(name: destination),
        for (final leg in trip.legs)
          AiTripShapeStop(
            name: leg.houseId ?? leg.locationDisplayName,
            from: leg.from?.toLocal(),
            to: leg.to?.toLocal(),
          ),
      ],
      transports: [...trip.transports]..sort(),
    );
  }

  factory AiTripShape.fromJson(Map<String, dynamic> json) =>
      _$AiTripShapeFromJson(json);
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

    /// Posti da riempire. `null` = risultato vecchio, senza posti: si
    /// comporta come prima.
    List<AiSlot>? slots,
    @Default(<AiTripNote>[]) List<AiTripNote> notes,

    /// Kit sotto soglia da proporre, nell'ordine della funzione.
    @Default(<AiKitSuggestion>[]) List<AiKitSuggestion> kitSuggestions,

    /// Oggetti dei kit entrati da soli: la valigia li unisce ai capi proposti.
    @Default(<AiKitAdded>[]) List<AiKitAdded> kitAdded,

    /// Risposta alla riga di ogni kit: kitId → "added" | "dismissed".
    @Default(<String, String>{}) Map<String, String> kitAnswers,

    /// Kit già contati per imparare in questo viaggio: un sì non conta due volte.
    @Default(<String>[]) List<String> kitLearnCounted,

    /// Versione del generatore che ha prodotto la valigia (`versione_generatore`
    /// della risposta). `null` = risultato vecchio, senza versione.
    String? generatorVersion,

    /// Il viaggio com'era quando la valigia è stata fatta. `null` = valigia
    /// vecchia: non si sa se il viaggio è cambiato.
    AiTripShape? tripShape,

    /// L'utente ha chiuso l'avviso "hai cambiato il viaggio".
    @Default(false) bool changeNoticeDismissed,
  }) = _AiPackingResult;

  /// Il risultato ha i posti (anche se la lista è vuota).
  bool get hasSlots => slots != null;

  /// Copia con il posto [slotId] cambiato da [change]. Id sconosciuto o
  /// risultato senza posti: nessun cambiamento.
  AiPackingResult withSlot(String slotId, AiSlot Function(AiSlot) change) {
    final current = slots;
    if (current == null) return this;
    return copyWith(
      slots: [
        for (final slot in current) slot.id == slotId ? change(slot) : slot,
      ],
    );
  }

  /// Avvisi non ancora chiusi dall'utente.
  List<AiWarning> get openWarnings => warnings
      .where((warning) => !dismissedWarnings.contains(warning.id))
      .toList();

  factory AiPackingResult.fromJson(Map<String, dynamic> json) =>
      _$AiPackingResultFromJson(json);
}

/// I risultati nuovi trasferiscono "da comprare" per identita' del bisogno.
/// Per i risultati precedenti resta il trasferimento al primo posto dello
/// stesso tipo: quei dati non contengono ancora un'identita' dei requisiti.
AiPackingResult carryToBuy(AiPackingResult? previous, AiPackingResult next) {
  final before = previous?.slots;
  final after = next.slots;
  if (before == null || after == null) return next;

  final remaining = before.where((slot) => slot.isOpen && slot.toBuy).toList();
  if (remaining.isEmpty) return next;
  final legacyTypesUsed = <String>{};
  bool hasNeedId(AiSlot slot) => slot.id.startsWith('need:v1:');

  AiSlot carry(AiSlot slot) {
    if (!slot.isOpen) return slot;
    var index = remaining.indexWhere(
      (old) => hasNeedId(old) && hasNeedId(slot) && old.id == slot.id,
    );
    if (index < 0 && !legacyTypesUsed.contains(slot.type)) {
      index = remaining.indexWhere(
        (old) => old.type == slot.type && (!hasNeedId(old) || !hasNeedId(slot)),
      );
      if (index >= 0) legacyTypesUsed.add(slot.type);
    }
    if (index < 0) return slot;
    remaining.removeAt(index);
    return slot.copyWith(toBuy: true);
  }

  return next.copyWith(slots: [for (final slot in after) carry(slot)]);
}

/// Rigenerando, le risposte alla riga dei kit si azzerano ([next] ne ha
/// già di nuove) ma i kit già contati per imparare restano: un sì dato in
/// questo viaggio non si conta due volte.
AiPackingResult carryKitCounted(
  AiPackingResult? previous,
  AiPackingResult next,
) {
  final counted = previous?.kitLearnCounted;
  if (counted == null || counted.isEmpty) {
    return next.copyWith(kitAnswers: const {});
  }
  return next.copyWith(
    kitLearnCounted: {...counted, ...next.kitLearnCounted}.toList(),
    kitAnswers: const {},
  );
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

String? _optDateToJson(DateTime? value) => value?.toUtc().toIso8601String();

DateTime? _optDateFromJson(String? value) =>
    value == null ? null : DateTime.parse(value).toLocal();
