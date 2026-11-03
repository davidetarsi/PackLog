import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_section_title.dart';
import '../../../../luggages/model/luggage_model.dart';
import 'pack_parts.dart';

/// Le valigie del viaggio come pillole sotto il titolo; niente se non ce ne
/// sono.
class PackLuggages extends StatelessWidget {
  const PackLuggages(this.luggages, {super.key});

  final List<LuggageModel> luggages;

  @override
  Widget build(BuildContext context) {
    if (luggages.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionTitle('trips.pack.luggages'.tr()),
        Wrap(
          spacing: context.spacingSm,
          runSpacing: context.spacingSm,
          children: [
            for (final luggage in luggages)
              PackPill(label: luggage.name, icon: Icons.luggage_outlined),
          ],
        ),
      ],
    );
  }
}
