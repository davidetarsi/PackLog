import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_spacing.dart';

/// Mostra il dialog di conferma eliminazione account.
///
/// Conferma protetta dalla digitazione esatta della propria email.
/// Pattern GitHub/Stripe: difficile fare l'operazione per errore.
Future<bool?> showProfileDeleteAccountDialog(
  BuildContext context,
  String requiredEmail,
) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _DeleteAccountDialog(requiredEmail: requiredEmail),
  );
}

/// Dialog di conferma per il delete account, estratto come [StatefulWidget]
/// per gestire correttamente il lifecycle del [TextEditingController].
class _DeleteAccountDialog extends StatefulWidget {
  final String requiredEmail;

  const _DeleteAccountDialog({required this.requiredEmail});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches =>
      _controller.text.trim().toLowerCase() ==
      widget.requiredEmail.toLowerCase();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('profile.delete_account_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('profile.delete_account_warning'.tr()),
          AppSpacing.gapMd,
          Text(
            'profile.delete_account_confirm_prompt'.tr(
              args: [widget.requiredEmail],
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          AppSpacing.gapSm,
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: widget.requiredEmail,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          child: Text('profile.delete_account_button'.tr()),
        ),
      ],
    );
  }
}
