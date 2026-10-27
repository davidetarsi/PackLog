import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_form_sheet.dart';
import '../../../model/ai_packing.dart';

/// Le due righe sotto il titolo della valigia AI: "Cosa manca a questo viaggio"
/// (avvisi, in ambra) e "Perché queste scelte" (motivi, neutra). Ognuna apre
/// il suo foglio.
class AiPackRows extends StatelessWidget {
  const AiPackRows({
    super.key,
    required this.warnings,
    required this.reasons,
    required this.onSearch,
    required this.onDismiss,
  });

  /// Avvisi ancora aperti (senza quelli chiusi con "Ok, capito").
  final List<AiWarning> warnings;

  /// Motivi, nell'ordine ricevuto da `pack-trip`.
  final List<AiReasonPoint> reasons;

  /// "Cerca nell'armadio": riceve la query dell'avviso, dopo che il foglio si
  /// è chiuso.
  final ValueChanged<String> onSearch;

  /// "Ok, capito": riceve l'id dell'avviso chiuso.
  final ValueChanged<String> onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasWarnings = warnings.isNotEmpty;
    final reasonTitles = [for (final reason in reasons.take(4)) reason.title];

    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Row(
            key: const Key('pack_row_missing'),
            icon: hasWarnings ? Icons.warning_amber_rounded : Icons.check,
            iconColor: hasWarnings
                ? context.appColors.warning
                : cs.onSurfaceVariant,
            title: hasWarnings
                ? 'trips.pack.ai.missing_row'.tr()
                : 'trips.pack.ai.nothing_missing'.tr(),
            titleColor: hasWarnings ? cs.onSurface : cs.onSurfaceVariant,
            subtitle: hasWarnings
                ? warnings.map((warning) => warning.title).join(' · ')
                : 'trips.pack.ai.nothing_missing_hint'.tr(),
            trailing: hasWarnings ? _CountBadge(count: warnings.length) : null,
            onTap: () => _openWarnings(context),
          ),
          Divider(
            height: 1,
            // Allineato al titolo: margine, icona e spazio dopo l'icona.
            indent: context.spacingMd * 2 + context.iconSizeMd,
            color: cs.outlineVariant,
          ),
          _Row(
            key: const Key('pack_row_reasons'),
            icon: Icons.lightbulb_outline,
            iconColor: cs.onSurfaceVariant,
            title: 'trips.pack.ai.reasons_row'.tr(),
            titleColor: cs.onSurface,
            subtitle: reasonTitles.isEmpty ? null : reasonTitles.join(', '),
            onTap: () => _openReasons(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openWarnings(BuildContext context) => showDsFormSheet<void>(
    context,
    builder: (_) => _WarningsSheet(
      warnings: warnings,
      onSearch: onSearch,
      onDismiss: onDismiss,
    ),
  );

  Future<void> _openReasons(BuildContext context) => showDsFormSheet<void>(
    context,
    builder: (_) => _ReasonsSheet(reasons: reasons),
  );
}

/// Una riga del gruppo: icona, titolo, sottotitolo, e a destra un'aggiunta
/// facoltativa e la freccia.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMd,
          vertical: context.spacingMd,
        ),
        child: Row(
          children: [
            Icon(icon, size: context.iconSizeMd, color: iconColor),
            SizedBox(width: context.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.bodyLarge?.strong.copyWith(color: titleColor),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: context.spacingXs / 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: context.spacingSm),
              trailing!,
            ],
            SizedBox(width: context.spacingXs),
            Icon(
              Icons.chevron_right,
              size: context.iconSizeSm,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Il numero degli avvisi, in ambra e con il contorno.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final warning = context.appColors.warning;
    final tt = Theme.of(context).textTheme;
    return Container(
      constraints: BoxConstraints(
        minWidth: context.iconSizeMd,
        minHeight: context.iconSizeMd,
      ),
      padding: EdgeInsets.symmetric(horizontal: context.spacingXs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
        border: Border.all(
          color: warning,
          width: AppConstants.emphasisBorderWidth,
        ),
      ),
      child: Text(
        '$count',
        style: tt.labelMedium?.strong.copyWith(color: warning),
      ),
    );
  }
}

/// Il foglio degli avvisi: un riquadro per avviso. "Ok, capito" lo toglie dal
/// foglio e lo chiude nella pagina; "Cerca nell'armadio" chiude il foglio e
/// scrive la ricerca.
class _WarningsSheet extends StatefulWidget {
  const _WarningsSheet({
    required this.warnings,
    required this.onSearch,
    required this.onDismiss,
  });

  final List<AiWarning> warnings;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onDismiss;

  @override
  State<_WarningsSheet> createState() => _WarningsSheetState();
}

class _WarningsSheetState extends State<_WarningsSheet> {
  late final List<AiWarning> _open = [...widget.warnings];

  void _dismiss(AiWarning warning) {
    setState(() => _open.removeWhere((w) => w.id == warning.id));
    widget.onDismiss(warning.id);
  }

  void _search(String query) {
    final onSearch = widget.onSearch;
    Navigator.pop(context);
    onSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return DsFormSheet(
      title: 'trips.pack.ai.missing_row'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_open.isEmpty)
            Text(
              'trips.pack.ai.nothing_missing_sheet'.tr(),
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          for (final warning in _open) ...[
            _WarningCard(
              warning: warning,
              onSearch: _search,
              onDismiss: () => _dismiss(warning),
            ),
            SizedBox(height: context.spacingMd),
          ],
        ],
      ),
    );
  }
}

/// Un avviso: livello ("Importante" in ambra), titolo, perché, e i bottoni.
class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.warning,
    required this.onSearch,
    required this.onDismiss,
  });

  final AiWarning warning;
  final ValueChanged<String> onSearch;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final search = warning.search?.trim();
    // Solo "Importante" in ambra: "Utile" resta grigio, così il livello si
    // legge prima del testo.
    final (levelKey, levelColor) = switch (warning.level) {
      AiWarningLevel.important => (
        'trips.pack.ai.level_important',
        context.appColors.warning,
      ),
      AiWarningLevel.useful => (
        'trips.pack.ai.level_useful',
        cs.onSurfaceVariant,
      ),
    };

    return Container(
      padding: EdgeInsets.all(context.spacingMd),
      decoration: BoxDecoration(
        color: context.groupSurface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            levelKey.tr(),
            style: tt.labelLarge?.strong.copyWith(color: levelColor),
          ),
          SizedBox(height: context.spacingXs),
          Text(warning.title, style: tt.titleMedium?.title),
          SizedBox(height: context.spacingXs),
          Text(warning.why, style: tt.bodyMedium),
          SizedBox(height: context.spacingMd),
          Wrap(
            spacing: context.spacingSm,
            runSpacing: context.spacingSm,
            children: [
              if (search != null && search.isNotEmpty)
                _NeutralButton(
                  key: Key('ai_warning_search_${warning.id}'),
                  label: 'trips.pack.ai.warning_search'.tr(),
                  onPressed: () => onSearch(search),
                  foreground: cs.onSurface,
                  border: cs.outline,
                ),
              _NeutralButton(
                key: Key('ai_warning_dismiss_${warning.id}'),
                label: 'trips.pack.ai.warning_dismiss'.tr(),
                onPressed: onDismiss,
                foreground: cs.onSurfaceVariant,
                border: cs.outlineVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottone a contorno, neutro: mai arancio.
class _NeutralButton extends StatelessWidget {
  const _NeutralButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.foreground,
    required this.border,
  });

  final String label;
  final VoidCallback onPressed;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: foreground,
      shape: const StadiumBorder(),
      side: BorderSide(color: border),
    ),
    child: Text(label),
  );
}

/// Il foglio dei motivi: un punto per motivo, nell'ordine ricevuto.
class _ReasonsSheet extends StatelessWidget {
  const _ReasonsSheet({required this.reasons});

  final List<AiReasonPoint> reasons;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DsFormSheet(
      title: 'trips.pack.ai.reasons_row'.tr(),
      child: reasons.isEmpty
          ? Text(
              'trips.pack.ai.reasons_none'.tr(),
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final point in reasons)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.spacingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(point.title, style: tt.titleMedium?.title),
                        SizedBox(height: context.spacingXs),
                        for (final sentence in point.sentences)
                          Text(sentence, style: tt.bodyMedium),
                        if (point.items.isNotEmpty) ...[
                          SizedBox(height: context.spacingXs),
                          Text(
                            point.items.join(' · '),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
