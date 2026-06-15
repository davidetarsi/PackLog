import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/repositories/house_repository.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/repositories/item_repository.dart';
import '../../tour/providers/post_login_onboarding_provider.dart';
import '../model/ai_import_state.dart';
import '../model/clothing_analysis_exception.dart';
import '../model/clothing_analysis_result.dart';
import 'ai_clothing_analyzer_service_provider.dart';

part 'ai_import_notifier.g.dart';

@Riverpod(keepAlive: true)
class AiImportNotifier extends _$AiImportNotifier {
  static const _maxPhotos = 5;
  final _uuid = const Uuid();

  @override
  AiImportState build() => const AiImportState();

  // ── Computed ──────────────────────────────────────────────────────────────

  int get remainingSlots => _maxPhotos - state.photoGroups.length;

  List<ClothingAnalysisResult> get allResults =>
      state.photoGroups.expand((g) => g.results).toList();

  // ── Processing ────────────────────────────────────────────────────────────

  Future<void> processFiles(List<File> files) async {
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      processingIndex: 0,
      totalImages: files.length,
      errorMessage: null,
    );

    try {
      final service = ref.read(aiClothingAnalyzerServiceProvider);
      for (var i = 0; i < files.length; i++) {
        state = state.copyWith(processingIndex: i + 1);
        final file = files[i];
        final result = await service.processClothingItem(file);

        state = state.copyWith(
          photoGroups: [
            ...state.photoGroups,
            PhotoGroup(photo: file, results: result),
          ],
        );
      }
    } on GptLimitExceededException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } on ClothingAnalysisException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'ai_import.unexpected_error'.tr(args: [e.toString()]),
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // ── Item management ───────────────────────────────────────────────────────

  void deleteItem(int groupIndex, int itemIndex) {
    final groups = List<PhotoGroup>.from(state.photoGroups);
    final group = groups[groupIndex];
    final newResults = List<ClothingAnalysisResult>.from(group.results)
      ..removeAt(itemIndex);

    if (newResults.isEmpty) {
      groups.removeAt(groupIndex);
    } else {
      groups[groupIndex] = group.copyWith(results: newResults);
    }
    state = state.copyWith(photoGroups: groups);
  }

  void updateItemName(int groupIndex, int itemIndex, String name) {
    final groups = List<PhotoGroup>.from(state.photoGroups);
    final group = groups[groupIndex];
    final newResults = List<ClothingAnalysisResult>.from(group.results);
    newResults[itemIndex] = newResults[itemIndex].copyWith(name: name);
    groups[groupIndex] = group.copyWith(results: newResults);
    state = state.copyWith(photoGroups: groups);
  }

  void setSelectedHouseId(String id) {
    state = state.copyWith(selectedHouseId: id);
  }

  void reset() {
    state = const AiImportState();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Saves items to the house specified by [state.selectedHouseId].
  /// Throws if [state.selectedHouseId] is null.
  Future<void> saveItems() async {
    final houseId = state.selectedHouseId;
    if (houseId == null) {
      state = state.copyWith(
        errorMessage: 'ai_import.no_house_selected'.tr(),
      );
      return;
    }

    final results = allResults;
    if (results.isEmpty) return;

    state = state.copyWith(isLoading: true);
    try {
      final now = DateTime.now();
      final items =
          results
              .map(
                (r) => ItemModel(
                  id: _uuid.v4(),
                  houseId: houseId,
                  name: r.name,
                  category: _mapCategory(r.category),
                  quantity: 1,
                  createdAt: now,
                  updatedAt: now,
                  aiMetadata: jsonEncode(r.toJson()),
                ),
              )
              .toList();

      await ref.read(itemRepositoryProvider).insertMultipleItems(items);
      ref.invalidate(itemNotifierProvider(houseId));
      ref.read(syncOrchestratorProvider).requestSync();
      ref
          .read(coreAnalyticsServiceProvider)
          .trackAiItemsSaved(count: items.length, isOnboarding: false);
      state = const AiImportState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'ai_import.save_error'.tr(args: [e.toString()]),
      );
    }
  }

  /// Creates a default house, saves all AI items to it, advances onboarding.
  /// Used only during first-time onboarding.
  Future<void> saveItemsOnboarding() async {
    final results = allResults;
    if (results.isEmpty) return;

    state = state.copyWith(isLoading: true);
    try {
      final now = DateTime.now();
      final houseId = _uuid.v4();
      final house = HouseModel(
        id: houseId,
        name: 'onboarding.default_house_name'.tr(),
        createdAt: now,
        updatedAt: now,
      );
      final items =
          results
              .map(
                (r) => ItemModel(
                  id: _uuid.v4(),
                  houseId: houseId,
                  name: r.name,
                  category: _mapCategory(r.category),
                  quantity: 1,
                  createdAt: now,
                  updatedAt: now,
                  aiMetadata: jsonEncode(r.toJson()),
                ),
              )
              .toList();

      await ref.read(houseRepositoryProvider).createHouseWithItems(house, items);
      ref.invalidate(houseNotifierProvider);
      ref.invalidate(itemNotifierProvider(houseId));
      ref.read(syncOrchestratorProvider).requestSync();
      ref
          .read(coreAnalyticsServiceProvider)
          .trackAiItemsSaved(count: items.length, isOnboarding: true);
      await ref.read(postLoginOnboardingProvider.notifier).completeAi(houseId);
      state = const AiImportState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'ai_import.save_error'.tr(args: [e.toString()]),
      );
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static ItemCategory _mapCategory(String aiCategory) {
    final lower = aiCategory.toLowerCase();
    if (lower.contains('accessory')) return ItemCategory.varie;
    return ItemCategory.vestiti;
  }
}
