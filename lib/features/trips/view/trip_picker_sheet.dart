import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/helpers/design_system.dart';

/// Bottom sheet per scegliere un viaggio non ancora concluso a cui
/// aggiungere degli oggetti selezionati da una casa.
///
/// Mostra solo i viaggi con `!trip.isCompleted` (upcoming o active) —
/// un viaggio concluso non ha senso come destinazione per nuovi oggetti.
class TripPickerSheet extends ConsumerWidget {
  const TripPickerSheet({super.key});

  static Future<TripModel?> show(BuildContext context) {
    return showModalBottomSheet<TripModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TripPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tripsAsync = ref.watch(tripNotifierProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.modalBorderRadius),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DsBottomSheetHandle(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingMd,
                vertical: context.spacingSm,
              ),
              child: Text(
                'trips.trip_picker_sheet_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: tripsAsync.when(
                  data: (allTrips) {
                    final openTrips = allTrips
                        .where((t) => !t.isCompleted)
                        .toList();
                    if (openTrips.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.all(context.spacingLg),
                        child: Text(
                          'trips.trip_picker_no_trips'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: openTrips
                          .map(
                            (trip) => ListTile(
                              leading: Icon(
                                Icons.luggage_outlined,
                                color: cs.onSurfaceVariant,
                              ),
                              title: Text(trip.name),
                              subtitle: trip.destinationDisplayName != null
                                  ? Text(trip.destinationDisplayName!)
                                  : null,
                              onTap: () => Navigator.of(context).pop(trip),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => ListTile(
                    enabled: false,
                    leading: const Icon(Icons.error_outline),
                    title: Text('errors.load_failed'.tr()),
                  ),
                ),
              ),
            ),
            SizedBox(height: context.spacingMd),
          ],
        ),
      ),
    );
  }
}
