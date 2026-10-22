import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_field.dart';
import '../../../shared/widgets/ds_form_sheet.dart';
import '../../../shared/widgets/ds_field_label.dart';
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
  return showDsFormSheet<void>(
    context,
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
    if (_isLoading) return;
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _errorKey = 'promo.error_empty');
      return;
    }
    final service = ref.read(promoCodeServiceProvider);
    setState(() {
      _isLoading = true;
      _errorKey = null;
    });
    try {
      if (!widget.redeemNow) {
        await service.savePending(code);
        if (!mounted) return;
        AppSnackBar.showSuccess(context, 'promo.saved_for_login'.tr());
        setState(() => _isLoading = false);
        Navigator.pop(context);
        return;
      }
      final result = await service.redeem(code);
      if (!mounted) return;
      switch (result) {
        case PromoRedeemed():
          ref.invalidate(gptUsageProvider);
          AppSnackBar.showSuccess(context, promoRedeemedMessage(result));
          setState(() => _isLoading = false);
          Navigator.pop(context);
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
    } catch (_) {
      if (!mounted) return;
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

    return DsFormSheet(
      title: 'promo.sheet_title'.tr(),
      onSubmit: _controller.text.trim().isNotEmpty ? _submit : null,
      isBusy: _isLoading,
      actionLabel: 'promo.activate'.tr(),
      actionKey: const Key('promo_sheet_activate'),
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
          DsFieldLabel('promo.code_label'.tr()),
          TextField(
            key: const Key('promo_sheet_field'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              setState(() => _errorKey = null);
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
