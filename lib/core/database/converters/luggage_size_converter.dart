import 'package:drift/drift.dart';
import '../../../features/luggages/model/luggage_model.dart';

/// Converter per serializzare LuggageSize enum nel database SQLite.
/// 
/// Converte:
/// - LuggageSize.smallBackpack → 'small_backpack'
/// - LuggageSize.cabinBaggage → 'cabin_baggage'
/// - LuggageSize.holdBaggage → 'hold_baggage'
/// - LuggageSize.custom → 'custom'
class LuggageSizeConverter extends TypeConverter<LuggageSize, String> {
  const LuggageSizeConverter();

  @override
  LuggageSize fromSql(String fromDb) {
    switch (fromDb) {
      case 'small_backpack':
        return LuggageSize.smallBackpack;
      case 'cabin_baggage':
        return LuggageSize.cabinBaggage;
      case 'hold_baggage':
        return LuggageSize.holdBaggage;
      case 'custom':
        return LuggageSize.custom;
      default:
        // Fallback sicuro: se il valore non è riconosciuto, usa custom
        return LuggageSize.custom;
    }
  }

  @override
  String toSql(LuggageSize value) {
    switch (value) {
      case LuggageSize.smallBackpack:
        return 'small_backpack';
      case LuggageSize.cabinBaggage:
        return 'cabin_baggage';
      case LuggageSize.holdBaggage:
        return 'hold_baggage';
      case LuggageSize.custom:
        return 'custom';
    }
  }
}
