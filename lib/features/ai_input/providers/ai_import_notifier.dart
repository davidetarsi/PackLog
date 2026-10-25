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
import '../../items/model/clothing_details.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/repositories/item_repository.dart';
import '../../tour/providers/post_login_onboarding_provider.dart';
import '../helpers/ai_item_category.dart';
import '../model/ai_failure_reason.dart';
import '../model/ai_import_state.dart';
import '../model/clothing_analysis_result.dart';
import 'ai_clothing_analyzer_service_provider.dart';

part 'ai_import_notifier.g.dart';

@Riverpod(keepAlive: true)
class AiImportNotifier extends _$AiImportNotifier {
  static const _maxPhotos = 5;
  final _uuid = const Uuid();

  /// I capi come li ha letti l'analisi, per gruppo e posizione: a fine
  /// scansione si vede quali dettagli l'utente ha cambiato dalla scheda.
  final Map<(int, int), ClothingAnalysisResult> _analyzed = {};

  @override
  AiImportState build() => const AiImportState();

  // ── Computed ──────────────────────────────────────────────────────────────

  int get remainingSlots => _maxPhotos - state.photoGroups.length;

  List<ClothingAnalysisResult> get allResults =>
      state.photoGroups.expand((g) => g.results).toList();

  /// I capi che il salvataggio scrive (nuovi o da arricchire), con la loro
  /// posizione nella scansione.
  Iterable<({int group, int item, ClothingAnalysisResult result})>
  get _savedEntries sync* {
    for (var g = 0; g < state.photoGroups.length; g++) {
      final group = state.photoGroups[g];
      for (var i = 0; i < group.results.length; i++) {
        if (group.linkedItemIds.containsKey(i) || !group.excluded.contains(i)) {
          yield (group: g, item: i, result: group.results[i]);
        }
      }
    }
  }

  List<ClothingAnalysisResult> get _newResults => [
    for (final group in state.photoGroups)
      for (var i = 0; i < group.results.length; i++)
        if (!group.excluded.contains(i) && !group.linkedItemIds.containsKey(i))
          group.results[i],
  ];

  Map<String, ClothingAnalysisResult> get _links => {
    for (final group in state.photoGroups)
      for (final entry in group.linkedItemIds.entries)
        entry.value: group.results[entry.key],
  };

  int get newCount => _newResults.length;

  int get updatedCount => _links.length;

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

        final groupIndex = state.photoGroups.length;
        for (var j = 0; j < result.length; j++) {
          _analyzed[(groupIndex, j)] = result[j];
        }
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

  PhotoGroup _group(int index) => state.photoGroups[index];

  void _replaceGroup(int index, PhotoGroup group) {
    final groups = List<PhotoGroup>.from(state.photoGroups);
    groups[index] = group;
    state = state.copyWith(photoGroups: groups);
  }

  void setIncluded(int groupIndex, int itemIndex, bool included) {
    final group = _group(groupIndex);
    final excluded = Set<int>.from(group.excluded);
    if (included) {
      excluded.remove(itemIndex);
    } else {
      excluded.add(itemIndex);
    }
    _replaceGroup(groupIndex, group.copyWith(excluded: excluded));
  }

  void linkToExisting(int groupIndex, int itemIndex, String itemId) {
    final groups = List<PhotoGroup>.from(state.photoGroups);
    for (var index = 0; index < groups.length; index++) {
      final links = Map<int, String>.from(groups[index].linkedItemIds)
        ..removeWhere((_, linkedId) => linkedId == itemId);
      groups[index] = groups[index].copyWith(linkedItemIds: links);
    }
    final target = groups[groupIndex];
    groups[groupIndex] = target.copyWith(
      linkedItemIds: {...target.linkedItemIds, itemIndex: itemId},
    );
    state = state.copyWith(photoGroups: groups);
  }

  void unlink(int groupIndex, int itemIndex) {
    final group = _group(groupIndex);
    final linkedItemIds = Map<int, String>.from(group.linkedItemIds)
      ..remove(itemIndex);
    _replaceGroup(groupIndex, group.copyWith(linkedItemIds: linkedItemIds));
  }

  void updateItemName(int groupIndex, int itemIndex, String name) {
    final current = _group(groupIndex).results[itemIndex];
    updateResult(groupIndex, itemIndex, current.copyWith(name: name));
  }

  /// Sostituisce il capo (per esempio dopo la scheda della scansione). Il
  /// nome è quello di [result]: non c'è un campo separato.
  void updateResult(
    int groupIndex,
    int itemIndex,
    ClothingAnalysisResult result,
  ) {
    final groups = List<PhotoGroup>.from(state.photoGroups);
    final group = groups[groupIndex];
    final newResults = List<ClothingAnalysisResult>.from(group.results);
    newResults[itemIndex] = result;
    groups[groupIndex] = group.copyWith(results: newResults);
    state = state.copyWith(photoGroups: groups);
  }

  void setSelectedHouseId(String id) {
    if (state.selectedHouseId == id) return;
    state = state.copyWith(
      selectedHouseId: id,
      photoGroups: [
        for (final group in state.photoGroups)
          group.copyWith(linkedItemIds: const <int, String>{}),
      ],
    );
  }

  void reset() {
    _analyzed.clear();
    state = const AiImportState();
  }

  /// Un evento per capo salvato i cui dettagli sono cambiati dalla scheda
  /// della scansione rispetto all'analisi.
  void _trackScanEdits() {
    final analytics = ref.read(coreAnalyticsServiceProvider);
    for (final entry in _savedEntries) {
      final original = _analyzed[(entry.group, entry.item)];
      if (original == null) continue;
      final fields = ClothingDetails.of(
        entry.result,
      ).changedFields(ClothingDetails.of(original));
      if (fields.isEmpty) continue;
      analytics.trackItemDetailsEdited(source: 'scan', fields: fields);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Saves items to the house specified by [state.selectedHouseId].
  /// Throws if [state.selectedHouseId] is null.
  Future<void> saveItems() async {
    if (state.isLoading) return;
    final houseId = state.selectedHouseId;
    if (houseId == null) {
      state = state.copyWith(errorMessage: 'ai_import.no_house_selected'.tr());
      return;
    }

    final results = _newResults;
    final links = _links;
    if (results.isEmpty && links.isEmpty) return;

    state = state.copyWith(isLoading: true);
    try {
      final now = DateTime.now();
      final items = results
          .map(
            (r) => ItemModel(
              id: _uuid.v4(),
              houseId: houseId,
              name: r.name,
              category: aiItemCategory(r.category, appCategory: r.appCategory),
              quantity: 1,
              createdAt: now,
              updatedAt: now,
              aiMetadata: jsonEncode(r.toJson()),
            ),
          )
          .toList();

      final metadataByItemId = {
        for (final entry in links.entries)
          entry.key: jsonEncode(entry.value.toJson()),
      };
      final updated = await ref
          .read(itemRepositoryProvider)
          .saveAiItemsToHouse(
            houseId: houseId,
            newItems: items,
            metadataByItemId: metadataByItemId,
          );
      ref.invalidate(itemNotifierProvider(houseId));
      ref.read(syncOrchestratorProvider).requestSync();
      ref
          .read(coreAnalyticsServiceProvider)
          .trackAiItemsSaved(
            count: items.length,
            isOnboarding: false,
            updated: updated,
          );
      _trackScanEdits();
      _analyzed.clear();
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
    if (state.isLoading) return;
    final results = _newResults;
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
              category: aiItemCategory(r.category, appCategory: r.appCategory),
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
      _trackScanEdits();
      _analyzed.clear();
      await ref.read(postLoginOnboardingProvider.notifier).completeAi(houseId);
      state = const AiImportState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'ai_import.save_error'.tr(args: [e.toString()]),
      );
    }
  }
}
