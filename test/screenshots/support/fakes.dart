import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pack_log/features/ai_input/model/ai_failure_reason.dart';
import 'package:pack_log/features/ai_input/model/ai_import_state.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';
import 'package:pack_log/features/ai_input/providers/ai_import_notifier.dart';

import 'seed.dart';

/// Import AI pilotato dal test: niente fotocamera, niente GPT.
///
/// Parte da [_initial] e passa a uno stato nuovo con [emit]. La schermata
/// risultati crea i campi di testo dei capi dentro un `ref.listen`, cioè solo
/// su una *transizione* di stato, come accade nell'app (caricamento →
/// risultati): uno stato iniziale già pieno mostrerebbe le foto senza capi.
class FakeAiImport extends AiImportNotifier {
  FakeAiImport([this._initial = const AiImportState(isLoading: true)]);

  final AiImportState _initial;

  @override
  AiImportState build() => _initial;

  void emit(AiImportState next) => state = next;

  @override
  Future<void> processFiles(List<File> files) async {}

  @override
  Future<void> retryFailed() async {}
}

const _fixturesDir = 'build/ui-screenshots-fixtures';

/// "Foto" dei capi: rettangoli colorati generati al volo. Non c'è una
/// fotocamera nei test e non vogliamo immagini personali nel repo.
late File photoShirt;
late File photoJeans;

Future<void> createPhotoFixtures() async {
  photoShirt = await _photo('shirt.png', const Color(0xFF8FB8DE));
  photoJeans = await _photo('jeans.png', const Color(0xFF3B5B85));
}

Future<File> _photo(String name, Color garment) async {
  const size = Size(600, 600);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE9E4DA));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(150, 120, 300, 380),
      const Radius.circular(40),
    ),
    Paint()..color = garment,
  );
  final image = await recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_fixturesDir/$name')..createSync(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file;
}

ClothingAnalysisResult _garment(String name, String color, String sub) =>
    ClothingAnalysisResult(
      name: name,
      category: 'vestiti',
      subCategory: sub,
      baseColor: color,
      pattern: 'Tinta unita',
      coverage: 'Busto',
      fit: 'Regular',
      warmth: 2,
      formality: 'Casual',
      activityTags: const ['città', 'viaggio'],
    );

AiImportState aiResultsState({String? houseId = kHomeId}) => AiImportState(
  selectedHouseId: houseId,
  photoGroups: [
    PhotoGroup(
      photo: photoShirt,
      results: [
        _garment('Camicia di lino azzurra', 'Azzurro', 'Camicia'),
        _garment('T-shirt bianca', 'Bianco', 'T-shirt'),
      ],
    ),
    PhotoGroup(
      photo: photoJeans,
      results: [_garment('Jeans slim blu scuro', 'Blu', 'Pantaloni')],
    ),
  ],
);

AiImportState aiLoadingState() =>
    const AiImportState(isLoading: true, processingIndex: 2, totalImages: 3);

AiImportState aiFailureState(AiFailureReason reason) =>
    AiImportState(failureReason: reason);

AiImportState aiPartialFailureState() =>
    aiResultsState().copyWith(failureReason: AiFailureReason.network);
