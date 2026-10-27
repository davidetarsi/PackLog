import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_dialog.dart';
import '../../../../shared/widgets/ds_group_header.dart';
import '../../../../shared/widgets/ds_icon_button.dart';

/// Foto d'origine e intestazione del relativo gruppo di risultati.
class AiPhotoGroupHeader extends StatelessWidget {
  final File photo;
  final int photoIndex;
  final int itemCount;

  const AiPhotoGroupHeader({
    super.key,
    required this.photo,
    required this.photoIndex,
    required this.itemCount,
  });

  Widget _missingPhoto(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  void _openFull(BuildContext context) {
    showDsDialog<void>(
      context,
      builder: (dialogContext) => Dialog.fullscreen(
        key: const Key('ai_photo_viewer'),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.file(
                  photo,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      _missingPhoto(context),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: DsIconButton(
                  icon: Icons.close,
                  tooltip: 'common.close'.tr(),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Foto intera e alta: è ciò che l'utente riconosce per primo. Toccandola
    // si apre a schermo intero.
    final height = context.responsive(160);
    final radius = BorderRadius.circular(AppConstants.cardBorderRadius);
    return Padding(
      padding: EdgeInsets.only(top: context.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              key: const Key('ai_photo_preview'),
              borderRadius: radius,
              onTap: () => _openFull(context),
              child: ClipRRect(
                borderRadius: radius,
                child: Image.file(
                  photo,
                  height: height,
                  fit: BoxFit.contain,
                  // Foto mancante: un riquadro quadrato, così resta un bersaglio
                  // da toccare e non sparisce.
                  errorBuilder: (context, error, stackTrace) => SizedBox.square(
                    dimension: height,
                    child: _missingPhoto(context),
                  ),
                ),
              ),
            ),
          ),
          DsGroupHeader(
            label: 'ai_import.photo_number'.tr(args: ['$photoIndex']),
            detail: 'ai_import.items_count'.plural(itemCount),
          ),
        ],
      ),
    );
  }
}
