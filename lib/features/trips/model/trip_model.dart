// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../shared/model/location_suggestion_model.dart';
import '../../items/model/item_model.dart';
import '../../luggages/model/luggage_model.dart';

part 'trip_model.freezed.dart';
part 'trip_model.g.dart';

/// Stato del viaggio basato sulle date
enum TripStatus {
  /// Il viaggio non è ancora iniziato
  upcoming,

  /// Il viaggio è in corso
  active,

  /// Il viaggio è terminato
  completed,
}

/// Rappresenta un singolo item copiato in una lista di viaggio
@freezed
class TripItem with _$TripItem {
  const TripItem._();

  factory TripItem({
    required String id,
    required String name,
    required ItemCategory category,
    required int quantity,

    /// ID della casa di origine dell'oggetto (default vuoto per retrocompatibilità)
    @Default('') String originHouseId,
    @Default(false) bool isChecked,
  }) = _TripItem;

  factory TripItem.fromJson(Map<String, dynamic> json) =>
      _$TripItemFromJson(json);
}

/// Rappresenta una lista di viaggio/spostamento
@freezed
class TripModel with _$TripModel {
  const TripModel._();

  factory TripModel({
    required String id,
    required String name,
    String? description,
    @Default([]) List<TripItem> items,

    /// Data e ora di partenza
    DateTime? departureDateTime,

    /// Data e ora di ritorno
    DateTime? returnDateTime,

    /// Casa di destinazione (opzionale)
    String? destinationHouseId,

    /// Località di destinazione completa (quando non si seleziona una casa)
    /// Include coordinate, tipo di località, etc.
    LocationSuggestionModel? destinationLocation,

    /// Bagagli associati al viaggio (relazione M:N via junction table)
    @Default([]) List<LuggageModel> luggages,

    /// Viaggio salvato/preferito
    @Default(false) bool isSaved,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _TripModel;

  factory TripModel.empty() {
    return TripModel(
      id: '',
      name: '',
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Restituisce il nome della destinazione
  String? get destinationDisplayName {
    return destinationLocation?.displayName;
  }

  /// Determina lo stato attuale del viaggio
  TripStatus get status {
    final now = DateTime.now();

    if (departureDateTime == null) {
      return TripStatus.upcoming;
    }

    if (now.isBefore(departureDateTime!)) {
      return TripStatus.upcoming;
    }

    if (returnDateTime == null) {
      // Se non c'è data di ritorno, il viaggio è attivo dopo la partenza
      return TripStatus.active;
    }

    if (now.isAfter(returnDateTime!)) {
      return TripStatus.completed;
    }

    return TripStatus.active;
  }

  /// Verifica se il viaggio è attivo (gli oggetti sono "assenti" dalla casa di origine)
  bool get isActive => status == TripStatus.active;

  /// Verifica se il viaggio è completato
  bool get isCompleted => status == TripStatus.completed;

  /// Verifica se il viaggio non è ancora iniziato
  bool get isUpcoming => status == TripStatus.upcoming;

  /// Conta gli items completati
  int get completedCount => items.where((item) => item.isChecked).length;

  /// Conta il totale degli items
  int get totalCount => items.length;

  /// Percentuale di completamento
  double get completionPercentage =>
      totalCount > 0 ? completedCount / totalCount : 0;

  /// Conta il numero di bagagli associati al viaggio
  int get luggageCount => luggages.length;

  /// Calcola il volume totale dei bagagli (in litri)
  int get totalLuggageVolume {
    return luggages.fold<int>(
      0,
      (sum, luggage) => sum + (luggage.effectiveVolumeLiters ?? 0),
    );
  }

  factory TripModel.fromJson(Map<String, dynamic> json) =>
      _$TripModelFromJson(json);
}
