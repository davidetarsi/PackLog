// ignore_for_file: non_abstract_class_inherits_abstract_member, invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip_leg.freezed.dart';
part 'trip_leg.g.dart';

/// Tappa intermedia di un viaggio.
///
/// È un promemoria, non una destinazione operativa: conserva il nome del
/// luogo e le date. [lat], [lon], [country] e [houseId] sono facoltativi:
/// [houseId] identifica una casa salvata, le coordinate descrivono il luogo.
/// Vivono serializzate nel blob JSON `trips.legs`: i campi facoltativi non
/// richiedono migrazione, e i JSON scritti prima di averli restano leggibili.
@freezed
class TripLeg with _$TripLeg {
  const factory TripLeg({
    required String id,
    @JsonKey(name: 'location_display_name') required String locationDisplayName,
    @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson) DateTime? from,
    @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson) DateTime? to,
    @JsonKey(name: 'lat') double? lat,
    @JsonKey(name: 'lon') double? lon,
    @JsonKey(name: 'country') String? country,
    @JsonKey(name: 'house_id') String? houseId,
  }) = _TripLeg;

  factory TripLeg.fromJson(Map<String, dynamic> json) =>
      _$TripLegFromJson(json);
}

/// Le date escono in UTC e rientrano in locale, come tutti gli altri timestamp
/// che finiscono su Supabase (vedi `sync_serializers.dart`).
String? _dateToJson(DateTime? value) => value?.toUtc().toIso8601String();

DateTime? _dateFromJson(String? value) =>
    value == null ? null : DateTime.parse(value).toLocal();
