import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/tables/mixins/syncable_table.dart';
import 'package:pack_log/core/monitoring/monitoring_service.dart';
import 'package:pack_log/core/sync/supabase_repository.dart';
import 'package:pack_log/core/sync/sync_orchestrator.dart';
import 'package:pack_log/core/sync/sync_service.dart';
import 'package:pack_log/core/sync/tombstone_config_service.dart';

import '../helpers/test_database_setup.dart';

// === MOCKS ===

class MockSupabaseRepository extends Mock implements SupabaseRepository {}

class MockConnectivity extends Mock implements Connectivity {}

class MockMonitoringService extends Mock implements AppMonitoringService {}

class MockTombstoneConfigService extends Mock
    implements TombstoneConfigService {}

void main() {
  late AppDatabase database;
  late MockSupabaseRepository mockRemote;
  late MockConnectivity mockConnectivity;
  late MockMonitoringService mockMonitoring;
  late MockTombstoneConfigService mockTombstoneConfig;
  late StreamController<List<ConnectivityResult>> connectivityController;
  late SyncService syncService;
  late SyncOrchestrator orchestrator;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    database = createTestDatabase();
    mockRemote = MockSupabaseRepository();
    mockConnectivity = MockConnectivity();
    mockMonitoring = MockMonitoringService();
    mockTombstoneConfig = MockTombstoneConfigService();
    connectivityController =
        StreamController<List<ConnectivityResult>>.broadcast();

    when(
      () => mockConnectivity.onConnectivityChanged,
    ).thenAnswer((_) => connectivityController.stream);
    when(
      () => mockMonitoring.logBreadcrumb(
        any(),
        category: any(named: 'category'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);

    when(
      () => mockTombstoneConfig.getRetentionDays(),
    ).thenAnswer((_) async => 15);

    syncService = SyncService(
      housesDao: database.housesDao,
      itemsDao: database.itemsDao,
      spacesDao: database.spacesDao,
      luggagesDao: database.luggagesDao,
      tripsDao: database.tripsDao,
      remote: mockRemote,
      monitoring: mockMonitoring,
      tombstoneConfig: mockTombstoneConfig,
    );

    orchestrator = SyncOrchestrator(
      syncService,
      mockMonitoring,
      connectivity: mockConnectivity,
    );
    orchestrator.init();
  });

  tearDown(() async {
    orchestrator.dispose();
    connectivityController.close();
    await closeTestDatabase(database);
  });

  group('Airplane Mode - Push (Local Wins)', () {
    test('local trip gets pushed to remote when server has no copy', () async {
      // 1. Simula Rete = Offline (nessun evento di connettività)
      final createdAt = DateTime(2026, 5, 1, 10, 0);

      // 2. L'utente crea un nuovo Trip in locale (syncStatus = pendingCreate)
      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: 'trip-local-1',
          name: 'Vacanza Roma',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      // 3. L'utente modifica il viaggio (updatedAt locale = now)
      final modifiedAt = DateTime(2026, 5, 1, 12, 0);
      await database.tripsDao.updateTrip(
        TripsCompanion(
          id: const Value('trip-local-1'),
          name: const Value('Vacanza Roma - Aggiornato'),
          createdAt: Value(createdAt),
          updatedAt: Value(modifiedAt),
          syncStatus: const Value(SyncStatus.pendingCreate),
        ),
      );

      // Verifica stato pre-sync
      final preSyncTrip = await database.tripsDao.getTripById('trip-local-1');
      expect(preSyncTrip!.syncStatus, equals(SyncStatus.pendingCreate));

      // 4. Configura mock: il server NON conosce questo viaggio
      when(
        () => mockRemote.fetchTripById(
          'trip-local-1',
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async => null);

      when(
        () => mockRemote.upsertTrip(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async => DateTime.utc(2026, 1, 1));

      // Nessun altro record pending (houses/items)
      when(
        () => mockRemote.fetchHouseById(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockRemote.fetchItemById(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async => null);

      // 5. Simula Rete = Online → triggera l'orchestratore
      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 6. Verifica che upsertTrip venga chiamato esattamente 1 volta
      verify(
        () => mockRemote.upsertTrip(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).called(1);

      // 7. Verifica che il DB locale ora abbia syncStatus == synced
      final syncedTrip = await database.tripsDao.getTripById('trip-local-1');
      expect(syncedTrip!.syncStatus, equals(SyncStatus.synced));
      expect(syncedTrip.name, equals('Vacanza Roma - Aggiornato'));
    });
  });

  group('Airplane Mode - Pull (Remote Wins)', () {
    test('remote overwrites local when remote updatedAt is newer', () async {
      final t1 = DateTime(2026, 5, 1, 8, 0);

      // 1. Un Trip esiste già in locale con syncStatus = synced e updatedAt = T1
      await database.tripsDao.insertTrip(
        TripsCompanion.insert(
          id: 'trip-conflict-1',
          name: 'Weekend Firenze',
          createdAt: t1,
          updatedAt: t1,
          syncStatus: const Value(SyncStatus.synced),
        ),
      );

      // 2. L'utente modifica il viaggio offline (updatedAt = T2, stato = pendingUpdate)
      final t2 = DateTime(2026, 5, 1, 10, 0);
      await database.tripsDao.updateTrip(
        TripsCompanion(
          id: const Value('trip-conflict-1'),
          name: const Value('Weekend Firenze - Offline Edit'),
          createdAt: Value(t1),
          updatedAt: Value(t2),
          syncStatus: const Value(SyncStatus.pendingUpdate),
        ),
      );

      // Verifica stato pre-sync
      final preSyncTrip = await database.tripsDao.getTripById(
        'trip-conflict-1',
      );
      expect(preSyncTrip!.syncStatus, equals(SyncStatus.pendingUpdate));
      expect(preSyncTrip.name, equals('Weekend Firenze - Offline Edit'));

      // 3. Configura mock: il server ha una versione con T3 > T2
      //    (un altro dispositivo ha modificato lo stesso viaggio)
      final t3 = DateTime(2026, 5, 1, 14, 0);
      when(
        () => mockRemote.fetchTripById(
          'trip-conflict-1',
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer(
        (_) async => {
          'id': 'trip-conflict-1',
          'user_id': null,
          'name': 'Weekend Firenze - Server Edit',
          'description': 'Modificato da altro device',
          'departure_date_time': null,
          'return_date_time': null,
          'destination_house_id': null,
          'location_place_id': null,
          'location_display_name': null,
          'location_name': null,
          'location_city': null,
          'location_state': null,
          'location_country': null,
          'location_type': null,
          'location_lat': null,
          'location_lon': null,
          'is_saved': false,
          'created_at': t1.toIso8601String(),
          'updated_at': t3.toIso8601String(),
          'is_deleted': false,
        },
      );

      // Nessun altro record pending
      when(
        () => mockRemote.fetchHouseById(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockRemote.fetchItemById(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      ).thenAnswer((_) async => null);

      // 4. Simula Rete = Online → triggera l'orchestratore
      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 5. Verifica che upsertTrip NON venga MAI chiamato (il server vince)
      verifyNever(
        () => mockRemote.upsertTrip(
          any(),
          sentryTrace: any(named: 'sentryTrace'),
        ),
      );

      // 6. Verifica che il DB locale sia stato sovrascritto con i dati remoti
      final syncedTrip = await database.tripsDao.getTripById('trip-conflict-1');
      expect(syncedTrip!.name, equals('Weekend Firenze - Server Edit'));
      expect(syncedTrip.description, equals('Modificato da altro device'));
      expect(syncedTrip.syncStatus, equals(SyncStatus.synced));
    });
  });
}
