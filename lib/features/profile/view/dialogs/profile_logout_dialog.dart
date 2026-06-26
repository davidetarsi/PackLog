import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

enum ProfileLogoutChoice { cancel, syncFirst, forceLogout }

/// Mostra il dialog di conferma logout.
///
/// Se [pending] == 0: dialog semplice (conferma / annulla).
/// Se [pending] > 0: dialog con avviso modifiche non sincronizzate e
/// opzione di flush pre-logout.
Future<ProfileLogoutChoice?> showProfileLogoutDialog(
  BuildContext context,
  int pending,
) {
  if (pending > 0) {
    return showDialog<ProfileLogoutChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile.logout_warning_title'.tr()),
        content: Text(
          'profile.logout_warning_body'.tr(args: [pending.toString()]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ProfileLogoutChoice.cancel),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, ProfileLogoutChoice.forceLogout),
            child: Text('profile.logout_force'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ProfileLogoutChoice.syncFirst),
            child: Text('profile.logout_sync_first'.tr()),
          ),
        ],
      ),
    );
  }

  return showDialog<ProfileLogoutChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('profile.logout_confirm_title'.tr()),
      content: Text('profile.logout_confirm_body'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, ProfileLogoutChoice.cancel),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ProfileLogoutChoice.forceLogout),
          child: Text('profile.logout_force'.tr()),
        ),
      ],
    ),
  );
}
