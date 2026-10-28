import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/app_spacing.dart';
import '../../../../../shared/widgets/ds_group_header.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../model/trip_model.dart';
import '../../../model/trip_postcard.dart';
import 'postcard_parts.dart';
import '../../../../../shared/theme/app_text_styles.dart';

/// Gruppo dell'album: etichetta (anno o "Da riusare") e i viaggi del gruppo.
class TripAlbumGroup {
  final String label;
  final List<TripModel> trips;

  const TripAlbumGroup(this.label, this.trips);
}

/// Album di cartoline piccole, due per riga, appese un po' storte. Ogni gruppo
/// ha il proprio header; la lista scorre tutta insieme.
class TripAlbum extends StatelessWidget {
  static const int _columns = 2;
  static const double _cellAspectRatio = 0.82;

  /// Inclinazione (rad) delle cartoline, a rotazione ciclica nel gruppo.
  static const List<double> _tilts = [-0.025, 0.02, 0.012, -0.018];

  final List<TripAlbumGroup> groups;

  /// Con vero i francobolli passati sono annullati dalle onde del timbro.
  final bool cancelledStamps;

  /// Nome della meta mostrato sulla cartolina.
  final String Function(TripModel trip) destinationOf;

  final ValueChanged<TripModel> onTap;
  final ValueChanged<TripModel> onLongPress;
  final ValueChanged<TripModel> onReuse;

  /// Padding della lista. Di default `spacingMd` ai lati.
  final EdgeInsetsGeometry? padding;

  const TripAlbum({
    super.key,
    required this.groups,
    required this.cancelledStamps,
    required this.destinationOf,
    required this.onTap,
    required this.onLongPress,
    required this.onReuse,
    this.padding,
  });

  Widget _tilted(TripModel trip, int index) => Transform.rotate(
    angle: _tilts[index % _tilts.length],
    child: _AlbumPostcard(
      key: Key('album_postcard_${trip.id}'),
      trip: trip,
      destination: destinationOf(trip),
      cancelled: cancelledStamps,
      onTap: onTap,
      onLongPress: onLongPress,
      onReuse: onReuse,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Esplicito: la lista resta trascinabile anche se più corta della vista,
      // così il RefreshIndicator che la avvolge scatta sempre.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding ?? EdgeInsets.symmetric(horizontal: context.spacingMd),
      children: [
        for (final group in groups) ...[
          DsGroupHeader(label: group.label, count: group.trips.length),
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = context.spacingMd;
              final cellWidth =
                  (constraints.maxWidth - gap * (_columns - 1)) / _columns;
              final trips = group.trips;
              return Column(
                children: [
                  for (var row = 0; row * _columns < trips.length; row++)
                    Padding(
                      padding: EdgeInsets.only(
                        top: row == 0 ? 0 : context.spacingMd,
                      ),
                      // Le proporzioni dell'album sono il minimo: con il
                      // testo di sistema ingrandito la riga si allunga.
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: cellWidth / _cellAspectRatio,
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var col = 0; col < _columns; col++) ...[
                                if (col > 0) SizedBox(width: gap),
                                Expanded(
                                  child: row * _columns + col < trips.length
                                      ? _tilted(
                                          trips[row * _columns + col],
                                          row * _columns + col,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Cartolina piccola: francobollo in alto a destra, nome del viaggio, notti
/// e l'azione per riusare il viaggio in basso.
class _AlbumPostcard extends StatelessWidget {
  /// Interlinea del titolo, stretta perché sta su due righe.
  static const double _titleHeight = 1.1;

  final TripModel trip;
  final String destination;
  final bool cancelled;
  final ValueChanged<TripModel> onTap;
  final ValueChanged<TripModel> onLongPress;
  final ValueChanged<TripModel> onReuse;

  const _AlbumPostcard({
    super.key,
    required this.trip,
    required this.destination,
    required this.cancelled,
    required this.onTap,
    required this.onLongPress,
    required this.onReuse,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nights = nightsBetween(trip.departureDateTime, trip.returnDateTime);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(trip),
      onLongPress: () => onLongPress(trip),
      child: PostcardPaper(
        padding: EdgeInsets.fromLTRB(
          context.spacingMd,
          context.spacingMd,
          context.spacingSm,
          context.spacingSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: _AlbumStamp(
                date: trip.departureDateTime,
                cancelled: cancelled,
              ),
            ),
            const Spacer(),
            Text(
              postcardTitle(trip, destination: destination),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.titleLarge?.postcard.copyWith(height: _titleHeight),
            ),
            if (nights != null)
              Text(
                'trips.itinerary.nights'.plural(nights),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DsTextButton(
                key: Key('album_reuse_${trip.id}'),
                onPressed: () => onReuse(trip),
                icon: Icons.replay,
                label: 'trips.album.reuse'.tr(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Francobollo piccolo con giorno e `MMM yy` in maiuscolo. Senza partenza
/// mostra il segnalibro. Con [cancelled] le onde del timbro coprono solo la
/// striscia destra, lasciando il testo libero.
class _AlbumStamp extends StatelessWidget {
  /// Frazione della larghezza riservata alle onde sul bordo destro.
  static const double _waveFraction = 0.2;

  final DateTime? date;
  final bool cancelled;

  const _AlbumStamp({required this.date, required this.cancelled});

  /// Lato del francobollo.
  static double sizeOf(BuildContext context) =>
      context.responsive(AppConstants.albumStampSize);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final width = sizeOf(context);
    final height = width;
    final waveWidth = width * _waveFraction;
    final day = date;

    final content = day == null
        ? Icon(
            Icons.bookmark_border,
            size: context.iconSizeMd,
            color: cs.onSurfaceVariant,
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${day.day}', style: tt.titleLarge?.postcard),
                Text(
                  DateFormat(
                    'MMM yy',
                    context.locale.toString(),
                  ).format(day).toUpperCase(),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          PostageStamp(
            size: Size(width, height),
            child: Padding(
              padding: EdgeInsets.only(right: cancelled ? waveWidth : 0),
              child: content,
            ),
          ),
          if (cancelled)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: waveWidth,
              child: CancelWaves(size: Size(waveWidth, height)),
            ),
        ],
      ),
    );
  }
}
