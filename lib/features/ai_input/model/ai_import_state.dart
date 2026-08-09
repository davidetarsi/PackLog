import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'ai_failure_reason.dart';
import 'clothing_analysis_result.dart';

part 'ai_import_state.freezed.dart';

@freezed
class PhotoGroup with _$PhotoGroup {
  const factory PhotoGroup({
    required File photo,
    required List<ClothingAnalysisResult> results,
  }) = _PhotoGroup;
}

/// Stima usata dalla barra di avanzamento al primo utilizzo, prima che ci
/// siano tempi reali su cui fare media.
const kDefaultPhotoAnalysisMs = 12000;

@freezed
class AiImportState with _$AiImportState {
  const factory AiImportState({
    @Default([]) List<PhotoGroup> photoGroups,
    @Default(false) bool isLoading,
    @Default(0) int processingIndex,
    @Default(0) int totalImages,

    /// Errore dell'analisi, in forma classificata.
    ///
    /// Separato da [errorMessage] perché sono due flussi diversi: questo è
    /// terminale per la schermata e può offrire un retry, mentre
    /// [errorMessage] copre il salvataggio e le validazioni, che non
    /// interrompono la pagina.
    AiFailureReason? failureReason,
    String? errorMessage,
    String? selectedHouseId,

    /// Durata media di analisi per foto, in millisecondi. Alimenta la stima
    /// della barra di avanzamento e si affina a ogni run.
    @Default(kDefaultPhotoAnalysisMs) int avgPhotoMs,
  }) = _AiImportState;
}
