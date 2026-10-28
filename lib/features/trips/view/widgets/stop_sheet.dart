import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_button.dart';
import '../../../../shared/widgets/ds_field.dart';
import '../../../../shared/widgets/ds_field_label.dart';
import '../../../../shared/widgets/ds_form_sheet.dart';
import '../../../../shared/widgets/ds_link_button.dart';
import '../../model/trip_draft.dart';
import '../../model/trip_postcard.dart';
import 'place_search.dart';
import 'trip_dates_sheet.dart';
import '../../../../shared/widgets/ds_glass_band.dart';

/// Esito del foglio della tappa.
sealed class StopSheetResult {
  const StopSheetResult();
}

/// Tappa scelta: il posto e il giorno in cui finisce.
final class StopSaved extends StopSheetResult {
  const StopSaved(this.stop);

  final DraftStop stop;
}

/// La tappa modificata va eliminata.
final class StopRemoved extends StopSheetResult {
  const StopRemoved();
}

/// Foglio per aggiungere una tappa in coda, o modificare [initial].
///
/// La tappa parte da [start], cioè dalla fine della precedente, il cui nome è
/// [previousName]. Chiede solo il posto e il giorno in cui finisce. Restituisce
/// uno [StopSheetResult], oppure `null` se il foglio si chiude senza scelte.
Future<StopSheetResult?> showStopSheet(
  BuildContext context, {
  required DateTime start,
  required String previousName,
  DraftStop? initial,
}) {
  return showDsFormSheet<StopSheetResult>(
    context,
    builder: (_) =>
        _StopSheet(start: start, previousName: previousName, initial: initial),
  );
}

class _StopSheet extends StatefulWidget {
  final DateTime start;
  final String previousName;
  final DraftStop? initial;

  const _StopSheet({
    required this.start,
    required this.previousName,
    this.initial,
  });

  @override
  State<_StopSheet> createState() => _StopSheetState();
}

class _StopSheetState extends State<_StopSheet> {
  late DraftPlace? _place = widget.initial?.place;
  late DateTime? _end = _initialEnd();

  bool get _editing => widget.initial != null;

  bool get _canSave => _place != null && _end != null;

  /// La fine iniziale vale solo se è dopo l'inizio: altrimenti il foglio
  /// partirebbe da una tappa che non può esistere.
  DateTime? _initialEnd() {
    final initial = widget.initial;
    if (initial == null) return null;
    final end = _dayOnly(initial.end);
    return end.isAfter(_dayOnly(widget.start)) ? end : null;
  }

  Future<void> _pickEnd() async {
    final picked = await showTripEndSheet(
      context,
      start: widget.start,
      initialEnd: _end,
    );
    if (picked == null || !mounted) return;
    setState(() => _end = picked);
  }

  void _save() {
    final place = _place;
    final end = _end;
    if (place == null || end == null) return;
    Navigator.of(
      context,
    ).pop<StopSheetResult>(StopSaved(DraftStop(place: place, end: end)));
  }

  void _remove() {
    Navigator.of(context).pop<StopSheetResult>(const StopRemoved());
  }

  String _formatDay(BuildContext context, DateTime day) =>
      DateFormat('EEE d MMM', context.locale.toString()).format(day);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final end = _end;

    return DsFormSheet(
      title: (_editing ? 'trips.new.stop_edit' : 'trips.new.stop_new').tr(),
      // Il piè sta fuori dallo scroll: la CTA resta visibile anche con la
      // tastiera aperta.
      footer: Padding(
        padding: EdgeInsets.fromLTRB(
          context.spacingMd,
          DsGlassBand.topGap(context),
          context.spacingMd,
          context.spacingMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsButton(
              key: const Key('stop_sheet_save'),
              label: (_editing ? 'trips.new.stop_save' : 'trips.new.stop_add')
                  .tr(),
              icon: _editing ? Icons.check_rounded : Icons.add,
              expand: true,
              onPressed: _canSave ? _save : null,
            ),
            if (_editing)
              DsLinkButton(
                key: const Key('stop_sheet_remove'),
                label: 'trips.new.stop_remove'.tr(),
                onPressed: _remove,
              ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsFieldLabel.prominent('trips.new.where_stop'.tr()),
          PlaceSearch(
            key: const Key('stop_sheet_place'),
            initialText: widget.initial?.place.name,
            onSelected: (place) => setState(() => _place = place),
            // Scrivere dopo la scelta vuol dire un posto
            // diverso da quello mostrato: la scelta decade.
            onTextChanged: (_) {
              if (_place != null) setState(() => _place = null);
            },
          ),
          DsFieldLabel.prominent('trips.new.when'.tr()),
          DsFieldBox(
            key: const Key('stop_sheet_dates'),
            icon: Icons.calendar_today_outlined,
            onTap: _pickEnd,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    end == null
                        ? 'common.tap_to_set_dates'.tr()
                        : '${_formatDay(context, widget.start)}'
                              ' – '
                              '${_formatDay(context, end)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(
                      color: end == null ? cs.onSurfaceVariant : cs.onSurface,
                    ),
                  ),
                ),
                if (end != null)
                  Text(
                    'trips.itinerary.nights'.plural(
                      nightsBetween(widget.start, end) ?? 0,
                    ),
                    style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          // Il ritorno è la fine dell'ultima tappa: vale solo
          // per una tappa aggiunta in coda, non per una modificata.
          if (end != null && !_editing)
            Padding(
              padding: EdgeInsets.only(top: context.spacingSm),
              child: Text(
                'trips.new.stop_hint'.tr(
                  args: [
                    widget.previousName,
                    _formatDay(context, widget.start),
                    _formatDay(context, end),
                  ],
                ),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
