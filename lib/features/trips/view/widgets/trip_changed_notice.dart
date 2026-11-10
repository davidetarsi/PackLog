import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/theme.dart';
import '../../../../shared/widgets/ds_icon_button.dart';
import '../../../../shared/widgets/ds_link_button.dart';

/// Avviso in cima alla valigia: il viaggio è cambiato dopo la proposta AI.
/// [onRedo] rifà la valigia, [onClose] chiude l'avviso per sempre.
class TripChangedNotice extends StatelessWidget {
  const TripChangedNotice({
    super.key,
    required this.onRedo,
    required this.onClose,
  });

  final VoidCallback onRedo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('trip_changed_notice'),
      padding: EdgeInsetsDirectional.only(
        start: context.spacingMd,
        top: context.spacingSm,
        bottom: context.spacingSm,
      ),
      decoration: BoxDecoration(
        color: context.groupSurface,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: context.spacingSm),
                  child: Text(
                    'trips.detail.changed_notice'.tr(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                ),
                DsLinkButton(
                  key: const Key('trip_changed_redo'),
                  label: 'trips.detail.changed_redo'.tr(),
                  onPressed: onRedo,
                ),
              ],
            ),
          ),
          DsIconButton(
            key: const Key('trip_changed_close'),
            icon: Icons.close,
            tooltip: 'common.close'.tr(),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
