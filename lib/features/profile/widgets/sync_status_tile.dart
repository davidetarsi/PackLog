import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_provider.dart';
import '../../../shared/helpers/exception_message.dart';

/// Tile in Profilo che mostra quante modifiche locali sono ancora in attesa
/// di essere pushate al cloud e offre un pulsante "Riprova" per forzare un
/// nuovo giro di [SyncOrchestrator.requestSync].
class SyncStatusTile extends ConsumerWidget {
  const SyncStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalUnsyncedAsync = ref.watch(totalUnsyncedCountProvider);
    final isPushInProgress = ref.watch(syncPushInProgressProvider);

    return totalUnsyncedAsync.when(
      // skipLoadingOnReload mantiene il valore precedente durante i reload
      // (es. dopo onProcessQueueComplete) evitando qualsiasi flash.
      skipLoadingOnReload: true,
      loading: () => ListTile(
        leading: const Icon(Icons.cloud_sync_outlined),
        title: Text('profile.sync_status_title'.tr()),
        trailing: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => ListTile(
        leading: Icon(
          Icons.cloud_off_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text('profile.sync_status_title'.tr()),
        subtitle: Text(exceptionMessage(e)),
      ),
      data: (totalUnsynced) {
        final synced = totalUnsynced == 0;

        final Widget? trailing = switch ((synced, isPushInProgress)) {
          (true, _) => null,
          (false, true) => const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          (false, false) => TextButton(
            onPressed: () =>
                ref.read(syncOrchestratorProvider).requestForcedSync(),
            child: Text('profile.sync_status_retry'.tr()),
          ),
        };

        return ListTile(
          leading: Icon(
            synced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
            color: synced
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.tertiary,
          ),
          title: Text('profile.sync_status_title'.tr()),
          subtitle: Text(
            synced
                ? 'profile.sync_status_synced'.tr()
                : 'profile.sync_status_pending'.tr(
                    args: [totalUnsynced.toString()],
                  ),
          ),
          trailing: trailing,
        );
      },
    );
  }
}
