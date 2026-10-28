import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/ds_picker_sheet.dart';

/// Sheet "galleria o fotocamera", unico per tour, import AI e risultati.
///
/// Restituisce la sorgente scelta, o null se l'utente chiude il sheet.
/// I sottotitoli sono facoltativi: il tour sceglie una foto sola e non deve
/// promettere il limite della galleria che vale nell'import.
Future<ImageSource?> showImageSourceSheet(
  BuildContext context, {
  String? gallerySubtitle,
  String? cameraSubtitle,
}) {
  return DsPickerSheet.show<ImageSource>(
    context: context,
    title: 'ai_import.source_sheet_title'.tr(),
    items: const [ImageSource.gallery, ImageSource.camera],
    getLabel: (s) => s == ImageSource.gallery
        ? 'ai_import.source_gallery'.tr()
        : 'ai_import.source_camera'.tr(),
    getSubtitle: (s) =>
        s == ImageSource.gallery ? gallerySubtitle : cameraSubtitle,
    getIcon: (s) => s == ImageSource.gallery
        ? Icons.photo_library_outlined
        : Icons.camera_alt_outlined,
  );
}
