import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tour/model/onboarding_state.dart';
import '../../tour/providers/post_login_onboarding_provider.dart';
import '../providers/house_provider.dart';
import '../view/add_edit_house_screen.dart';

/// Apre il form "nuova casa". Se il tour è sullo step `houseTooltip` e una
/// casa viene davvero creata, avanza il tour.
Future<void> createHouseWithTourAdvance(
  BuildContext context,
  WidgetRef ref,
) async {
  final onboardingStep = ref
      .read(postLoginOnboardingProvider)
      .valueOrNull
      ?.step;
  final housesBefore = ref.read(houseNotifierProvider).valueOrNull?.length ?? 0;

  await showAddEditHouseSheet(context);

  if (!context.mounted) return;
  if (onboardingStep == OnboardingStep.houseTooltip) {
    final housesAfter =
        ref.read(houseNotifierProvider).valueOrNull?.length ?? 0;
    if (housesAfter > housesBefore) {
      await ref.read(postLoginOnboardingProvider.notifier).advance();
    }
  }
}
