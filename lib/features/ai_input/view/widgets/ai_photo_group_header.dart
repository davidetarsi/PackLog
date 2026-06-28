import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/theme/app_spacing.dart';

class AiPhotoGroupHeader extends StatelessWidget {
  final File photo;
  final int photoIndex;
  final int totalPhotos;

  const AiPhotoGroupHeader({
    super.key,
    required this.photo,
    required this.photoIndex,
    required this.totalPhotos,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          child: Image.file(
            photo,
            width: context.iconSizeHero,
            height: context.iconSizeHero,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: context.spacingMd),
        Text(
          totalPhotos > 1
              ? 'ai_import.photo_of'.tr(
                  args: [photoIndex.toString(), totalPhotos.toString()],
                )
              : 'ai_import.photo'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
