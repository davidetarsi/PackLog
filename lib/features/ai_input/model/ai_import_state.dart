import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'clothing_analysis_result.dart';

part 'ai_import_state.freezed.dart';

@freezed
class PhotoGroup with _$PhotoGroup {
  const factory PhotoGroup({
    required File photo,
    required List<ClothingAnalysisResult> results,
  }) = _PhotoGroup;
}

@freezed
class AiImportState with _$AiImportState {
  const factory AiImportState({
    @Default([]) List<PhotoGroup> photoGroups,
    @Default(false) bool isLoading,
    @Default(0) int processingIndex,
    @Default(0) int totalImages,
    String? errorMessage,
    String? selectedHouseId,
  }) = _AiImportState;
}
