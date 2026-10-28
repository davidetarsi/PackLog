import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/sync/sync_provider.dart';
import '../constants/app_constants.dart';
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
    final first = words.first.characters.first;
    final last = words.length > 1 ? words.last.characters.first : '';
    return (first + last).toUpperCase();
  }
  final mail = email.trim();
  return mail.isNotEmpty ? mail.characters.first.toUpperCase() : '?';
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ProfileInitialsCircle(
                initials: initials,
                radius: size / 2,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (showSyncDot)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _SyncDot(size: context.responsive(10)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cerchio con le iniziali dell'utente: fondo pesca, iniziali arancio scuro e
/// un bordino arancio che lo stacca dal fondo grigio del tema chiaro. Lo
/// stesso in alto a destra nelle tab e in cima al Profilo.
class ProfileInitialsCircle extends StatelessWidget {
  const ProfileInitialsCircle({
    super.key,
    required this.initials,
    required this.radius,
    this.style,
  });

  final String initials;
  final double radius;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('profile_initials_circle'),
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primaryContainer,
        border: Border.all(
          color: colorScheme.primary,
          width: AppConstants.selectedBorderWidth,
        ),
      ),
      child: Text(
        initials,
        style: style?.copyWith(color: colorScheme.onPrimaryContainer),
      ),
    );
  }
}

/// Pallino "modifiche da sincronizzare": arancio, con un anello del colore di
/// fondo che lo stacca dal bordo arancio dell'avatar.
class _SyncDot extends StatelessWidget {
  const _SyncDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('profile_sync_dot'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary,
        border: Border.all(
          color: colorScheme.surface,
          width: AppConstants.emphasisBorderWidth,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
    );
  }
}
