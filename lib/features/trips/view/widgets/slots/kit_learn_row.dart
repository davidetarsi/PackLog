import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_divider.dart';
import '../../../../../shared/widgets/ds_text_button.dart';

/// "La prossima volta lo aggiungo da solo per {}?": compare dopo un sì, nella
/// stessa posizione della riga del kit, con Sì e No.
class KitLearnRow extends StatelessWidget {
  const KitLearnRow({
    super.key,
    required this.useLabel,
    required this.onYes,
    required this.onNo,
  });

  /// L'attività o il mezzo, nella lingua attiva.
  final String useLabel;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: context.spacingSm),
          child: Text(
            'kits.learn_question'.tr(args: [useLabel]),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Row(
          children: [
            DsTextButton(
              key: const Key('kit_learn_yes'),
              label: 'kits.learn_yes'.tr(),
              accent: true,
              onPressed: onYes,
            ),
            SizedBox(width: context.spacingSm),
            DsTextButton(
              key: const Key('kit_learn_no'),
              label: 'kits.learn_no'.tr(),
              onPressed: onNo,
            ),
          ],
        ),
        const DsDivider(),
      ],
    );
  }
}
