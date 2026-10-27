import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_provider.dart';
import '../../../shared/widgets/ds_link_button.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_settings.dart';
import '../../../shared/widgets/ds_text_button.dart';
import 'sync_details_dialog.dart';

/// Riga del Profilo con lo stato della sincronizzazione: quante modifiche
/// locali aspettano ancora il cloud, con "Riprova ora" per forzare un nuovo
/// giro di [SyncOrchestrator.requestSync].
///
/// Sta in un [DsSettingsGroup] come le altre righe. Quando è tutto a posto la
/// nuvola è grigia: è un'informazione, non un'azione. Il colore arriva solo
/// quando c'è qualcosa da fare.
class SyncStatusTile extends ConsumerWidget {
  const SyncStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final totalUnsyncedAsync = ref.watch(totalUnsyncedCountProvider);
    final isPushInProgress = ref.watch(syncPushInProgressProvider);
    final spinner = SizedBox.square(
      dimension: context.iconSizeSm,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );

    return totalUnsyncedAsync.when(
      // skipLoadingOnReload mantiene il valore precedente durante i reload
      // (es. dopo onProcessQueueComplete) evitando qualsiasi flash.
      skipLoadingOnReload: true,
      loading: () => DsSettingsRow(
        label: 'profile.sync_status_title'.tr(),
        trailing: spinner,
      ),
      error: (e, _) => DsSettingsRow(
        label: 'profile.sync_status_title'.tr(),
        subtitle: 'errors.load_failed'.tr(),
        leading: Icon(
          Icons.cloud_off_outlined,
          size: context.iconSizeSm,
          color: cs.onSurfaceVariant,
        ),
        trailing: DsLinkButton(
          label: 'common.retry'.tr(),
          icon: Icons.refresh,
          onPressed: () => ref.invalidate(totalUnsyncedCountProvider),
        ),
      ),
      data: (totalUnsynced) {
        if (totalUnsynced == 0) {
          return DsSettingsRow(
            label: 'profile.sync_status_title'.tr(),
            subtitle: 'profile.sync_status_synced'.tr(),
            trailing: Icon(
              Icons.cloud_done_outlined,
              size: context.iconSizeSm,
              color: cs.onSurfaceVariant,
            ),
          );
        }
        return DsSettingsRow(
          label: 'profile.sync_status_title'.tr(),
          subtitle: 'profile.sync_status_pending'.tr(
            args: [totalUnsynced.toString()],
          ),
          trailing: isPushInProgress
              ? spinner
              : DsTextButton(
                  onPressed: () =>
                      ref.read(syncOrchestratorProvider).requestForcedSync(),
                  icon: Icons.cloud_upload_outlined,
                  label: 'profile.sync_status_retry'.tr(),
                ),
          onTap: () => SyncDetailsDialog.show(context),
        );
      },
    );
  }
}
