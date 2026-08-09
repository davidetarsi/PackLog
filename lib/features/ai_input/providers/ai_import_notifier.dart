import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../model/ai_failure_reason.dart';
import '../model/ai_import_state.dart';
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

  /// File dell'ultimo tentativo, per poter riprovare senza rifare la scelta.
  List<File> _lastFiles = const [];

  Future<void> processFiles(List<File> files) async {
    if (state.isLoading) return;
    _lastFiles = List.unmodifiable(files);

    // Nessun await prima di qui: alzare isLoading dopo una sospensione
    // lascerebbe passare due chiamate concorrenti dalla guardia qui sopra.
    state = state.copyWith(
      isLoading: true,
      processingIndex: 0,
      totalImages: files.length,
      failureReason: null,
      errorMessage: null,
      avgPhotoMs: _cachedAvgMs ?? kDefaultPhotoAnalysisMs,
    );

    // La stima serve alla barra, non all'analisi: leggerla da disco prima di
    // iniziare ritarderebbe la prima chiamata a GPT per nulla. Parte in
    // parallelo e aggiorna lo stato quando arriva.
    unawaited(_primeAvgPhotoMs());

    final durations = <int>[];
    try {
      final service = ref.read(aiClothingAnalyzerServiceProvider);
      for (var i = 0; i < files.length; i++) {
        state = state.copyWith(processingIndex: i + 1);
        final file = files[i];

        final started = DateTime.now();
        final result = await service.processClothingItem(file);
        durations.add(DateTime.now().difference(started).inMilliseconds);

        state = state.copyWith(
          photoGroups: [
            ...state.photoGroups,
            PhotoGroup(photo: file, results: result),
          ],
        );
      }
    } catch (e) {
      // Un solo punto di uscita per gli errori: il messaggio tecnico resta
      // nell'eccezione (log/Sentry), a schermo va il motivo classificato.
      state = state.copyWith(failureReason: aiFailureReasonFrom(e));
    } finally {
      state = state.copyWith(isLoading: false);
      if (durations.isNotEmpty) await _recordDurations(durations);
    }
  }

  /// Riprova l'analisi solo sulle foto non ancora andate a buon fine.
  ///
  /// Rilanciare l'intero lotto duplicherebbe i gruppi già ottenuti, visto che
  /// [processFiles] accoda invece di sostituire.
  Future<void> retryFailed() async {
    final done = state.photoGroups.map((g) => g.photo.path).toSet();
    final remaining = _lastFiles
        .where((f) => !done.contains(f.path))
        .toList(growable: false);
    if (remaining.isEmpty) return;
    await processFiles(remaining);
  }

  // ── Stima dei tempi ───────────────────────────────────────────────────────

  static const _avgPhotoMsKey = 'ai_import_avg_photo_ms';

  /// Stima in memoria, per non rileggere il disco a ogni run.
  int? _cachedAvgMs;

  /// Carica la stima e la applica allo stato, se nel frattempo l'analisi è
  /// ancora in corso. Non blocca nessuno.
  Future<void> _primeAvgPhotoMs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_avgPhotoMsKey);
    if (stored == null) return;
    _cachedAvgMs = stored;
    if (state.isLoading) state = state.copyWith(avgPhotoMs: stored);
  }

  /// Media mobile esponenziale sui tempi reali: la stima si adatta al backend
  /// e alla rete dell'utente senza farsi trascinare da un singolo run lento.
  Future<void> _recordDurations(List<int> durations) async {
    final prefs = await SharedPreferences.getInstance();
    var avg = prefs.getInt(_avgPhotoMsKey) ?? kDefaultPhotoAnalysisMs;
    for (final d in durations) {
      avg = (avg * 0.7 + d * 0.3).round();
    }
    // Limiti di sicurezza: una stima assurda renderebbe la barra inutile.
    avg = avg.clamp(3000, 60000);
    _cachedAvgMs = avg;
    await prefs.setInt(_avgPhotoMsKey, avg);
    state = state.copyWith(avgPhotoMs: avg);
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
      state = state.copyWith(errorMessage: 'ai_import.no_house_selected'.tr());
      return;
    }

    final results = allResults;
    if (results.isEmpty) return;

    state = state.copyWith(isLoading: true);
    try {
      final now = DateTime.now();
      final items = results
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
      final items = results
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

      await ref
          .read(houseRepositoryProvider)
          .createHouseWithItems(house, items);
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
