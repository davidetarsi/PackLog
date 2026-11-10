import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../model/trip_weather.dart';

/// Un giorno di una stima dallo storico: data, minima e massima medie, e sotto
/// la pioggia come anni su anni ("Pioggia 2 anni su 5", "Mai pioggia negli
/// ultimi 5 anni"). Niente
/// icona del tempo né fasce: sono medie, non una previsione.
class WeatherHistoryDayRow extends StatelessWidget {
  const WeatherHistoryDayRow({super.key, required this.day});

  final HistoricalDayWeather day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final locale = context.locale.toString();
    final max = day.tempMax;
    final min = day.tempMin;
    final details = _details();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacingMd,
        vertical: context.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toBeginningOfSentenceCase(
                    DateFormat('EEEE d MMMM', locale).format(day.date),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyLarge?.strong,
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (max != null && min != null)
            Text(
              'trips.weather.temps'.tr(
                args: [min.round().toString(), max.round().toString()],
              ),
              style: tt.titleMedium?.title,
            ),
        ],
      ),
    );
  }

  /// "Pioggia 2 anni su 5", oppure "Mai pioggia negli ultimi 5 anni".
  String _details() {
    if (day.dataYears == 0) return '';
    if (day.rainYears == 0) {
      return 'trips.weather.rain_never'.plural(
        day.dataYears,
        args: ['${day.dataYears}'],
      );
    }
    return 'trips.weather.rain_years'.plural(
      day.rainYears,
      args: ['${day.rainYears}', '${day.dataYears}'],
    );
  }
}
