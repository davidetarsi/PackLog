import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/trips/model/trip_model.dart';
import '../../features/houses/providers/house_provider.dart';
import '../theme/app_spacing.dart';
import 'ds_badge.dart';


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
    final formattedDates = _formatTripDates();
    final destinationName = _getDestinationName(ref);

    final List<Widget> badges = [
      if (formattedDates.isNotEmpty)
        DsInfoBadge(
          icon: Icons.calendar_today_outlined,
          label: formattedDates,
        ),
      DsInfoBadge(
        icon: Icons.place,
        label: destinationName,
      ),
      if (trip.luggageCount > 0)
        DsInfoBadge(
          icon: Icons.luggage,
          label: 'common.luggages_count'.tr(args: [
            trip.luggageCount.toString(),
            trip.totalLuggageVolume.toString(),
          ]),
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

