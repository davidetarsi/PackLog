import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/catalog/catalog_provider.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_text_button.dart';
import '../../providers/kit_provider.dart';
import 'kit_chip_card.dart';

/// La riga dei kit nella casa, sotto le pillole degli spazi: titolo, una card
/// per kit e in fondo "+ Kit". Senza kit resta solo il tasto.
class KitStrip extends ConsumerWidget {
  const KitStrip({super.key, required this.houseId});

  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le etichette delle pillole seguono il catalogo.
    ref.watch(catalogRevisionProvider);
    final theme = Theme.of(context);
    final kits =
        ref.watch(kitNotifierProvider(houseId)).valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: context.spacingMd,
            top: context.spacingSm,
            bottom: context.spacingXs,
          ),
          child: Text(
            'kits.strip_title'.tr(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SingleChildScrollView(
          key: const Key('kit_strip_row'),
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
          child: Row(
            children: [
              for (final kit in kits) ...[
                KitChipCard(
                  key: Key('kit_card_${kit.id}'),
                  kit: kit,
                  moreLabel: (n) => 'kits.more_uses'.tr(args: ['$n']),
                  onTap: () => context.push('/houses/$houseId/kits/${kit.id}'),
                ),
                SizedBox(width: context.spacingSm),
              ],
              DsTextButton(
                key: const Key('kit_strip_add'),
                icon: Icons.add,
                label: 'kits.strip_add'.tr(),
                accent: true,
                onPressed: () => context.push('/houses/$houseId/kits/new'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
