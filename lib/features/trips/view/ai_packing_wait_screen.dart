import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_spacing.dart';
import '../providers/ai_packing_run_provider.dart';
import 'widgets/wait/ai_wait_body.dart';
import 'widgets/wait/ai_wait_failure.dart';

export '../model/pack_trip_job.dart';

/// Pagina d'attesa della valigia AI (passaggio: la versione completa arriva
/// con il task successivo). Legge il lavoro dallo stato e non chiama niente.
class AiPackingWaitScreen extends ConsumerWidget {
  const AiPackingWaitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(aiPackingRunProvider);
    final notifier = ref.read(aiPackingRunProvider.notifier);
    ref.listen(aiPackingRunProvider, (_, next) {
      if (next is AiRunDone) {
        context.go('/trips/${next.tripId}?review=1');
        notifier.clear();
      }
    });
    final Widget body;
    switch (run) {
      case AiRunRunning(:final request):
        body = AiWaitBody(
          job: request.job,
          tripId: request.trip.id,
          steps: null,
          cardKey: GlobalKey(),
          onCancel: () {
            notifier.clear();
            context.pop();
          },
        );
      case AiRunFailed(:final request, :final error):
        body = AiWaitFailure(
          failure: error,
          houseId: request.job.houseId,
          onRetry: notifier.retry,
          onClose: () {
            notifier.clear();
            context.pop();
          },
          onGoTo: (location) {
            notifier.clear();
            final router = GoRouter.of(context);
            context.pop();
            router.push(location);
          },
        );
      default:
        body = const SizedBox.shrink();
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
          child: body,
        ),
      ),
    );
  }
}
