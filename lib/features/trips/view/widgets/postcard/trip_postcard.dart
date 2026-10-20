import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_spacing.dart';
import '../../../../../shared/widgets/ds_button.dart';
import '../../../model/trip_model.dart';
import '../../../model/trip_postcard.dart';
import 'postcard_parts.dart';
import 'trip_itinerary_view.dart';

/// Cartolina grande di un viaggio: intestazione con la meta, francobollo con
/// timbro, itinerario, stato della valigia e azione principale.
///
/// Richiede un'altezza vincolata dal genitore: l'itinerario parte dall'alto e
/// scorre se lo spazio è poco; lo spazio libero sta tra itinerario e valigia,
/// così valigia e azione restano in fondo alla carta.
class TripPostcard extends StatelessWidget {
  static const double _ringStroke = 6;

  final TripModel trip;

  /// Nome della meta mostrato in grande, intero (es. nome della casa).
  final String destination;

  final ValueChanged<PostcardCta> onCta;

  /// Nomi delle case per id: una tappa che è una casa li mostra interi.
  final Map<String, String> houseNames;

  const TripPostcard({
    super.key,
    required this.trip,
    required this.destination,
    required this.onCta,
    this.houseNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final stamp = stampFor(trip, DateTime.now());
    final cta = ctaFor(trip);
    final title = postcardTitle(trip, destination: destination);
    final showDestination =
        destination.trim().toLowerCase() != title.toLowerCase();

    return PostcardPaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: tt.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    if (showDestination)
                      Text(
                        destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: context.spacingMd),
              _StampArea(stamp: stamp, departure: trip.departureDateTime),
            ],
          ),
          SizedBox(height: context.spacingMd),
          Expanded(
            child: SingleChildScrollView(
              child: TripItineraryView(
                entries: buildItinerary(
                  trip,
                  destination: destination,
                  houseNames: houseNames,
                ),
              ),
            ),
          ),
          SizedBox(height: context.spacingMd),
          _SuitcaseRow(trip: trip),
          SizedBox(height: context.spacingMd),
          DsButton(
            key: const Key('postcard_cta'),
            label: _ctaLabel(cta),
            icon: _ctaIcon(cta),
            onPressed: () => onCta(cta),
            expand: true,
          ),
        ],
      ),
    );
  }

  static String _ctaLabel(PostcardCta cta) => switch (cta) {
    PostcardCta.prepare => 'trips.postcard.cta_prepare'.tr(),
    PostcardCta.ready => 'trips.postcard.cta_ready'.tr(),
    PostcardCta.continuePacking => 'trips.postcard.cta_continue'.tr(),
  };

  static IconData _ctaIcon(PostcardCta cta) => switch (cta) {
    PostcardCta.prepare => Icons.luggage_outlined,
    PostcardCta.ready => Icons.check_circle_outline,
    PostcardCta.continuePacking => Icons.luggage_outlined,
  };
}

/// Francobollo e, se c'è una data di partenza, il timbro che lo sovrappone.
class _StampArea extends StatelessWidget {
  final ({StampKind kind, int? days}) stamp;
  final DateTime? departure;

  const _StampArea({required this.stamp, required this.departure});

  @override
  Widget build(BuildContext context) {
    final stampWidth = context.responsive(80);
    final stampHeight = context.responsive(96);
    final markSize = context.responsive(72);

    return SizedBox(
      width: stampWidth + markSize * 0.7,
      height: stampHeight + markSize * 0.6,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: PostageStamp(
              key: const Key('postcard_stamp'),
              size: Size(stampWidth, stampHeight),
              child: _StampContent(stamp: stamp),
            ),
          ),
          if (departure != null)
            Positioned(
              left: 0,
              bottom: 0,
              child: Postmark(
                key: const Key('postcard_postmark'),
                date: departure!,
                size: markSize,
              ),
            ),
        ],
      ),
    );
  }
}

class _StampContent extends StatelessWidget {
  final ({StampKind kind, int? days}) stamp;

  const _StampContent({required this.stamp});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final days = stamp.days;

    return switch (stamp.kind) {
      StampKind.daysLeft => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '-$days',
            style: tt.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            'trips.postcard.days_label'.plural(days ?? 0),
            style: tt.labelMedium,
          ),
        ],
      ),
      StampKind.today => Text(
        'trips.postcard.today'.tr(),
        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      StampKind.traveling => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flight_takeoff, size: context.iconSizeLg),
          Text('trips.postcard.traveling'.tr(), style: tt.labelMedium),
        ],
      ),
      StampKind.noDate => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event, size: context.iconSizeLg),
          Text(
            'trips.postcard.no_date'.tr(),
            style: tt.labelMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    };
  }
}

/// Stato della valigia: anello con la percentuale, conteggio, bagagli.
class _SuitcaseRow extends StatelessWidget {
  final TripModel trip;

  const _SuitcaseRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = trip.totalCount;
    final done = trip.completedCount;
    final fraction = total == 0 ? 0.0 : done / total;
    final ringSize = context.responsive(52);

    final String title;
    final String subtitle;
    if (total == 0) {
      title = 'trips.postcard.empty_title'.tr();
      subtitle = 'trips.postcard.empty_sub'.tr();
    } else {
      title = 'trips.postcard.ready_count'.tr(args: ['$done', '$total']);
      subtitle = done == total
          ? 'trips.postcard.all_packed'.tr()
          : 'trips.postcard.missing'.plural(total - done);
    }

    final luggageNames = trip.luggages.map((l) => l.name).join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: cs.outlineVariant),
        SizedBox(height: context.spacingMd),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: fraction,
                      strokeWidth: TripPostcard._ringStroke,
                      backgroundColor: cs.surfaceContainerHigh,
                      color: cs.onSurface,
                    ),
                  ),
                  Text('${(fraction * 100).round()}%', style: tt.labelMedium),
                ],
              ),
            ),
            SizedBox(width: context.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (trip.luggages.isNotEmpty) ...[
              SizedBox(width: context.spacingSm),
              Flexible(
                child: Row(
                  key: const Key('postcard_luggage'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.luggage_outlined,
                      size: context.iconSizeMd,
                      color: cs.onSurfaceVariant,
                    ),
                    SizedBox(width: context.spacingXs),
                    Flexible(
                      child: Text(
                        luggageNames,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
