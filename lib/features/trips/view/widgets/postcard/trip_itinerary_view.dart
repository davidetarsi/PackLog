import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_spacing.dart';
import '../../../../../shared/theme/surface_colors.dart';
import '../../../model/trip_postcard.dart';

/// Itinerario della cartolina: una linea verticale che collega Andata, luoghi,
/// spostamenti e Ritorno. Icone e pallini interrompono la linea.
class TripItineraryView extends StatelessWidget {
  final List<ItineraryEntry> entries;

  /// Tocco su una riga di luogo, con il suo indice tra i soli luoghi (0 è la
  /// meta). Null: le righe non reagiscono al tocco.
  final ValueChanged<int>? onPlaceTap;

  /// Primo luogo toccabile: i luoghi prima di questo indice restano righe
  /// normali, senza ripple. Nel passo 1 la meta (0) si cambia altrove.
  final int firstTappablePlace;

  const TripItineraryView({
    super.key,
    required this.entries,
    this.onPlaceTap,
    this.firstTappablePlace = 0,
  });

  @override
  Widget build(BuildContext context) {
    final tap = onPlaceTap;
    var placeCount = 0;
    final rows = <Widget>[];
    for (final (i, entry) in entries.indexed) {
      final placeIndex = entry.kind == ItineraryKind.place
          ? placeCount++
          : null;
      rows.add(
        _ItineraryRow(
          key: ValueKey('itinerary_row_$i'),
          entry: entry,
          isFirst: i == 0,
          isLast: i == entries.length - 1,
          onTap:
              tap == null ||
                  placeIndex == null ||
                  placeIndex < firstTappablePlace
              ? null
              : () => tap(placeIndex),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _ItineraryRow extends StatelessWidget {
  final ItineraryEntry entry;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  const _ItineraryRow({
    super.key,
    required this.entry,
    required this.isFirst,
    required this.isLast,
    this.onTap,
  });

  bool get _isPlace =>
      entry.kind == ItineraryKind.place ||
      entry.kind == ItineraryKind.moreStops;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final line = cs.outline;
    final gap = Colors.transparent;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: context.responsive(32),
            child: Column(
              children: [
                Expanded(child: _Segment(color: isFirst ? gap : line)),
                _marker(context),
                Expanded(child: _Segment(color: isLast ? gap : line)),
              ],
            ),
          ),
          SizedBox(width: context.spacingMd),
          Expanded(child: _withTap(_content(context, tt, cs))),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, TextTheme tt, ColorScheme cs) {
    final Widget body;
    if (!_isPlace) {
      body = _transferContent(context, tt, cs);
    } else {
      final place = _placeContent(context, tt, cs);
      // Una tappa toccabile mostra la freccia: si apre per modificarla.
      body = onTap == null
          ? place
          : Row(
              children: [
                Expanded(child: place),
                Icon(
                  Icons.chevron_right,
                  size: context.iconSizeSm,
                  color: cs.onSurfaceVariant,
                ),
              ],
            );
    }
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: _isPlace ? context.spacingSm : context.spacingXs,
      ),
      child: body,
    );
  }

  /// Solo le righe toccabili hanno un InkWell: senza tocco il contenuto resta
  /// com'è, anche fuori da un Material.
  Widget _withTap(Widget content) {
    final tap = onTap;
    if (tap == null) return content;
    return InkWell(onTap: tap, child: content);
  }

  Widget _marker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isPlace) {
      return Container(
        width: context.responsive(12),
        height: context.responsive(12),
        decoration: BoxDecoration(shape: BoxShape.circle, color: cs.onSurface),
      );
    }

    return Container(
      width: context.iconSizeMd,
      height: context.iconSizeMd,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.groupSurface,
      ),
      child: Icon(_icon, size: context.iconSizeSm, color: cs.onSurfaceVariant),
    );
  }

  IconData get _icon => switch (entry.kind) {
    ItineraryKind.departure => Icons.flight_takeoff,
    ItineraryKind.transfer => Icons.flight,
    ItineraryKind.ret => Icons.flight_land,
    ItineraryKind.place || ItineraryKind.moreStops => Icons.circle,
  };

  /// Luogo o "+N tappe": nome in grassetto, periodo sotto.
  Widget _placeContent(BuildContext context, TextTheme tt, ColorScheme cs) {
    if (entry.kind == ItineraryKind.moreStops) {
      return Text(
        'trips.itinerary.more_stops'.plural(entry.hiddenStops ?? 0),
        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          entry.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          _periodLabel(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  /// Andata, spostamento o Ritorno: etichetta a sinistra, data in grassetto
  /// a destra.
  Widget _transferContent(BuildContext context, TextTheme tt, ColorScheme cs) {
    final date = entry.date;

    return Row(
      children: [
        Expanded(
          child: Text(
            _label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        SizedBox(width: context.spacingSm),
        Text(
          date == null
              ? 'trips.postcard.no_date'.tr()
              : _formatDate(context, date, 'EEE d MMM'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  String get _label => switch (entry.kind) {
    ItineraryKind.departure => 'trips.itinerary.departure'.tr(),
    ItineraryKind.transfer => 'trips.itinerary.transfer'.tr(),
    ItineraryKind.ret => 'trips.itinerary.return'.tr(),
    ItineraryKind.place || ItineraryKind.moreStops => '',
  };

  /// "3 notti · 28 ott – 31 ott", con le notti omesse se non si calcolano.
  /// Senza una delle due date del periodo, solo "da decidere".
  String _periodLabel(BuildContext context) {
    final from = entry.from;
    final to = entry.to;
    if (from == null || to == null) return 'trips.postcard.no_date'.tr();

    final nights = nightsBetween(from, to);
    final range =
        '${_formatDate(context, from, 'd MMM')} – '
        '${_formatDate(context, to, 'd MMM')}';
    return nights == null
        ? range
        : '${'trips.itinerary.nights'.plural(nights)} · $range';
  }

  String _formatDate(BuildContext context, DateTime date, String pattern) =>
      DateFormat(pattern, context.locale.toString()).format(date);
}

/// Pezzo verticale della linea. Trasparente sopra la prima riga e sotto
/// l'ultima.
class _Segment extends StatelessWidget {
  final Color color;

  const _Segment({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.responsive(2),
      child: ColoredBox(color: color),
    );
  }
}
