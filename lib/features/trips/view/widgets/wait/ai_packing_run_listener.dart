import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../shared/helpers/snack_bar_helper.dart';
import '../../../providers/ai_packing_run_provider.dart';
import '../../../services/ai_failure_message.dart';

/// L'avviso globale del lavoro AI, sopra tutte le pagine. Quando il lavoro
/// finisce e nessuna pagina d'attesa lo sta mostrando, dice com'è andata con
/// uno SnackBar sul `ScaffoldMessenger` della radice e azzera il lavoro. Mai
/// navigazioni forzate: chi vuole la valigia tocca "Apri".
///
/// Con la pagina d'attesa attaccata non fa niente: è lei a navigare e ad
/// azzerare.
class AiPackingRunListener extends ConsumerWidget {
  const AiPackingRunListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(aiPackingRunProvider, (previous, next) {
      final run = ref.read(aiPackingRunProvider.notifier);
      if (run.attached) return;
      switch (next) {
        case AiRunDone():
          final title = switch (previous) {
            AiRunRunning(:final request) => request.job.title,
            _ => '',
          };
          _showReady(context, ref, next, title);
          run.clear();
        case AiRunFailed(:final error):
          AppSnackBar.showError(context, aiFailureMessageKey(error).tr());
          run.clear();
        case AiRunIdle() || AiRunRunning():
          break;
      }
    });
    return child;
  }

  void _showReady(
    BuildContext context,
    WidgetRef ref,
    AiRunDone done,
    String title,
  ) {
    // L'errore dura qualche secondo; "Apri" resta finché non si tocca, per
    // questo viene dopo.
    if (done.itemsError) {
      AppSnackBar.showError(context, 'trips.pack.ai.items_error'.tr());
    }
    AppSnackBar.showAction(
      context,
      'trips.ai.ready'.tr(args: [title]),
      actionLabel: 'trips.ai.open'.tr(),
      onAction: () =>
          ref.read(appRouterProvider).go('/trips/${done.tripId}?review=1'),
      queue: done.itemsError,
    );
  }
}
