import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DsQuantityBadge
// ─────────────────────────────────────────────────────────────────────────────

/// Quantità ("xN" o "xN/M") resa come testo semplice, senza riquadro.
///
/// Non è più un badge con fill: la quantità è un dato di lettura, non uno
/// stato scelto né un'azione, e su una lista lunga i riquadri diventavano la
/// cosa più evidente della schermata. Il nome resta per non toccare i
/// chiamanti.
///
/// ```dart
/// DsQuantityBadge(current: 3)            // → "x3"
/// DsQuantityBadge(current: 2, max: 5)    // → "x2/5"
/// DsQuantityBadge(current: 3, isSelected: true) // testo in primary
/// ```
class DsQuantityBadge extends StatelessWidget {
  /// Quantità corrente.
  final int current;

  /// Quantità massima opzionale: se fornita, mostra "xN/M".
  final int? max;

  /// Semantica "item selezionato/in lista": colora il testo con l'accento
  /// invece del grigio dei metadati.
  final bool isSelected;

  const DsQuantityBadge({
    super.key,
    required this.current,
    this.max,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // "x1" su un oggetto singolo non informa: è il caso implicito, e ripetuto
    // su ogni riga diventa la voce più frequente della schermata. La quantità
    // compare solo quando dice qualcosa — più di uno, oppure una frazione
    // rispetto a un massimo.
    if (current == 1 && max == null) return const SizedBox.shrink();

    final showPartial = max != null && current > 0 && current < max!;
    final text = showPartial ? 'x$current/$max' : 'x$current';

    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: isSelected ? cs.primary : cs.onSurfaceVariant,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DsStatusBadgeType
// ─────────────────────────────────────────────────────────────────────────────

/// Tipo semantico per [DsStatusBadge]. Determina la palette colori.
enum DsStatusBadgeType {
  /// Item in viaggio → `tertiary / onTertiary`
  onTrip,

  /// Item ospite/temporaneo → `itemTemporary` dell'AppColorsExtension
  temporary,

  /// Entità principale (casa primaria) → `primaryContainer / onPrimaryContainer`
  primary,

  /// Stato completato/successo → `success` dell'AppColorsExtension
  success,
}

// ─────────────────────────────────────────────────────────────────────────────
// DsStatusBadge
// ─────────────────────────────────────────────────────────────────────────────

/// Badge semantico per stati di item o entità ("In viaggio", "Ospite",
/// "Principale", "Completato"). Sostituisce [OnTripBadge], [TemporaryBadge]
/// e il privato `_Badge` di `HousesScreen`.
///
/// ```dart
/// DsStatusBadge(type: DsStatusBadgeType.onTrip, label: 'common.in_transit'.tr())
/// DsStatusBadge(type: DsStatusBadgeType.temporary, label: 'common.temporary'.tr())
/// DsStatusBadge.onTrip()        // shortcut con label tradotta
/// DsStatusBadge.temporary()     // shortcut con label tradotta
/// ```
class DsStatusBadge extends StatelessWidget {
  final DsStatusBadgeType type;
  final String label;
  final IconData? icon;

  const DsStatusBadge({
    super.key,
    required this.type,
    required this.label,
    this.icon,
  });

  /// Shortcut "In viaggio".
  factory DsStatusBadge.onTrip({Key? key, IconData? icon}) => DsStatusBadge(
    key: key,
    type: DsStatusBadgeType.onTrip,
    label: 'common.in_transit'.tr(),
    icon: icon,
  );

  /// Shortcut "Temporaneo/Ospite".
  factory DsStatusBadge.temporary({Key? key, IconData? icon}) => DsStatusBadge(
    key: key,
    type: DsStatusBadgeType.temporary,
    label: 'common.temporary'.tr(),
    icon: icon,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColorsExtension>();

    late final Color bg;
    late final Color fg;

    switch (type) {
      case DsStatusBadgeType.onTrip:
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
      case DsStatusBadgeType.temporary:
        bg = appColors?.itemTemporaryBackground ?? cs.primaryContainer;
        fg = appColors?.itemTemporaryText ?? cs.onPrimaryContainer;
      case DsStatusBadgeType.primary:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
      case DsStatusBadgeType.success:
        bg = appColors?.successContainer ?? cs.tertiaryContainer;
        fg = appColors?.onSuccessContainer ?? cs.onTertiaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DsInfoBadge
// ─────────────────────────────────────────────────────────────────────────────

/// Badge informativo (icona + testo) senza fill. Sostituisce il privato
/// `_Badge` di `TripInfoBadges`.
///
/// Usato per metadati del viaggio: date, destinazione, bagagli.
///
/// ```dart
/// DsInfoBadge(icon: Icons.calendar_today_outlined, label: '12 Giu - 18 Giu')
/// DsInfoBadge(icon: Icons.place, label: 'Milano')
/// ```
class DsInfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const DsInfoBadge({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            // bodyMedium e non bodyLarge: sono metadati (date, destinazione,
            // bagagli), non testo di contenuto. A 16 occupavano la stessa
            // taglia del corpo e mandavano a capo il Wrap della card viaggio.
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
