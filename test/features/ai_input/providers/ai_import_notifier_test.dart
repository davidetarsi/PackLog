import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/ai_input/model/ai_import_state.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_exception.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';
import 'package:pack_log/features/ai_input/providers/ai_clothing_analyzer_service_provider.dart';
import 'package:pack_log/features/ai_input/providers/ai_import_notifier.dart';
import 'package:pack_log/features/ai_input/service/ai_clothing_analyzer_service.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/tour/model/onboarding_state.dart';
import 'package:pack_log/features/tour/providers/post_login_onboarding_provider.dart';
import 'package:pack_log/features/tour/repositories/i_onboarding_repository.dart';
import 'package:pack_log/features/tour/repositories/shared_prefs_onboarding_repository.dart';
import 'package:pack_log/features/ai_input/model/ai_failure_reason.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAiClothingAnalyzerService extends Mock
    implements AiClothingAnalyzerService {}

class MockItemRepository extends Mock implements ItemRepository {}

class MockHouseRepository extends Mock implements HouseRepository {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class MockOnboardingRepository extends Mock implements IOnboardingRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

File _fakeFile() {
  return File('${Directory.systemTemp.path}/test_ai_img.png')
    ..writeAsBytesSync(Uint8List.fromList([137, 80, 78, 71]));
}

ClothingAnalysisResult _fakeResult({String name = 'T-Shirt'}) =>
    ClothingAnalysisResult(
      name: name,
      category: 'Upper Body',
      subCategory: 'T-Shirt',
      baseColor: 'Bianco',
      pattern: 'Solid',
      coverage: 'Short-sleeve',
      fit: 'Regular',
      warmth: 2,
      formality: 'Casual',
      activityTags: const ['Everyday'],
    );

void _stubServiceSuccess(
  MockAiClothingAnalyzerService service,
  List<ClothingAnalysisResult> results,
) {
  when(
    () => service.processClothingItem(any()),
  ).thenAnswer((_) async => results);
}

ProviderContainer _makeContainer({
  MockAiClothingAnalyzerService? service,
  MockItemRepository? itemRepo,
  MockHouseRepository? houseRepo,
  MockSyncOrchestrator? syncOrchestrator,
  MockOnboardingRepository? onboardingRepo,
}) {
  return ProviderContainer(
    overrides: [
      if (service != null)
        aiClothingAnalyzerServiceProvider.overrideWithValue(service),
      if (itemRepo != null) itemRepositoryProvider.overrideWithValue(itemRepo),
      if (houseRepo != null)
        houseRepositoryProvider.overrideWithValue(houseRepo),
      if (syncOrchestrator != null)
        syncOrchestratorProvider.overrideWith((_) => syncOrchestrator),
      if (onboardingRepo != null)
        onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
    ],
  );
}

void _setupOnboardingMock(
  MockOnboardingRepository repo, {
  OnboardingStep step = OnboardingStep.aiIntro,
  bool hasExistingHouses = false,
}) {
  when(() => repo.loadStep()).thenAnswer((_) async => step);
  when(() => repo.loadSkippedAi()).thenAnswer((_) async => false);
  when(
    () => repo.loadHasExistingHouses(),
  ).thenAnswer((_) async => hasExistingHouses);
  when(() => repo.loadDefaultHouseId()).thenAnswer((_) async => null);
  when(() => repo.saveStep(any())).thenAnswer((_) async {});
  when(() => repo.saveSkippedAi(any())).thenAnswer((_) async {});
  when(() => repo.saveHasExistingHouses(any())).thenAnswer((_) async {});
  when(() => repo.saveDefaultHouseId(any())).thenAnswer((_) async {});
}

/// Puts a single PhotoGroup into state by running processFiles with a mocked service.
Future<void> _seedOneGroup(
  ProviderContainer container,
  MockAiClothingAnalyzerService service, {
  List<ClothingAnalysisResult>? results,
}) async {
  _stubServiceSuccess(service, results ?? [_fakeResult()]);
  await container.read(aiImportNotifierProvider.notifier).processFiles([
    _fakeFile(),
  ]);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // processFiles legge la stima dei tempi da SharedPreferences: senza binding
  // e valori mock il plugin non è disponibile nei test unitari.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  setUpAll(() {
    registerFallbackValue(OnboardingStep.aiIntro);
    registerFallbackValue(File(''));
    registerFallbackValue(<ItemModel>[]);
    registerFallbackValue(
      HouseModel(
        id: '',
        name: '',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
  });

  // ── build() ────────────────────────────────────────────────────────────────

  group('build()', () {
    test('returns const AiImportState() on initial build', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final state = container.read(aiImportNotifierProvider);
      expect(state, const AiImportState());
    });

    test('remainingSlots is 5 on fresh state', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(aiImportNotifierProvider.notifier);
      expect(notifier.remainingSlots, 5);
    });
  });

  // ── processFiles() ─────────────────────────────────────────────────────────

  group('processFiles()', () {
    test('success: appends one PhotoGroup, isLoading ends false', () async {
      final service = MockAiClothingAnalyzerService();
      final container = _makeContainer(service: service);
      addTearDown(container.dispose);

      await _seedOneGroup(container, service);

      final state = container.read(aiImportNotifierProvider);
      expect(state.photoGroups.length, 1);
      expect(state.photoGroups.first.results.first.name, 'T-Shirt');
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('success with 2 files: appends 2 groups', () async {
      final service = MockAiClothingAnalyzerService();
      final container = _makeContainer(service: service);
      addTearDown(container.dispose);

      _stubServiceSuccess(service, [_fakeResult()]);
      await container.read(aiImportNotifierProvider.notifier).processFiles([
        _fakeFile(),
        _fakeFile(),
      ]);

      final state = container.read(aiImportNotifierProvider);
      expect(state.photoGroups.length, 2);
      expect(state.isLoading, isFalse);
    });

    test(
      'GptLimitExceededException: failureReason=limitReached, no groups added',
      () async {
        final service = MockAiClothingAnalyzerService();
        final container = _makeContainer(service: service);
        addTearDown(container.dispose);

        when(
          () => service.processClothingItem(any()),
        ).thenThrow(const GptLimitExceededException('Monthly limit reached'));

        await container.read(aiImportNotifierProvider.notifier).processFiles([
          _fakeFile(),
        ]);

        final state = container.read(aiImportNotifierProvider);
        expect(state.failureReason, AiFailureReason.limitReached);
        // Riprovare non può sbloccare una quota esaurita.
        expect(state.failureReason!.isRetryable, isFalse);
        expect(state.isLoading, isFalse);
        expect(state.photoGroups, isEmpty);
      },
    );

    test(
      'VisionAnalysisException: failureReason=serviceError, isLoading false',
      () async {
        final service = MockAiClothingAnalyzerService();
        final container = _makeContainer(service: service);
        addTearDown(container.dispose);

        when(
          () => service.processClothingItem(any()),
        ).thenThrow(const VisionAnalysisException('Vision failed'));

        await container.read(aiImportNotifierProvider.notifier).processFiles([
          _fakeFile(),
        ]);

        final state = container.read(aiImportNotifierProvider);
        expect(state.failureReason, AiFailureReason.serviceError);
        expect(state.failureReason!.isRetryable, isTrue);
        // Il dettaglio tecnico non deve finire in uno stato leggibile dalla UI.
        expect(state.errorMessage, isNull);
        expect(state.isLoading, isFalse);
      },
    );

    test(
      'partial failure: first file OK, second throws → 1 group + failureReason',
      () async {
        final service = MockAiClothingAnalyzerService();
        final container = _makeContainer(service: service);
        addTearDown(container.dispose);

        var callCount = 0;
        when(() => service.processClothingItem(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return [_fakeResult()];
          throw const VisionAnalysisException('Second image failed');
        });

        await container.read(aiImportNotifierProvider.notifier).processFiles([
          _fakeFile(),
          _fakeFile(),
        ]);

        final state = container.read(aiImportNotifierProvider);
        expect(state.photoGroups, hasLength(1));
        expect(state.photoGroups.first.results.first.name, 'T-Shirt');
        expect(state.failureReason, AiFailureReason.serviceError);
        expect(state.isLoading, isFalse);
      },
    );

    test(
      'unexpected (non-ClothingAnalysis) exception → failureReason=unknown',
      () async {
        final service = MockAiClothingAnalyzerService();
        final container = _makeContainer(service: service);
        addTearDown(container.dispose);

        when(
          () => service.processClothingItem(any()),
        ).thenThrow(Exception('Unexpected DB error'));

        await container.read(aiImportNotifierProvider.notifier).processFiles([
          _fakeFile(),
        ]);

        final state = container.read(aiImportNotifierProvider);
        expect(state.failureReason, AiFailureReason.unknown);
        expect(state.isLoading, isFalse);
        expect(state.photoGroups, isEmpty);
      },
    );

    test(
      'concurrent call while isLoading is true: second call is a no-op',
      () async {
        final service = MockAiClothingAnalyzerService();
        final container = _makeContainer(service: service);
        addTearDown(container.dispose);

        // Slow completer that won't resolve until we tell it to
        final completer = Completer<List<ClothingAnalysisResult>>();
        when(
          () => service.processClothingItem(any()),
        ).thenAnswer((_) => completer.future);

        // Start first call (don't await — it hangs)
        final firstCall = container
            .read(aiImportNotifierProvider.notifier)
            .processFiles([_fakeFile()]);

        // isLoading should be true immediately after kick-off
        expect(container.read(aiImportNotifierProvider).isLoading, isTrue);

        // Second call while isLoading = true → should be a no-op
        await container.read(aiImportNotifierProvider.notifier).processFiles([
          _fakeFile(),
        ]);

        // Only 1 service call was ever made
        verify(() => service.processClothingItem(any())).called(1);

        // Resolve the hanging first call so the container can dispose cleanly
        completer.complete([_fakeResult()]);
        await firstCall;
      },
    );
  });

  // ── retryFailed() ──────────────────────────────────────────────────────────

  group('retryFailed()', () {
    test(
      'riprocessa solo le foto non riuscite, senza duplicare i gruppi',
      () async {
        final service = MockAiClothingAnalyzerService();
        final container = _makeContainer(service: service);
        addTearDown(container.dispose);

        final fileA = File('${Directory.systemTemp.path}/retry_a.png')
          ..writeAsBytesSync(Uint8List.fromList([1]));
        final fileB = File('${Directory.systemTemp.path}/retry_b.png')
          ..writeAsBytesSync(Uint8List.fromList([2]));

        // Primo giro: A passa, B fallisce.
        var call = 0;
        when(() => service.processClothingItem(any())).thenAnswer((_) async {
          call++;
          if (call == 1) return [_fakeResult(name: 'A')];
          throw const AnalysisNetworkException('down');
        });

        final notifier = container.read(aiImportNotifierProvider.notifier);
        await notifier.processFiles([fileA, fileB]);

        expect(
          container.read(aiImportNotifierProvider).photoGroups,
          hasLength(1),
        );
        expect(
          container.read(aiImportNotifierProvider).failureReason,
          AiFailureReason.network,
        );

        // Secondo giro: solo B, che stavolta passa.
        when(
          () => service.processClothingItem(any()),
        ).thenAnswer((_) async => [_fakeResult(name: 'B')]);
        await notifier.retryFailed();

        final state = container.read(aiImportNotifierProvider);
        // Due gruppi, non tre: A non è stato rianalizzato.
        expect(state.photoGroups, hasLength(2));
        expect(state.photoGroups.map((g) => g.results.first.name), ['A', 'B']);
        expect(state.failureReason, isNull);
      },
    );

    test('è un no-op se non è rimasto nulla da riprovare', () async {
      final service = MockAiClothingAnalyzerService();
      final container = _makeContainer(service: service);
      addTearDown(container.dispose);

      await _seedOneGroup(container, service);
      clearInteractions(service);

      await container.read(aiImportNotifierProvider.notifier).retryFailed();
      verifyNever(() => service.processClothingItem(any()));
    });
  });

  // ── deleteItem() ───────────────────────────────────────────────────────────

  group('deleteItem()', () {
    test(
      'removes item from group; group remains with remaining items',
      () async {
        final service = MockAiClothingAnalyzerService();
        final container = _makeContainer(service: service);
        addTearDown(container.dispose);

        await _seedOneGroup(
          container,
          service,
          results: [
            _fakeResult(name: 'T-Shirt'),
            _fakeResult(name: 'Jeans'),
          ],
        );

        container.read(aiImportNotifierProvider.notifier).deleteItem(0, 0);

        final state = container.read(aiImportNotifierProvider);
        expect(state.photoGroups.length, 1);
        expect(state.photoGroups.first.results.length, 1);
        expect(state.photoGroups.first.results.first.name, 'Jeans');
      },
    );

    test('removes entire group when last item is deleted', () async {
      final service = MockAiClothingAnalyzerService();
      final container = _makeContainer(service: service);
      addTearDown(container.dispose);

      await _seedOneGroup(container, service);

      container.read(aiImportNotifierProvider.notifier).deleteItem(0, 0);

      final state = container.read(aiImportNotifierProvider);
      expect(state.photoGroups, isEmpty);
    });
  });

  // ── updateItemName() ───────────────────────────────────────────────────────

  group('updateItemName()', () {
    test(
      'updates name at correct group/item position; other items unchanged',
      () async {
        final service = MockAiClothingAnalyzerService();
        final container = _makeContainer(service: service);
        addTearDown(container.dispose);

        await _seedOneGroup(
          container,
          service,
          results: [
            _fakeResult(name: 'T-Shirt'),
            _fakeResult(name: 'Jeans'),
          ],
        );

        container
            .read(aiImportNotifierProvider.notifier)
            .updateItemName(0, 0, 'Polo');

        final state = container.read(aiImportNotifierProvider);
        expect(state.photoGroups.first.results[0].name, 'Polo');
        expect(state.photoGroups.first.results[1].name, 'Jeans');
      },
    );

    test('multi-group: update in group 1 does not affect group 0', () async {
      final service = MockAiClothingAnalyzerService();
      final container = _makeContainer(service: service);
      addTearDown(container.dispose);

      // Seed two separate groups (one call each).
      _stubServiceSuccess(service, [_fakeResult(name: 'T-Shirt')]);
      await container.read(aiImportNotifierProvider.notifier).processFiles([
        _fakeFile(),
      ]);
      _stubServiceSuccess(service, [_fakeResult(name: 'Jeans')]);
      await container.read(aiImportNotifierProvider.notifier).processFiles([
        _fakeFile(),
      ]);

      container
          .read(aiImportNotifierProvider.notifier)
          .updateItemName(1, 0, 'Pantaloni');

      final state = container.read(aiImportNotifierProvider);
      expect(state.photoGroups[0].results[0].name, 'T-Shirt');
      expect(state.photoGroups[1].results[0].name, 'Pantaloni');
    });
  });

  // ── setSelectedHouseId() ───────────────────────────────────────────────────

  group('setSelectedHouseId()', () {
    test('updates selectedHouseId in state', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      container
          .read(aiImportNotifierProvider.notifier)
          .setSelectedHouseId('house-42');

      final state = container.read(aiImportNotifierProvider);
      expect(state.selectedHouseId, 'house-42');
    });
  });

  // ── reset() ────────────────────────────────────────────────────────────────

  group('reset()', () {
    test('resets state to const AiImportState()', () async {
      final service = MockAiClothingAnalyzerService();
      final container = _makeContainer(service: service);
      addTearDown(container.dispose);

      await _seedOneGroup(container, service);
      container
          .read(aiImportNotifierProvider.notifier)
          .setSelectedHouseId('h1');

      container.read(aiImportNotifierProvider.notifier).reset();

      final state = container.read(aiImportNotifierProvider);
      expect(state, const AiImportState());
    });
  });

  // ── saveItems() ────────────────────────────────────────────────────────────

  group('saveItems()', () {
    test(
      'null selectedHouseId: sets errorMessage, does NOT call repository',
      () async {
        final itemRepo = MockItemRepository();
        final container = _makeContainer(itemRepo: itemRepo);
        addTearDown(container.dispose);

        await container.read(aiImportNotifierProvider.notifier).saveItems();

        final state = container.read(aiImportNotifierProvider);
        expect(state.errorMessage, isNotNull);
        // easy_localization returns the key itself in tests
        expect(state.errorMessage, contains('ai_import.no_house_selected'));
        verifyNever(() => itemRepo.insertMultipleItems(any()));
      },
    );

    test('empty results: returns early, state unchanged', () async {
      final itemRepo = MockItemRepository();
      final container = _makeContainer(itemRepo: itemRepo);
      addTearDown(container.dispose);

      container
          .read(aiImportNotifierProvider.notifier)
          .setSelectedHouseId('house-1');
      // No processFiles call → allResults is empty

      await container.read(aiImportNotifierProvider.notifier).saveItems();

      verifyNever(() => itemRepo.insertMultipleItems(any()));
      expect(container.read(aiImportNotifierProvider).isLoading, isFalse);
    });

    test(
      'success: calls insertMultipleItems with correct houseId, aiMetadata non-null, state resets',
      () async {
        final service = MockAiClothingAnalyzerService();
        final itemRepo = MockItemRepository();
        final syncOrchestrator = MockSyncOrchestrator();
        final container = _makeContainer(
          service: service,
          itemRepo: itemRepo,
          syncOrchestrator: syncOrchestrator,
        );
        addTearDown(container.dispose);

        when(
          () => itemRepo.insertMultipleItems(any()),
        ).thenAnswer((_) async {});
        when(() => syncOrchestrator.requestSync()).thenReturn(null);

        await _seedOneGroup(container, service);
        container
            .read(aiImportNotifierProvider.notifier)
            .setSelectedHouseId('house-99');

        await container.read(aiImportNotifierProvider.notifier).saveItems();

        final captured = verify(
          () => itemRepo.insertMultipleItems(captureAny()),
        ).captured;
        final items = captured.first as List<ItemModel>;

        expect(items.length, 1);
        expect(items.first.houseId, 'house-99');
        expect(items.first.aiMetadata, isNotNull);

        // State resets after success
        expect(container.read(aiImportNotifierProvider), const AiImportState());
      },
    );

    test('error from repository: sets errorMessage, isLoading false', () async {
      final service = MockAiClothingAnalyzerService();
      final itemRepo = MockItemRepository();
      final syncOrchestrator = MockSyncOrchestrator();
      final container = _makeContainer(
        service: service,
        itemRepo: itemRepo,
        syncOrchestrator: syncOrchestrator,
      );
      addTearDown(container.dispose);

      when(
        () => itemRepo.insertMultipleItems(any()),
      ).thenThrow(Exception('DB write failed'));
      when(() => syncOrchestrator.requestSync()).thenReturn(null);

      await _seedOneGroup(container, service);
      container
          .read(aiImportNotifierProvider.notifier)
          .setSelectedHouseId('house-99');

      await container.read(aiImportNotifierProvider.notifier).saveItems();

      final state = container.read(aiImportNotifierProvider);
      expect(state.errorMessage, isNotNull);
      expect(state.isLoading, isFalse);
    });
  });

  // ── saveItemsOnboarding() ──────────────────────────────────────────────────

  group('saveItemsOnboarding()', () {
    test(
      'success: calls createHouseWithItems, calls completeAi (saveStep), state resets',
      () async {
        final service = MockAiClothingAnalyzerService();
        final houseRepo = MockHouseRepository();
        final itemRepo = MockItemRepository();
        final syncOrchestrator = MockSyncOrchestrator();
        final onboardingRepo = MockOnboardingRepository();

        final container = _makeContainer(
          service: service,
          houseRepo: houseRepo,
          itemRepo: itemRepo,
          syncOrchestrator: syncOrchestrator,
          onboardingRepo: onboardingRepo,
        );
        addTearDown(container.dispose);

        when(
          () => houseRepo.createHouseWithItems(any(), any()),
        ).thenAnswer((_) async => 'new-house-id');
        when(() => syncOrchestrator.requestSync()).thenReturn(null);
        _setupOnboardingMock(onboardingRepo);

        // Initialise the onboarding provider so completeAi has state to act on
        await container.read(postLoginOnboardingProvider.future);

        await _seedOneGroup(container, service);
        await container
            .read(aiImportNotifierProvider.notifier)
            .saveItemsOnboarding();

        verify(() => houseRepo.createHouseWithItems(any(), any())).called(1);
        verify(() => onboardingRepo.saveStep(any())).called(1);

        // State resets after success
        expect(container.read(aiImportNotifierProvider), const AiImportState());
      },
    );

    test('empty results: returns early without calling repository', () async {
      final houseRepo = MockHouseRepository();
      final container = _makeContainer(houseRepo: houseRepo);
      addTearDown(container.dispose);

      // No processFiles → allResults is empty
      await container
          .read(aiImportNotifierProvider.notifier)
          .saveItemsOnboarding();

      verifyNever(() => houseRepo.createHouseWithItems(any(), any()));
      expect(container.read(aiImportNotifierProvider).isLoading, isFalse);
    });
  });
}
