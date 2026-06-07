import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/onboarding_state.dart';

part 'post_login_onboarding_provider.g.dart';

@Riverpod(keepAlive: true)
class PostLoginOnboarding extends _$PostLoginOnboarding {
  @override
  Future<OnboardingState> build() async => const OnboardingState();
}
