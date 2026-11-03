import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/helpers/snack_bar_helper.dart';
import '../../items/providers/item_selection_provider.dart';
import '../model/kit_model.dart';
import '../providers/kit_provider.dart';
import '../repositories/kit_repository.dart';
import 'widgets/add_to_kit_sheet.dart';

/// "In un kit" dalla selezione della casa: sceglie un kit (o ne crea uno
/// nuovo, con gli oggetti già dentro) e chiude la selezione. Gli oggetti non
/// cambiano posto. Quelli già nel kit tengono le loro copie.
Future<void> addSelectionToKit(
  BuildContext context,
  WidgetRef ref, {
  required String houseId,
}) async {
  final ids = ref.read(itemSelectionNotifierProvider).selectedIds.toList();
  if (ids.isEmpty) return;

  final choice = await AddToKitSheet.show(
    context,
    houseId: houseId,
    itemCount: ids.length,
  );
  if (choice == null || !context.mounted) return;

  final kit = choice.kit;
  if (kit == null) {
    final saved = await context.push<bool>(
      '/houses/$houseId/kits/new',
      extra: ids,
    );
    if (saved == true) ref.read(itemSelectionNotifierProvider.notifier).clear();
    return;
  }
  await _addToExisting(context, ref, houseId: houseId, kit: kit, ids: ids);
}

Future<void> _addToExisting(
  BuildContext context,
  WidgetRef ref, {
  required String houseId,
  required KitModel kit,
  required List<String> ids,
}) async {
  final already = {for (final line in kit.items) line.itemId};
  final fresh = {
    for (final id in ids)
      if (!already.contains(id)) id: 1,
  };
  try {
    if (fresh.isNotEmpty) {
      await ref
          .read(kitNotifierProvider(houseId).notifier)
          .addItems(kit.id, fresh);
    }
    if (!context.mounted) return;
    AppSnackBar.showSuccess(
      context,
      'kits.added_to_kit'.plural(ids.length, args: ['${ids.length}', kit.name]),
    );
    ref.read(itemSelectionNotifierProvider.notifier).clear();
  } on KitLimitException catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(
        context,
        'kits.limit_items'.tr(args: ['${e.limit}']),
      );
    }
  } catch (_) {
    if (context.mounted) {
      AppSnackBar.showError(context, 'errors.save_error'.tr());
    }
  }
}
