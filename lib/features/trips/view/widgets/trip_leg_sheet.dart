import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/helpers/snack_bar_helper.dart';
import '../../../../shared/theme/theme.dart';
import '../../../../shared/widgets/location_autocomplete_field.dart';
import '../../../../shared/widgets/standard_bottom_sheet_layout.dart';
import '../../model/trip_date_range.dart';
import '../../model/trip_leg.dart';
import '../trip_date_range_screen.dart';

/// Apre il form di creazione/modifica di una tappa.
///
/// Restituisce la tappa, oppure `null` se l'utente chiude senza salvare.
/// In modifica l'id di [initial] viene conservato: senza, modificare una
/// tappa equivarrebbe a cancellarla e ricrearla.
Future<TripLeg?> showTripLegSheet(BuildContext context, {TripLeg? initial}) {
  return showModalBottomSheet<TripLeg>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripLegSheet(initial: initial),
  );
}

class _TripLegSheet extends StatefulWidget {
  final TripLeg? initial;

  const _TripLegSheet({this.initial});

  @override
  State<_TripLegSheet> createState() => _TripLegSheetState();
}

class _TripLegSheetState extends State<_TripLegSheet> {
  late String _location = widget.initial?.locationDisplayName ?? '';
  late DateTime? _from = widget.initial?.from;
  late DateTime? _to = widget.initial?.to;

  bool get _canSave => _location.trim().isNotEmpty;

  Future<void> _pickDates() async {
    final result = await Navigator.of(context).push<TripDateRange>(
      MaterialPageRoute(
        builder: (_) =>
            TripDateRangeScreen(initialDeparture: _from, initialReturn: _to),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _from = result.departureDate;
      _to = result.returnDate;
    });
  }

  void _save() {
    if (!_canSave) {
      // Il bottone resta attivo di proposito: un tap che non fa nulla non
      // fa capire se manca un campo o se l'app è rotta.
      AppSnackBar.showError(context, 'trips.leg_location_required'.tr());
      return;
    }
    Navigator.pop(
      context,
      TripLeg(
        id: widget.initial?.id ?? const Uuid().v4(),
        locationDisplayName: _location.trim(),
        from: _from,
        to: _to,
      ),
    );
  }

  String get _datesLabel {
    if (_from == null && _to == null) return 'trips.leg_pick_dates'.tr();
    final format = DateFormat('d MMM');
    if (_to == null) return format.format(_from!);
    // Il picker non produce mai "solo to", ma il valore arriva anche dal
    // sync di un altro device: un blob con solo `to` non è più impossibile.
    if (_from == null) return format.format(_to!);
    return '${format.format(_from!)} – ${format.format(_to!)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDates = _from != null || _to != null;

    return StandardBottomSheetLayout(
      title: widget.initial == null
          ? 'trips.leg_new'.tr()
          : 'trips.leg_edit'.tr(),
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      saveLabel: 'common.save'.tr(),
      saveButtonKey: const Key('trip_leg_sheet_save'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'trips.leg_location'.tr(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.spacingXs),
          LocationAutocompleteField(
            key: const Key('trip_leg_sheet_location'),
            initialValue: widget.initial?.locationDisplayName,
            hintText: 'trips.destination_hint'.tr(),
            onLocationSelected: (location) =>
                setState(() => _location = location.displayName),
            onTextChanged: (text) => setState(() => _location = text),
          ),
          SizedBox(height: context.spacingMd),
          Text(
            'trips.leg_dates'.tr(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.spacingXs),
          InkWell(
            key: const Key('trip_leg_sheet_dates'),
            onTap: _pickDates,
            borderRadius: context.responsiveBorderRadius(12),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingMd,
                vertical: context.spacingMd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: context.spacingMd),
                  Expanded(
                    child: Text(
                      _datesLabel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: hasDates
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Chevron, non azione: le date si scelgono in una schermata
                  // intera, non qui dentro.
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
