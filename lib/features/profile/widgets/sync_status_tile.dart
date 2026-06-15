import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_provider.dart';

/// Tile in Profilo che mostra quante modifiche locali sono ancora in attesa
/// di essere pushate al cloud e offre un pulsante "Riprova" per forzare un
/// nuovo giro di [SyncOrchestrator.requestSync].
class SyncStatusTile extends ConsumerWidget {
  const SyncStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingChangesCountProvider);

    return pendingAsync.when(
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
        subtitle: Text(e.toString()),
      ),
      data: (count) {
        final synced = count == 0;
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
                : 'profile.sync_status_pending'.tr(args: [count.toString()]),
          ),
          trailing: synced
              ? null
              : TextButton(
                  onPressed: () {
                    ref.read(syncOrchestratorProvider).requestSync();
                    ref.invalidate(pendingChangesCountProvider);
                  },
                  child: Text('profile.sync_status_retry'.tr()),
                ),
        );
      },
    );
  }
}
