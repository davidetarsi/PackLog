import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/core/sync/sync_service.dart';
import 'package:pack_log/core/sync/sync_session.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/providers/luggage_provider.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/shared/widgets/sync_session_protection.dart';
import 'package:pack_log/shared/widgets/ds_error_state.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/memory_asset_loader.dart';

class _Service extends Mock implements SyncService {}

class _Connectivity extends Mock implements Connectivity {}

class _Monitoring extends Mock implements AppMonitoringService {}

class _Houses extends HouseNotifier {
  _Houses({this.loads, this.cursor});
  final List<Completer<List<HouseModel>>>? loads;
  final List<int>? cursor;
  @override
  Future<List<HouseModel>> build() {
    ref.watch(syncTriggerProvider);
    if (loads == null) return Future.value([]);
    final index = cursor == null ? 0 : cursor![0]++;
    return index >= loads!.length ? Future.value([]) : loads![index].future;
  }
}

class _Trips extends TripNotifier {
  _Trips({this.loads, this.cursor});
  final List<Completer<List<TripModel>>>? loads;
  final List<int>? cursor;
  @override
  Future<List<TripModel>> build() {
    ref.watch(syncTriggerProvider);
    if (loads == null) return Future.value([]);
    final index = cursor == null ? 0 : cursor![0]++;
    return index >= loads!.length ? Future.value([]) : loads![index].future;
  }
}

class _Luggages extends LuggageNotifier {
  _Luggages({this.loads, this.cursor});
  final List<Completer<List<LuggageModel>>>? loads;
  final List<int>? cursor;
  @override
  Future<List<LuggageModel>> build() {
    ref.watch(syncTriggerProvider);
    if (loads == null) return Future.value([]);
    final index = cursor == null ? 0 : cursor![0]++;
    return index >= loads!.length ? Future.value([]) : loads![index].future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(SyncLocalWriteBarrier());

  testWidgets(
    'preparation failure covers root dialog until retry is prepared',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      final service = _Service();
      final connectivity = _Connectivity();
      var network = ConnectivityResult.none;
      final monitoring = _Monitoring();
      when(() => service.bindSessionBarrier(any())).thenReturn(null);
      when(() => service.drainLocalWrites()).thenAnswer((_) async {});
      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => [network]);
      when(() => service.processQueue()).thenAnswer((_) async {});
      when(() => service.countPendingChanges()).thenAnswer((_) async => 0);
      when(() => service.fullPull(any())).thenAnswer((_) async {});
      when(
        () => monitoring.logBreadcrumb(
          any(),
          category: any(named: 'category'),
          data: any(named: 'data'),
        ),
      ).thenReturn(null);
      when(
        () => monitoring.captureException(
          any(),
          stackTrace: any(named: 'stackTrace'),
          tags: any(named: 'tags'),
        ),
      ).thenReturn(null);
      final orchestrator = SyncOrchestrator(
        service,
        monitoring,
        connectivity: connectivity,
      );
      await orchestrator.replaceSession(
        'A',
        prepareLocalData: () async => false,
      );
      await tester.pump();
      var dialogActionCalls = 0;
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
          path: 'assets/translations',
          assetLoader: MemoryAssetLoader(readAppTranslations()),
          fallbackLocale: const Locale('en', 'US'),
          startLocale: const Locale('it', 'IT'),
          saveLocale: false,
          child: ProviderScope(
            overrides: [
              syncOrchestratorProvider.overrideWith((ref) => orchestrator),
              houseNotifierProvider.overrideWith(_Houses.new),
              tripNotifierProvider.overrideWith(_Trips.new),
              luggageNotifierProvider.overrideWith(_Luggages.new),
            ],
            child: Builder(
              builder: (context) => MaterialApp(
                theme: AppTheme.light,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                builder: (context, child) => SyncSessionProtection(
                  child: child ?? const SizedBox.shrink(),
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: FilledButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            content: const Text('Cached A detail'),
                            actions: [
                              TextButton(
                                onPressed: () => dialogActionCalls++,
                                child: const Text('Cached A action'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('Open detail'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      expect(find.text('Cached A detail'), findsOneWidget);

      network = ConnectivityResult.wifi;
      final finishRetry = Completer<bool>();
      var attempts = 0;
      await orchestrator.replaceSession(
        'B',
        prepareLocalData: () async {
          attempts++;
          if (attempts == 1) throw StateError('failed before wipe');
          return finishRetry.future;
        },
      );
      await tester.pump();
      expect(find.text('errors.load_failed'.tr()), findsOneWidget);
      await tester.tap(find.text('Cached A action'), warnIfMissed: false);
      await tester.pump();
      expect(dialogActionCalls, 0);

      await tester.tap(find.text('common.retry'.tr()));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Cached A action'), warnIfMissed: false);
      await tester.pump();
      expect(dialogActionCalls, 0);

      finishRetry.complete(true);
      await tester.pumpAndSettle();
      expect(orchestrator.sessionReady, isTrue);
      orchestrator.dispose();
    },
  );

  testWidgets('account replacement stays covered until all local caches load', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final service = _Service();
    final connectivity = _Connectivity();
    when(() => service.bindSessionBarrier(any())).thenReturn(null);
    when(() => service.drainLocalWrites()).thenAnswer((_) async {});
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => service.processQueue()).thenAnswer((_) async {});
    when(() => service.countPendingChanges()).thenAnswer((_) async => 0);
    when(() => service.fullPull(any())).thenAnswer((_) async {});
    final monitoring = _Monitoring();
    when(
      () => monitoring.logBreadcrumb(
        any(),
        category: any(named: 'category'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => monitoring.captureException(
        any(),
        stackTrace: any(named: 'stackTrace'),
        tags: any(named: 'tags'),
      ),
    ).thenReturn(null);

    final orchestrator = SyncOrchestrator(
      service,
      monitoring,
      connectivity: connectivity,
    );
    final aHouses = Completer<List<HouseModel>>();
    final aTrips = Completer<List<TripModel>>();
    final aLuggages = Completer<List<LuggageModel>>();
    final bHouses = Completer<List<HouseModel>>();
    final bTrips = Completer<List<TripModel>>();
    final bLuggages = Completer<List<LuggageModel>>();
    final cHouses = Completer<List<HouseModel>>();
    final cTrips = Completer<List<TripModel>>();
    final cLuggages = Completer<List<LuggageModel>>();
    final dHouses = Completer<List<HouseModel>>();
    final dTrips = Completer<List<TripModel>>();
    final dLuggages = Completer<List<LuggageModel>>();
    final eHouses = Completer<List<HouseModel>>();
    final houseCursor = [0];
    final tripCursor = [0];
    final luggageCursor = [0];
    await orchestrator.replaceSession('A', prepareLocalData: () async => false);
    var childActions = 0;
    final container = ProviderContainer(
      overrides: [
        syncOrchestratorProvider.overrideWith((ref) => orchestrator),
        houseNotifierProvider.overrideWith(
          () => _Houses(
            loads: [aHouses, bHouses, cHouses, dHouses, eHouses],
            cursor: houseCursor,
          ),
        ),
        tripNotifierProvider.overrideWith(
          () => _Trips(
            loads: [aTrips, bTrips, cTrips, dTrips],
            cursor: tripCursor,
          ),
        ),
        luggageNotifierProvider.overrideWith(
          () => _Luggages(
            loads: [aLuggages, bLuggages, cLuggages, dLuggages],
            cursor: luggageCursor,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
        path: 'assets/translations',
        assetLoader: MemoryAssetLoader(readAppTranslations()),
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        child: UncontrolledProviderScope(
          container: container,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.light,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              builder: (context, child) => SyncSessionProtection(
                child: child ?? const SizedBox.shrink(),
              ),
              home: Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => childActions++,
                    child: const Text('Child A'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    aHouses.complete([
      HouseModel(
        id: 'cached-a',
        name: 'Cached A',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    aTrips.complete([]);
    aLuggages.complete([]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Child A'), findsOneWidget);
    expect(
      container.read(houseNotifierProvider).value!.single.name,
      'Cached A',
    );

    await orchestrator.replaceSession(
      'B',
      prepareLocalData: () async {
        container.read(syncTriggerProvider.notifier).increment();
        return true;
      },
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      container.read(houseNotifierProvider).value!.single.name,
      'Cached A',
    );
    expect(container.read(houseNotifierProvider).isLoading, isTrue);
    await tester.tap(find.text('Child A'), warnIfMissed: false);
    expect(childActions, 0);

    bHouses.completeError(StateError('local cache read failed'));
    await tester.pump();
    await tester.pump();
    expect(container.read(houseNotifierProvider).hasError, isTrue);
    expect(find.byType(DsErrorState), findsOneWidget);
    expect(find.text('errors.load_failed'.tr()), findsOneWidget);
    bTrips.complete([]);
    bLuggages.complete([]);
    await tester.pump();
    await tester.tap(find.text('common.retry'.tr()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('errors.load_failed'.tr()), findsNothing);
    cHouses.completeError(StateError('retry cache read failed'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(DsErrorState), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('common.retry'.tr()));
    await tester.pump();
    dHouses.complete([]);
    dTrips.complete([]);
    dLuggages.complete([]);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    container.read(syncTriggerProvider.notifier).increment();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(container.read(houseNotifierProvider).isLoading, isTrue);
    await tester.tap(find.text('Child A'));
    expect(childActions, 1);
    container.dispose();
    orchestrator.dispose();
  });
}
