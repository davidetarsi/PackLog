// ignore_for_file: non_abstract_class_inherits_abstract_member, invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip_leg.freezed.dart';
part 'trip_leg.g.dart';

/// Tappa intermedia di un viaggio.
///
/// È un promemoria, non una destinazione operativa: conserva solo il nome del
/// luogo e le date. Niente `placeId`, coordinate o [LocationType], perché
/// nessuna logica dell'app li legge. Vivono serializzate nel blob JSON
/// `trips.legs`, quindi aggiungere campi in futuro non costa una migrazione.
@freezed
class TripLeg with _$TripLeg {
  const factory TripLeg({
    required String id,
    @JsonKey(name: 'location_display_name') required String locationDisplayName,
    @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson) DateTime? from,
    @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson) DateTime? to,
  }) = _TripLeg;

  factory TripLeg.fromJson(Map<String, dynamic> json) =>
      _$TripLegFromJson(json);
}

/// Le date escono in UTC e rientrano in locale, come tutti gli altri timestamp
/// che finiscono su Supabase (vedi `sync_serializers.dart`).
String? _dateToJson(DateTime? value) => value?.toUtc().toIso8601String();

DateTime? _dateFromJson(String? value) =>
    value == null ? null : DateTime.parse(value).toLocal();
