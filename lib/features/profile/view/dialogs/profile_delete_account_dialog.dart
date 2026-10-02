import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/helpers/dialog_helpers.dart';

/// Mostra il dialog di conferma eliminazione account.
///
/// Conferma protetta dalla digitazione esatta della propria email: il corpo
/// del dialog vive in [DialogHelpers.showProtectedDeleteConfirmation], così
/// resta allineato allo stile delle altre conferme distruttive dell'app.
Future<bool?> showProfileDeleteAccountDialog(
  BuildContext context,
  String requiredEmail,
) {
  return DialogHelpers.showProtectedDeleteConfirmation(
    context: context,
    title: 'profile.delete_account_title'.tr(),
    warning: 'profile.delete_account_warning'.tr(),
    prompt: 'profile.delete_account_confirm_prompt'.tr(args: [requiredEmail]),
    requiredText: requiredEmail,
    confirmLabel: 'profile.delete_account_button'.tr(),
  );
}
