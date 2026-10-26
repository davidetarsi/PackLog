import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_spacing.dart';
import '../../../model/trip_model.dart';
import '../../../model/trip_postcard.dart';

/// Riepilogo del viaggio in una riga, in cima alla valigia: nome in grande; sotto
/// le date, le notti e i luoghi; a destra i giorni alla partenza, come il
/// francobollo della cartolina ("-9 giorni", "oggi", "in viaggio").
class PackSummaryLine extends StatelessWidget {
  final TripModel trip;

  /// Nome della casa di destinazione, se la meta è una casa.
  final String? destinationHouseName;

  /// Nomi delle case per id: una tappa che è una casa mostra il nome intero.
  final Map<String, String> houseNames;

  const PackSummaryLine({
    super.key,
    required this.trip,
    this.destinationHouseName,
    this.houseNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final destination = tripDestinationName(
      trip,
      houseName: destinationHouseName,
    );
    final title = postcardTitle(trip, destination: destination);
    final details = tripSummaryDetails(
      context,
      trip,
      destination: destination,
      houseNames: houseNames,
    );
    final stamp = tripStampLabel(trip);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                details,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (stamp != null) ...[
          SizedBox(width: context.spacingSm),
          Text(
            stamp,
            style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// "29 ott – 3 nov · 5 notti · Lisbona, Sintra". Senza date, "da decidere".
/// La usano il riepilogo della valigia e la scelta di un viaggio.
String tripSummaryDetails(
  BuildContext context,
  TripModel trip, {
  required String destination,
  Map<String, String> houseNames = const {},
}) {
  final locale = context.locale.toString();
  final departure = trip.departureDateTime;
  final returnAt = trip.returnDateTime;

  final parts = <String>[];
  if (departure != null && returnAt != null) {
    final from = DateFormat('d MMM', locale).format(departure);
    final to = DateFormat('d MMM', locale).format(returnAt);
    parts.add('$from – $to');
    final nights = nightsBetween(departure, returnAt);
    if (nights != null) parts.add('trips.itinerary.nights'.plural(nights));
  } else {
    parts.add('trips.postcard.no_date'.tr());
  }

  // Nessuna tappa va riassunta: la riga elenca tutti i luoghi.
  final places = buildItinerary(
    trip,
    destination: destination,
    houseNames: houseNames,
    maxPlaces: trip.legs.length + 2,
  ).where((entry) => entry.kind == ItineraryKind.place);
  final names = [
    for (final place in places)
      if (place.name != null) place.name!,
  ];
  if (names.isNotEmpty) parts.add(names.join(', '));

  return parts.join(' · ');
}

/// I giorni alla partenza come il francobollo della cartolina ("-9 giorni",
/// "oggi", "in viaggio"); null senza date.
String? tripStampLabel(TripModel trip) {
  final stamp = stampFor(trip, DateTime.now());
  return switch (stamp.kind) {
    StampKind.daysLeft => 'trips.pack.days_left'.plural(stamp.days ?? 0),
    StampKind.today => 'trips.postcard.today'.tr(),
    StampKind.traveling => 'trips.postcard.traveling'.tr(),
    StampKind.noDate => null,
  };
}
