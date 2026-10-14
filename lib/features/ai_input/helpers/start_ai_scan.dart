import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/ai_import_notifier.dart';
import '../view/widgets/image_source_sheet.dart';

/// Numero massimo di immagini selezionabili per scansione.
const kAiScanMaxPhotos = 5;

BuildContext? _activeAiScanContext;
Object? _activeAiScanOperation;

/// Apre il selettore delle immagini e avvia l'analisi per la casa indicata.
///
/// La guardia impedisce fogli sovrapposti; lo stato del notifier e la route
/// risultati bloccano un nuovo avvio durante l'analisi e finché resta aperta.
Future<void> startAiScan(
  BuildContext context,
  WidgetRef ref,
  String houseId,
) async {
  if (!context.mounted) return;
  if (_activeAiScanContext?.mounted ?? false) return;

  final router = GoRouter.of(context);
  final notifier = ref.read(aiImportNotifierProvider.notifier);
  final matches = router.routerDelegate.currentConfiguration.matches;
  final isAlreadyOnResults =
      matches.isNotEmpty &&
      matches.last is RouteMatch &&
      (matches.last as RouteMatch).route.name == 'ai-import-results';
  if (isAlreadyOnResults || ref.read(aiImportNotifierProvider).isLoading) {
    return;
  }

  final operation = Object();
  _activeAiScanContext = context;
  _activeAiScanOperation = operation;
  try {
    final source = await showImageSourceSheet(
      context,
      gallerySubtitle: 'ai_import.gallery_subtitle'.tr(
        args: ['$kAiScanMaxPhotos'],
      ),
      cameraSubtitle: 'ai_import.camera_subtitle'.tr(),
    );
    if (source == null || !context.mounted) return;

    final List<File> files;
    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        final picked = await picker.pickMultiImage(
          imageQuality: 80,
          limit: kAiScanMaxPhotos,
        );
        files = [
          for (final image in picked.take(kAiScanMaxPhotos)) File(image.path),
        ];
      } else {
        final picked = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );
        files = picked == null ? const [] : [File(picked.path)];
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('ai_import.picker_error'.tr()),
            action: SnackBarAction(
              label: 'ai_import.picker_retry'.tr(),
              onPressed: () {
                if (context.mounted) {
                  unawaited(startAiScan(context, ref, houseId));
                }
              },
            ),
          ),
        );
      }
      return;
    }
    if (files.isEmpty || !context.mounted) return;

    notifier
      ..reset()
      ..setSelectedHouseId(houseId);
    // processFiles imposta isLoading in modo sincrono prima del primo await.
    unawaited(notifier.processFiles(files));
    // Il Future di GoRouter.push non si completa quando go() sostituisce lo
    // stack (per esempio dopo logout); isLoading blocca altri avvii durante
    // l'analisi senza legare la guardia alla durata del Future di navigazione.
    unawaited(context.push<void>('/houses/$houseId/ai-import/results'));
  } finally {
    if (identical(_activeAiScanOperation, operation)) {
      _activeAiScanContext = null;
      _activeAiScanOperation = null;
    }
  }
}
