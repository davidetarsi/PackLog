import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/cta_reserved_space.dart';
import '../../model/trip_date_range.dart';
import '../../../../shared/theme/app_text_styles.dart';

/// Diametro del cerchio di un giorno selezionato o di "oggi".
const double _dayCellSize = 36;

/// Altezza di una riga della griglia dei giorni. La stima dello scroll dei
/// mesi (_monthHeight) la usa nello stesso modo: cambiarla altera lo scroll.
const double _weekRowHeight = 40;

// ─────────────────────────────────────────────────────────────────────────────
// TripCalendar
// ─────────────────────────────────────────────────────────────────────────────

/// Calendario a scorrimento (lazy, 24 mesi) per scegliere le date di un viaggio.
///
/// È un componente senza logica di selezione: mostra [selection] e segnala il
/// giorno toccato con [onDaySelected]. La regola di selezione sta nel
/// chiamante (es. [DateRangeSelectionNotifier] o il foglio della fine).
///
/// - [initialMonth]: mese a cui scorrere all'apertura. Se null, il mese
///   corrente.
/// - [firstSelectableDay]: i giorni prima di questa data sono spenti e non
///   toccabili (oltre ai giorni passati, che restano selezionabili).
class TripCalendar extends StatefulWidget {
  final TripDateRange selection;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime? initialMonth;
  final DateTime? firstSelectableDay;

  const TripCalendar({
    super.key,
    required this.selection,
    required this.onDaySelected,
    this.initialMonth,
    this.firstSelectableDay,
  });

  @override
  State<TripCalendar> createState() => _TripCalendarState();
}

class _TripCalendarState extends State<TripCalendar> {
  late final ScrollController _scrollController;
  late final DateTime _startMonth;
  late final int _itemCount;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    // Finestra di default: 12 mesi indietro
    final defaultStartMonth = DateTime(now.year, now.month - 12, 1);

    // Se il mese iniziale è antecedente alla finestra di default, estendi
    final initial = widget.initialMonth;
    final initialMonthStart = initial != null
        ? DateTime(initial.year, initial.month, 1)
        : null;
    _startMonth =
        (initialMonthStart != null &&
            initialMonthStart.isBefore(defaultStartMonth))
        ? initialMonthStart
        : defaultStartMonth;

    // Fine: sempre 24 mesi dal mese corrente
    final endMonth = DateTime(now.year, now.month + 24, 1);
    _itemCount = _monthDiff(_startMonth, endMonth);

    // Mese target per lo scroll iniziale
    final targetMonth = initialMonthStart ?? currentMonth;
    final targetIndex = _monthDiff(_startMonth, targetMonth);

    _scrollController = ScrollController(
      initialScrollOffset: _estimatedOffset(targetIndex),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Differenza in mesi tra due date (b - a), assunzione b >= a
  static int _monthDiff(DateTime a, DateTime b) =>
      (b.year - a.year) * 12 + (b.month - a.month);

  /// Stima l'offset in pixel fino all'inizio del mese all'indice [targetIndex].
  ///
  /// Usa le costanti base di AppSpacing (non responsive) — la precisione è
  /// sufficiente per uno scroll iniziale "vicino al target".
  ///
  /// Fissi di proposito: servono a calcolare l'altezza dei mesi per lo scroll.
  double _estimatedOffset(int targetIndex) {
    // Padding top del ListView
    double offset = AppSpacing.md;
    for (int i = 0; i < targetIndex; i++) {
      final month = DateTime(_startMonth.year, _startMonth.month + i, 1);
      offset += _monthHeight(month);
    }
    return offset;
  }

  /// Altezza stimata di un mese basata sulla struttura di [_MonthView]:
  ///
  ///   header text (fontLg ≈ 28px con line-height) + paddingBottom(md=16)
  ///   + weekday row (~18px, fontXxs=12)
  ///   + spacer (xs=4)
  ///   + N rows × _weekRowHeight(40) + (N-1) × rowSpacing(xs=4)
  ///   + bottom padding (xl=32)
  static double _monthHeight(DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((month.weekday - 1 + daysInMonth) / 7).ceil();

    const double headerText = 28; // fontLg 20 × ~1.4 line-height
    const double headerBottomPadding = AppSpacing.md; // 16
    const double weekdayRow = 18; // fontXxs 12 × ~1.5 line-height
    const double spacerAfterWeekdays = AppSpacing.xs; // 4
    const double rowSpacing =
        AppSpacing.xs; // 4, tra le righe (non dopo l'ultima)
    const double monthBottomPadding = AppSpacing.xl; // 32

    return headerText +
        headerBottomPadding +
        weekdayRow +
        spacerAfterWeekdays +
        rows * _weekRowHeight +
        (rows - 1) * rowSpacing +
        monthBottomPadding;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        context.spacingMd,
        context.spacingMd,
        context.spacingXl + context.ctaReservedHeight,
      ),
      itemCount: _itemCount,
      itemBuilder: (_, index) {
        final month = DateTime(_startMonth.year, _startMonth.month + index, 1);
        return _MonthView(
          month: month,
          today: today,
          selection: widget.selection,
          firstSelectableDay: widget.firstSelectableDay,
          onDayTap: widget.onDaySelected,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MonthView — header + griglia giorni di un singolo mese
// ─────────────────────────────────────────────────────────────────────────────

class _MonthView extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final TripDateRange selection;
  final DateTime? firstSelectableDay;
  final ValueChanged<DateTime> onDayTap;

  const _MonthView({
    required this.month,
    required this.today,
    required this.selection,
    required this.firstSelectableDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Month/Year header ─────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(bottom: context.spacingMd),
            child: Text(
              DateFormat.yMMMM(locale).format(month),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: cs.onSurface),
            ),
          ),

          // ── Weekday labels (Mon-first) ────────────────────────────────
          _WeekdayHeader(locale: locale),

          SizedBox(height: context.spacingXs),

          // ── Days grid ─────────────────────────────────────────────────
          _DaysGrid(
            month: month,
            today: today,
            selection: selection,
            firstSelectableDay: firstSelectableDay,
            onDayTap: onDayTap,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WeekdayHeader — riga etichette L M M G V S D
// ─────────────────────────────────────────────────────────────────────────────

class _WeekdayHeader extends StatelessWidget {
  final String locale;

  const _WeekdayHeader({required this.locale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Genera le etichette dei giorni in locale usando una settimana nota
    // che inizia di lunedì (2 gennaio 2023 = lunedì)
    final monday = DateTime(2023, 1, 2);
    final labels = List.generate(
      7,
      (i) => DateFormat.E(
        locale,
      ).format(monday.add(Duration(days: i))).substring(0, 1).toUpperCase(),
    );

    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DaysGrid — griglia settimane di un mese
// ─────────────────────────────────────────────────────────────────────────────

class _DaysGrid extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final TripDateRange selection;
  final DateTime? firstSelectableDay;
  final ValueChanged<DateTime> onDayTap;

  const _DaysGrid({
    required this.month,
    required this.today,
    required this.selection,
    required this.firstSelectableDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    // Giorni nel mese
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Offset: quante celle vuote prima del giorno 1
    // (weekday: 1=lun, 7=dom → 0-indexed offset = weekday - 1)
    final offset = month.weekday - 1;

    final totalCells = offset + daysInMonth;
    final numRows = (totalCells / 7).ceil();
    final limit = firstSelectableDay;

    return Column(
      children: List.generate(numRows, (row) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: row < numRows - 1 ? context.spacingXs : 0,
          ),
          child: Row(
            children: List.generate(7, (col) {
              final dayIndex = row * 7 + col - offset;
              if (dayIndex < 0 || dayIndex >= daysInMonth) {
                return const Expanded(child: SizedBox.shrink());
              }
              final date = DateTime(month.year, month.month, dayIndex + 1);
              final isPast = date.isBefore(today);
              final isDisabled =
                  limit != null &&
                  date.isBefore(DateTime(limit.year, limit.month, limit.day));
              return Expanded(
                child: _DayCell(
                  date: date,
                  today: today,
                  selection: selection,
                  isPast: isPast,
                  isDisabled: isDisabled,
                  isFirstOfRow: col == 0,
                  isLastOfRow: col == 6,
                  // I giorni passati rimangono selezionabili per permettere
                  // la modifica di viaggi già avvenuti. Quelli prima di
                  // [firstSelectableDay] invece no.
                  onTap: isDisabled ? null : () => onDayTap(date),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DayCell — singola cella giorno con evidenziazione range
// ─────────────────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final TripDateRange selection;
  final bool isPast;
  final bool isDisabled;
  final bool isFirstOfRow;
  final bool isLastOfRow;
  final VoidCallback? onTap;

  const _DayCell({
    required this.date,
    required this.today,
    required this.selection,
    required this.isPast,
    required this.isDisabled,
    required this.isFirstOfRow,
    required this.isLastOfRow,
    this.onTap,
  });

  bool get _isToday =>
      date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;

  bool get _isDeparture =>
      selection.departureDate != null &&
      _isSameDay(date, selection.departureDate!);

  bool get _isReturn =>
      selection.returnDate != null && _isSameDay(date, selection.returnDate!);

  bool get _isInRange {
    final dep = selection.departureDate;
    final ret = selection.returnDate;
    if (dep == null || ret == null) return false;
    return date.isAfter(dep) && date.isBefore(ret);
  }

  /// Chiave stabile per giorno, usata dai test e dagli strumenti di debug.
  static final _keyFormat = DateFormat('yyyy-MM-dd');

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final base = Theme.of(context).textTheme.bodyMedium;
    final isSelected = _isDeparture || _isReturn;
    final inRange = _isInRange;
    final showRangeBg = isSelected || inRange;

    // Il range strip si arrotonda solo agli estremi (o ai bordi di riga)
    final isRangeLeftRounded = _isDeparture || (inRange && isFirstOfRow);
    final isRangeRightRounded = _isReturn || (inRange && isLastOfRow);

    // Un giorno spento resta leggibile come partenza se è il giorno scelto.
    final muted = isPast || (isDisabled && !isSelected);

    // Colore testo
    final textColor = muted
        ? cs.onSurface.withValues(alpha: 0.38)
        : isSelected
        ? cs.onPrimary
        : inRange
        ? cs.onPrimaryContainer
        : cs.onSurface;

    return GestureDetector(
      key: ValueKey('trip_calendar_day_${_keyFormat.format(date)}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: _weekRowHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Range background strip ─────────────────────────────────
            if (showRangeBg)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.horizontal(
                      left: isRangeLeftRounded
                          ? const Radius.circular(AppConstants.pillBorderRadius)
                          : Radius.zero,
                      right: isRangeRightRounded
                          ? const Radius.circular(AppConstants.pillBorderRadius)
                          : Radius.zero,
                    ),
                  ),
                ),
              ),

            // ── Cerchio pieno per i giorni selezionati (start/end) ─────
            if (isSelected)
              Container(
                width: _dayCellSize,
                height: _dayCellSize,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),

            // ── Anello "oggi" (solo se non selezionato) ────────────────
            if (_isToday && !isSelected)
              Container(
                width: _dayCellSize,
                height: _dayCellSize,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: cs.primary,
                    width: AppConstants.selectedBorderWidth,
                  ),
                  shape: BoxShape.circle,
                ),
              ),

            // ── Numero del giorno ──────────────────────────────────────
            Text(
              '${date.day}',
              style: (isSelected ? base?.strong : base)?.copyWith(
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
