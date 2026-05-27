/// Immutable value object che rappresenta un range di date di viaggio
/// (partenza + ritorno).
///
/// Nessuna dipendenza da Flutter o Riverpod — testabile come puro Dart.
class TripDateRange {
  final DateTime? departureDate;
  final DateTime? returnDate;

  const TripDateRange({this.departureDate, this.returnDate});

  /// `true` quando sia partenza che ritorno sono impostati.
  bool get isComplete => departureDate != null && returnDate != null;

  /// `true` quando nessuna data è impostata.
  bool get isEmpty => departureDate == null && returnDate == null;

  /// `true` quando è impostata solo la partenza.
  bool get hasOnlyDeparture => departureDate != null && returnDate == null;

  TripDateRange copyWith({
    DateTime? departureDate,
    DateTime? returnDate,
    bool clearReturn = false,
  }) {
    return TripDateRange(
      departureDate: departureDate ?? this.departureDate,
      returnDate: clearReturn ? null : (returnDate ?? this.returnDate),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripDateRange &&
          runtimeType == other.runtimeType &&
          departureDate == other.departureDate &&
          returnDate == other.returnDate;

  @override
  int get hashCode => Object.hash(departureDate, returnDate);

  @override
  String toString() =>
      'TripDateRange(departure: $departureDate, return: $returnDate)';
}
