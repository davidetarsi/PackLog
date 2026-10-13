import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/sync/sync_provider.dart';
import '../theme/app_spacing.dart';

/// Iniziali per l'avatar: prima e ultima parola del nome, altrimenti la
/// prima lettera della email, altrimenti "?".
String profileInitials(String? displayName, String email) {
  final words = (displayName ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isNotEmpty) {
    final first = words.first[0];
    final last = words.length > 1 ? words.last[0] : '';
    return (first + last).toUpperCase();
  }
  final mail = email.trim();
  return mail.isNotEmpty ? mail[0].toUpperCase() : '?';
}

/// Intestazione comune delle tab della shell: titolo a sinistra, avatar del
/// profilo a destra.
class TabHeader extends StatelessWidget {
  final String title;

  const TabHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        context.spacingSm,
        context.spacingSm,
        context.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const ProfileAvatarButton(),
        ],
      ),
    );
  }
}

/// Avatar cablato su auth e sync. Apre il profilo sopra la shell.
class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final initials = switch (authState) {
      Authenticated(:final displayName, :final email) => profileInitials(
        displayName,
        email,
      ),
      Unauthenticated() => '?',
    };
    final unsynced = ref.watch(totalUnsyncedCountProvider).valueOrNull ?? 0;

    return ProfileAvatar(
      initials: initials,
      showSyncDot: unsynced > 0,
      onTap: () => context.push('/profile'),
    );
  }
}

/// Avatar puro (testabile senza provider).
class ProfileAvatar extends StatelessWidget {
  final String initials;
  final bool showSyncDot;
  final VoidCallback onTap;

  const ProfileAvatar({
    super.key,
    required this.initials,
    required this.showSyncDot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = context.responsive(40);

    return Semantics(
      button: true,
      label: 'navigation.open_profile'.tr(),
      child: InkResponse(
        key: const Key('profile_avatar'),
        onTap: onTap,
        radius: size,
        child: Padding(
          padding: EdgeInsets.all(context.spacingXs),
          child: Badge(
            isLabelVisible: showSyncDot,
            smallSize: context.responsive(10),
            backgroundColor: colorScheme.primary,
            child: CircleAvatar(
              radius: size / 2,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                initials,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
