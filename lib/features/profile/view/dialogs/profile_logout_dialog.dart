import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/helpers/dialog_helpers.dart';

enum ProfileLogoutChoice { cancel, syncFirst, forceLogout }

/// Mostra il dialog di conferma logout.
///
/// Se [pending] == 0: conferma semplice (esci / annulla).
/// Se [pending] > 0: tre uscite, perché "esci comunque" e "sincronizza prima
/// di uscire" sono due decisioni diverse e nessuna delle due è "annulla".
///
/// Entrambi i casi passano da [DialogHelpers]: prima erano due `AlertDialog`
/// scritti a mano, con il rischio che il giorno in cui cambia lo stile delle
/// conferme questi due restino indietro.
Future<ProfileLogoutChoice?> showProfileLogoutDialog(
  BuildContext context,
  int pending,
) async {
  if (pending > 0) {
    final choice = await DialogHelpers.showChoice<ProfileLogoutChoice>(
      context: context,
      title: 'profile.logout_warning_title'.tr(),
      message: 'profile.logout_warning_body'.tr(args: [pending.toString()]),
      secondaryLabel: 'profile.logout_force'.tr(),
      secondaryValue: ProfileLogoutChoice.forceLogout,
      primaryLabel: 'profile.logout_sync_first'.tr(),
      primaryValue: ProfileLogoutChoice.syncFirst,
    );
    return choice ?? ProfileLogoutChoice.cancel;
  }

  final confirmed = await DialogHelpers.showConfirmation(
    context: context,
    title: 'profile.logout_confirm_title'.tr(),
    message: 'profile.logout_confirm_body'.tr(),
    confirmLabel: 'profile.logout_force'.tr(),
  );
  return confirmed
      ? ProfileLogoutChoice.forceLogout
      : ProfileLogoutChoice.cancel;
}
