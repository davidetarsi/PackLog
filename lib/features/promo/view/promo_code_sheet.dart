import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_field.dart';
import '../../../shared/widgets/standard_bottom_sheet_layout.dart';
import '../../profile/providers/gpt_usage_provider.dart';
import '../model/promo_redeem_result.dart';
import '../providers/promo_code_provider.dart';

/// Il foglio "Hai un codice promo?".
///
/// Con [redeemNow] `false` (schermata di login, utente non ancora entrato) il
/// codice viene solo salvato sul telefono e attivato dopo il login; con
/// `true` (profilo) si attiva subito e un rifiuto resta nel foglio.
Future<void> showPromoCodeSheet(
  BuildContext context, {
  required bool redeemNow,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PromoCodeSheet(redeemNow: redeemNow),
  );
}

/// Il messaggio per l'utente di un codice attivato.
String promoRedeemedMessage(PromoRedeemed result) => 'promo.redeemed'.tr(
  args: [
    result.credits.toString(),
    DateFormat.yMMMd().format(result.expiresAt),
  ],
);

class _PromoCodeSheet extends ConsumerStatefulWidget {
  const _PromoCodeSheet({required this.redeemNow});

  final bool redeemNow;

  @override
  ConsumerState<_PromoCodeSheet> createState() => _PromoCodeSheetState();
}

class _PromoCodeSheetState extends ConsumerState<_PromoCodeSheet> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorKey;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _errorKey = 'promo.error_empty');
      return;
    }
    final service = ref.read(promoCodeServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (!widget.redeemNow) {
      await service.savePending(code);
      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.showSuccess(context, 'promo.saved_for_login'.tr());
      return;
    }

    setState(() {
      _isLoading = true;
      _errorKey = null;
    });
    final result = await service.redeem(code);
    if (!mounted) return;
    switch (result) {
      case PromoRedeemed():
        ref.invalidate(gptUsageProvider);
        Navigator.pop(context);
        messenger.hideCurrentSnackBar();
        AppSnackBar.showSuccess(context, promoRedeemedMessage(result));
      case PromoRejected(:final reason):
        setState(() {
          _isLoading = false;
          _errorKey = reason.messageKey;
        });
      case PromoFailed():
        setState(() {
          _isLoading = false;
          _errorKey = 'promo.error_generic';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StandardBottomSheetLayout(
      title: 'promo.sheet_title'.tr(),
      onCancel: () => Navigator.pop(context),
      onSave: _submit,
      isLoading: _isLoading,
      saveLabel: 'promo.activate'.tr(),
      saveButtonKey: const Key('promo_sheet_activate'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.redeemNow
                ? 'promo.description'.tr()
                : 'promo.description_login'.tr(),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapMd,
          TextField(
            key: const Key('promo_sheet_field'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_errorKey != null) setState(() => _errorKey = null);
            },
            decoration: dsFieldDecoration(
              context,
              hasError: _errorKey != null,
              hintText: 'promo.hint'.tr(),
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
            ),
          ),
          if (_errorKey != null) ...[
            SizedBox(height: context.spacingXs),
            Text(
              _errorKey!.tr(),
              key: const Key('promo_sheet_error'),
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
          AppSpacing.gapLg,
        ],
      ),
    );
  }
}
