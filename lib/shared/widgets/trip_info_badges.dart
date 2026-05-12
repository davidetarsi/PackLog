import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/trips/model/trip_model.dart';
import '../../features/houses/providers/house_provider.dart';
import '../theme/app_spacing.dart';

/// Badge informativi per un viaggio (date, destinazione, bagagli).
///
/// Mostra (solo se disponibili):
/// - Date di partenza/ritorno
/// - Destinazione (nome casa o località)
/// - Conteggio bagagli e volume
///
/// Il parametro [direction] controlla il layout:
/// - `Axis.horizontal` (default): `Wrap` con wrap automatico a capo
/// - `Axis.vertical`: `Column` con un badge per riga
class TripInfoBadges extends ConsumerWidget {
  final TripModel trip;
  final Axis direction;

  const TripInfoBadges({
    super.key,
    required this.trip,
    this.direction = Axis.horizontal,
  });

  String _getDestinationName(WidgetRef ref) {
    if (trip.destinationHouseId != null) {
      final houses = ref.watch(houseNotifierProvider).valueOrNull;
      if (houses != null) {
        final house = houses.where((h) => h.id == trip.destinationHouseId).firstOrNull;
        if (house != null) return house.name;
      }
      return 'common.unknown_house'.tr();
    }
    final displayName = trip.destinationDisplayName;
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return 'common.no_destination'.tr();
  }

  String _formatTripDates() {
    if (trip.departureDateTime == null) return '';
    final departure = trip.departureDateTime!;

    String fmtDate(DateTime d) => DateFormat('d MMM').format(d);
    String fmtTime(DateTime d) => DateFormat('HH:mm').format(d);

    if (trip.returnDateTime != null) {
      final ret = trip.returnDateTime!;
      final sameDay = departure.day == ret.day &&
          departure.month == ret.month &&
          departure.year == ret.year;
      return sameDay
          ? '${fmtDate(departure)} • ${fmtTime(departure)} - ${fmtTime(ret)}'
          : '${fmtDate(departure)} - ${fmtDate(ret)}';
    }
    return '${fmtDate(departure)} • ${fmtTime(departure)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDates = _formatTripDates();
    final destinationName = _getDestinationName(ref);

    final List<Widget> badges = [
      if (formattedDates.isNotEmpty)
        _Badge(
          icon: Icons.calendar_today_outlined,
          text: formattedDates,
          colorScheme: colorScheme,
        ),
      _Badge(
        icon: Icons.place,
        text: destinationName,
        colorScheme: colorScheme,
      ),
      if (trip.luggageCount > 0)
        _Badge(
          icon: Icons.luggage,
          text: 'common.luggages_count'.tr(args: [
            trip.luggageCount.toString(),
            trip.totalLuggageVolume.toString(),
          ]),
          colorScheme: colorScheme,
        ),
    ];

    if (direction == Axis.vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < badges.length; i++) ...[
            badges[i],
            if (i < badges.length - 1) SizedBox(height: context.responsive(8)),
          ],
        ],
      );
    }

    return Wrap(
      spacing: context.responsive(16),
      runSpacing: context.responsive(8),
      children: badges,
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme colorScheme;

  const _Badge({
    required this.icon,
    required this.text,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        //color: colorScheme.surfaceContainerLow,
        borderRadius: context.responsiveBorderRadius(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: context.responsive(16),
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: context.fontSizeSm,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
