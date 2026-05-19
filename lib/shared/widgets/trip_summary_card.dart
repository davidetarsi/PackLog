import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/trips/model/trip_model.dart';
import '../constants/app_constants.dart';
import '../theme/theme.dart';
import 'trip_info_badges.dart';

/// Card riassuntiva per un viaggio.
///
/// Mostra:
/// - Nome del viaggio
/// - Date di partenza e ritorno
/// - Destinazione (casa o località)
/// - Barra di progresso degli oggetti preparati
///
/// Usabile sia nella lista viaggi che nel dettaglio viaggio.
class TripSummaryCard extends ConsumerWidget {
  /// Il viaggio da mostrare
  final TripModel trip;

  /// Se true, la card è cliccabile e naviga al dettaglio
  final bool isClickable;

  /// Callback opzionale quando la card viene premuta
  final VoidCallback? onTap;

  /// Callback opzionale quando la card viene tenuta premuta
  final VoidCallback? onLongPress;

  const TripSummaryCard({
    super.key,
    required this.trip,
    this.isClickable = true,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget cardContent = Padding(
      padding: EdgeInsets.all(context.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Riga Superiore: Nome Viaggio e Icona Aereo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  trip.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600, // ~24px → w600
                    fontSize: context.fontSizeTitle,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: context.spacingSm),
              Icon(
                Icons.flight_takeoff,
                size: context.iconSizeLg + 4,
                color: colorScheme.onSurface,
              ),
            ],
          ),

          SizedBox(height: context.spacingSm),

          // 2. Wrap di Badge orizzontali (Date, Luogo, Bagagli)
          TripInfoBadges(trip: trip),

          SizedBox(height: context.spacingMd),

          // 3. Barra progresso e conteggio
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'common.items_ready'.tr(
                  args: [
                    trip.completedCount.toString(),
                    trip.totalCount.toString(),
                    //percentageInt.toString(),
                  ],
                ),
                style: TextStyle(
                  fontSize: context.fontSizeSm,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: context.spacingXs),
              ClipRRect(
                borderRadius: context.responsiveBorderRadius(4),
                child: LinearProgressIndicator(
                  value: trip.completionPercentage,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    trip.completionPercentage == 1.0
                        ? context.appColors.success
                        : colorScheme.primary,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: context.responsiveBorderRadius(
          AppConstants.cardBorderRadius + 4,
        ),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: isClickable && (onTap != null || onLongPress != null)
          ? InkWell(
              borderRadius: context.responsiveBorderRadius(
                AppConstants.cardBorderRadius + 4,
              ),
              onTap: onTap,
              onLongPress: onLongPress,
              child: cardContent,
            )
          : cardContent,
    );
  }
}
