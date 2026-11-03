import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_button.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../services/pack_trip_service.dart';

/// Cosa fare quando `pack-trip` non riesce: testi e uscite di ogni errore.
class AiWaitFailure extends StatelessWidget {
  const AiWaitFailure({
    super.key,
    required this.failure,
    required this.onRetry,
    required this.onClose,
    required this.onGoTo,
    required this.houseId,
  });

  final Object failure;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  /// Chiude la pagina e apre il percorso dato.
  final void Function(String location) onGoTo;
  final String houseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String title;
    final String body;
    final String primaryLabel;
    final VoidCallback primaryAction;
    var showExit = true;

    switch (failure) {
      case PackTripCreditsException():
        title = 'trips.ai.error.credits_title'.tr();
        body = 'trips.ai.error.credits_body'.tr();
        primaryLabel = 'trips.ai.error.credits_action'.tr();
        primaryAction = () => onGoTo('/profile');
      case PackTripEmptyWardrobeException():
        title = 'trips.ai.error.empty_title'.tr();
        body = 'trips.ai.error.empty_body'.tr();
        primaryLabel = 'trips.ai.error.empty_action'.tr();
        primaryAction = () => onGoTo('/houses/$houseId');
      case PackTripWardrobeTooLargeException():
        // Un'unica uscita: è anche l'azione principale.
        title = 'trips.ai.error.too_large_title'.tr();
        body = 'trips.ai.error.too_large_body'.tr();
        primaryLabel = 'common.close'.tr();
        primaryAction = onClose;
        showExit = false;
      default:
        title = 'trips.ai.error.generic_title'.tr();
        body = 'trips.ai.error.generic_body'.tr();
        primaryLabel = 'common.retry'.tr();
        primaryAction = onRetry;
    }

    return Column(
      children: [
        const Spacer(),
        Icon(
          Icons.error_outline,
          size: context.iconSizeXl,
          color: colorScheme.onSurfaceVariant,
        ),
        SizedBox(height: context.spacingLg),
        Text(title, style: theme.textTheme.headlineSmall?.title),
        SizedBox(height: context.spacingSm),
        Text(
          body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        DsButton(label: primaryLabel, onPressed: primaryAction, expand: true),
        if (showExit)
          SizedBox(
            width: double.infinity,
            child: DsTextButton(onPressed: onClose, label: 'common.close'.tr()),
          ),
        SizedBox(height: context.spacingXl),
      ],
    );
  }
}
