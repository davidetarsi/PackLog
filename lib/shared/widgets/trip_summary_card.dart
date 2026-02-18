import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/trips/model/trip_model.dart';
import '../../features/houses/providers/house_provider.dart';
import '../constants/app_constants.dart';
import '../theme/theme.dart';

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

  const TripSummaryCard({
    super.key,
    required this.trip,
    this.isClickable = true,
    this.onTap,
  });

  /// Ottiene il nome della destinazione (casa o località)
  String _getDestinationName(WidgetRef ref) {
    // Se c'è una casa di destinazione, cerca il nome
    if (trip.destinationHouseId != null) {
      final housesAsync = ref.watch(houseNotifierProvider);
      final houses = housesAsync.valueOrNull;
      if (houses != null) {
        final house = houses
            .where((h) => h.id == trip.destinationHouseId)
            .firstOrNull;
        if (house != null) {
          return house.name;
        }
      }
      return 'Casa sconosciuta';
    }

    // Usa il getter che gestisce sia il nuovo modello che il campo legacy
    final displayName = trip.destinationDisplayName;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return 'Nessuna destinazione';
  }

  String _formatTripDates() {
    if (trip.departureDateTime == null) return '';

    final departure = trip.departureDateTime!;
    final months = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
    ];

    String formatDate(DateTime date) {
      return '${date.day} ${months[date.month - 1]}';
    }

    String formatTime(DateTime date) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    if (trip.returnDateTime != null) {
      final returnDate = trip.returnDateTime!;
      if (departure.day == returnDate.day &&
          departure.month == returnDate.month &&
          departure.year == returnDate.year) {
        // Stesso giorno
        return '${formatDate(departure)} • ${formatTime(departure)} - ${formatTime(returnDate)}';
      } else {
        return '${formatDate(departure)} - ${formatDate(returnDate)}';
      }
    }

    return '${formatDate(departure)} • ${formatTime(departure)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final destinationName = _getDestinationName(ref);
    final formattedDates = _formatTripDates();
    final percentageInt = (trip.completionPercentage * 100).toInt();

    Widget cardContent = Padding(
      padding: EdgeInsets.all(context.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Riga superiore: Info viaggio + Icona aereo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonna info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome viaggio
                    Text(
                      trip.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: context.fontSizeXl + 2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Date
                    if (formattedDates.isNotEmpty) ...[
                      SizedBox(height: context.spacingXs),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: context.iconSizeSm,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          SizedBox(width: context.spacingXs),
                          Text(
                            formattedDates,
                            style: TextStyle(
                              fontSize: context.fontSizeMd,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Destinazione
                    SizedBox(height: context.spacingXs),
                    Row(
                      children: [
                        Icon(
                          Icons.place,
                          size: context.iconSizeSm,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        SizedBox(width: context.spacingXs),
                        Flexible(
                          child: Text(
                            destinationName,
                            style: TextStyle(
                              fontSize: context.fontSizeMd,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Icona aereo
              SizedBox(width: context.spacingSm),
              Icon(
                Icons.flight_takeoff,
                size: context.iconSizeLg + 8,
                color: colorScheme.primary,
              ),
            ],
          ),
          
          SizedBox(height: context.spacingMd),
          
          // Barra progresso e conteggio
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Testo progresso
              Text(
                '${trip.completedCount}/${trip.totalCount} pronti ($percentageInt%)',
                style: TextStyle(
                  fontSize: context.fontSizeSm,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: context.spacingXs),
              
              // Barra progresso
              ClipRRect(
                borderRadius: context.responsiveBorderRadius(4),
                child: LinearProgressIndicator(
                  value: trip.completionPercentage,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    trip.completionPercentage == 1.0
                        ? AppColors.success
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
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: isClickable && onTap != null
          ? InkWell(
              borderRadius: context.responsiveBorderRadius(
                AppConstants.cardBorderRadius + 4,
              ),
              onTap: onTap,
              child: cardContent,
            )
          : cardContent,
    );
  }
}
