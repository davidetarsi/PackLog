import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'clothing_analysis_result.dart';

part 'ai_import_state.freezed.dart';

class PhotoGroup {
  final File photo;
  final List<ClothingAnalysisResult> results;

  const PhotoGroup({required this.photo, required this.results});

  PhotoGroup copyWith({File? photo, List<ClothingAnalysisResult>? results}) =>
      PhotoGroup(
        photo: photo ?? this.photo,
        results: results ?? this.results,
      );
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
