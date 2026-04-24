import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/helpers/bottom_sheet_handle.dart';
import '../../../shared/theme/app_spacing.dart';
import '../model/trip_model.dart';

/// Mostra un bottom sheet di anteprima prima di avviare la generazione AI.
///
/// Espone all'utente:
///  - Scopo del Viaggio (primaryVibe)
///  - Attività Extra (extraEvents)
///  - Meteo previsto (weatherTags)
///
/// Se alcuni campi non sono compilati, suggerisce all'utente di integrarli
/// modificando il viaggio per ottenere risultati più accurati.
Future<void> showSmartPackingPreviewSheet(
  BuildContext context, {
  required TripModel trip,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => SmartPackingPreviewSheet(trip: trip),
  );
}

class SmartPackingPreviewSheet extends StatelessWidget {
  final TripModel trip;

  const SmartPackingPreviewSheet({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasVibe = trip.primaryVibe != null && trip.primaryVibe!.isNotEmpty;
    final hasEvents = trip.extraEvents.isNotEmpty;
    final isMissingContext = !hasVibe;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle + header
            Center(child: const BottomSheetHandle()),
            const SizedBox(height: AppSpacing.sm),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: colorScheme.secondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Packing AI',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Contesto che verrà usato per la generazione',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Context sections
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Scopo del Viaggio ──────────────────────────────────
                  _SectionLabel(
                    label: 'Scopo del Viaggio',
                    icon: Icons.flag_outlined,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (hasVibe)
                    _ContextChip(
                      label: trip.primaryVibe!,
                      colorScheme: colorScheme,
                      filled: true,
                    )
                  else
                    _MissingHint(
                      text: 'Non impostato — modifica il viaggio per risultati migliori',
                      colorScheme: colorScheme,
                    ),

                  const SizedBox(height: AppSpacing.md),

                  // ── Attività Extra ─────────────────────────────────────
                  _SectionLabel(
                    label: 'Attività Extra',
                    icon: Icons.local_activity_outlined,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (hasEvents)
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: trip.extraEvents
                          .map(
                            (e) => _ContextChip(
                              label: e,
                              colorScheme: colorScheme,
                            ),
                          )
                          .toList(),
                    )
                  else
                    _MissingHint(
                      text: 'Nessuna attività selezionata',
                      colorScheme: colorScheme,
                    ),

                ],
              ),
            ),

            // Warning banner if missing critical context
            if (isMissingContext)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Aggiungere lo scopo del viaggio migliora la qualità dei suggerimenti',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.md),

            // CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: FilledButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Genera Lista con AI'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/trips/${trip.id}/smart-packing');
                },
              ),
            ),

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final ColorScheme colorScheme;

  const _SectionLabel({
    required this.label,
    required this.icon,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
        ),
      ],
    );
  }
}

class _ContextChip extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;
  final bool filled;
  final IconData? icon;

  const _ContextChip({
    required this.label,
    required this.colorScheme,
    this.filled = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: icon != null
          ? Icon(icon, size: 14, color: colorScheme.onSecondaryContainer)
          : null,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: filled ? FontWeight.w600 : FontWeight.normal,
          color: filled
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
      backgroundColor: filled
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MissingHint extends StatelessWidget {
  final String text;
  final ColorScheme colorScheme;

  const _MissingHint({required this.text, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.4),
            fontStyle: FontStyle.italic,
          ),
    );
  }
}
