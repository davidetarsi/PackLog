import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'ds_link_button.dart';

/// Errore recuperabile in una sezione: il resto della schermata resta usabile.
class DsInlineError extends StatelessWidget {
  const DsInlineError({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: context.spacingSm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: context.spacingSm),
          child: Icon(
            Icons.info_outline,
            size: context.iconSizeSm,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(width: context.spacingSm),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: context.spacingSm),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        DsLinkButton(
          label: 'common.retry'.tr(),
          icon: Icons.refresh,
          onPressed: onRetry,
        ),
      ],
    ),
  );
}
