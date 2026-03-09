// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:easy_localization/easy_localization.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'luggage_model.freezed.dart';
part 'luggage_model.g.dart';

/// Taglia standard del bagaglio.
enum LuggageSize {
  /// Zaino piccolo (fino a 20L circa)
  @JsonValue('small_backpack')
  smallBackpack,
  
  /// Bagaglio a mano (40-55cm, 8-10kg)
  @JsonValue('cabin_baggage')
  cabinBaggage,
  
  /// Bagaglio da stiva (grandi dimensioni)
  @JsonValue('hold_baggage')
  holdBaggage,
  
  /// Dimensioni personalizzate (usa volumeLiters)
  @JsonValue('custom')
  custom,
}

/// Extension per ottenere il nome visualizzato della taglia.
extension LuggageSizeExtension on LuggageSize {
  String get displayName {
    switch (this) {
      case LuggageSize.smallBackpack:
        return 'luggage_sizes.small_backpack'.tr();
      case LuggageSize.cabinBaggage:
        return 'luggage_sizes.cabin_baggage'.tr();
      case LuggageSize.holdBaggage:
        return 'luggage_sizes.hold_baggage'.tr();
      case LuggageSize.custom:
        return 'luggage_sizes.custom'.tr();
    }
  }
  
  /// Volume approssimativo in litri per le taglie standard.
  /// Usato come indicatore, non vincolante.
  int? get approximateVolumeLiters {
    switch (this) {
      case LuggageSize.smallBackpack:
        return 20;
      case LuggageSize.cabinBaggage:
        return 40;
      case LuggageSize.holdBaggage:
        return 80;
      case LuggageSize.custom:
        return null; // User-defined
    }
  }
}

/// Rappresenta un bagaglio riutilizzabile associato a una casa.
/// 
/// I bagagli sono entità globali che appartengono a una casa specifica
/// e possono essere riutilizzati in viaggi multipli tramite la junction table.
@freezed
class LuggageModel with _$LuggageModel {
  const LuggageModel._();

  factory LuggageModel({
    required String id,
    
    /// ID della casa a cui appartiene il bagaglio
    required String houseId,
    
    /// Nome del bagaglio (es. "Zaino Blu", "Valigia Grande")
    required String name,
    
    /// Taglia standard del bagaglio
    required LuggageSize sizeType,
    
    /// Volume in litri (opzionale, obbligatorio solo se sizeType == custom)
    int? volumeLiters,
    
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _LuggageModel;

  factory LuggageModel.empty(String houseId) {
    return LuggageModel(
      id: '',
      houseId: houseId,
      name: '',
      sizeType: LuggageSize.cabinBaggage,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Restituisce il volume effettivo del bagaglio.
  /// 
  /// Per taglie standard, usa il volume approssimativo dell'enum.
  /// Per custom, usa il valore user-defined.
  int? get effectiveVolumeLiters {
    if (sizeType == LuggageSize.custom) {
      return volumeLiters;
    }
    return sizeType.approximateVolumeLiters;
  }

  /// Restituisce una descrizione leggibile della taglia.
  String get sizeDescription {
    if (sizeType == LuggageSize.custom && volumeLiters != null) {
      return '$volumeLiters L';
    }
    return sizeType.displayName;
  }

  factory LuggageModel.fromJson(Map<String, dynamic> json) =>
      _$LuggageModelFromJson(json);
}
