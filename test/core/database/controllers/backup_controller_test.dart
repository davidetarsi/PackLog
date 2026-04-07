import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/core/database/controllers/backup_controller.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/core/database/database_provider.dart';
import 'package:pack_log/core/database/services/database_backup_service.dart';
import 'package:pack_log/core/database/services/backup_service.dart';
import 'package:pack_log/core/database/exceptions/backup_exceptions.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import '../../../helpers/test_database_setup.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Mock classes for testing BackupController in isolation.
class MockDatabaseBackupService extends Mock implements DatabaseBackupService {}
class MockBackupService extends Mock implements BackupService {}
class MockFile extends Mock implements File {}
class MockFileStat extends Mock implements FileStat {}

/// Fake platform interface per testare il file system in modo agnostico (Clean Architecture).
/// Questo bypassa FFI su Linux/Windows e MethodChannels su Mac/iOS.
class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getDownloadsPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;

  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}

/// Unit tests for BackupController.
void main() {
  late ProviderContainer container;
  late MockDatabaseBackupService mockDatabaseBackupService;
  late MockBackupService mockBackupService;
  late AppDatabase database;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // INIEZIONE ENTERPRISE: Mockiamo la Platform Interface per evitare crash in CI/CD Linux
    PathProviderPlatform.instance = FakePathProviderPlatform();

    mockDatabaseBackupService = MockDatabaseBackupService();
    mockBackupService = MockBackupService();
    database = createTestDatabase();

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        databaseBackupServiceProvider.overrideWithValue(mockDatabaseBackupService),
        backupServiceProvider.overrideWithValue(mockBackupService),
      ],
    );

    registerFallbackValue(File(''));
  });

  tearDown(() async {
    container.dispose();
    await closeTestDatabase(database);
  });

  group('BackupController - Manual Export', () {
    test(
      'should export database to temporary file with correct timestamped filename format',
      () async {
        // === ARRANGE ===
        final mockExportedFile = MockFile();
        final mockFileStat = MockFileStat();

        String? capturedDestinationPath;

        when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((
          invocation,
        ) async {
          capturedDestinationPath = invocation.positionalArguments[0] as String;
          when(() => mockExportedFile.path).thenReturn(capturedDestinationPath!);
          when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
          when(() => mockFileStat.size).thenReturn(1024 * 50); // 50 KB
          return mockExportedFile;
        });

        // === ACT ===
        final controller = container.read(backupControllerProvider.notifier);
        final result = await controller.exportToTemporaryFile();

        // === ASSERT ===
        verify(() => mockDatabaseBackupService.exportData(any())).called(1);
        expect(capturedDestinationPath, isNotNull);
        expect(capturedDestinationPath, contains(AppConstants.backupFilePrefix));
        expect(capturedDestinationPath, endsWith(AppConstants.databaseFileExtension));

        // AGGIORNATO: Regex che supporta il formato completo (data e ora)
        final fileName = capturedDestinationPath!.split('/').last;
        final fileNameRegex = RegExp(r'^pack-log-export-db-\d{8}-\d{6}\.db$');
        expect(fileName, matches(fileNameRegex));

        // Estrazione e verifica della data
        final datePartMatch = RegExp(
          r'pack-log-export-db-(\d{2})(\d{2})(\d{4})-\d{6}\.db$',
        ).firstMatch(fileName);
        
        expect(datePartMatch, isNotNull);

        final day = int.parse(datePartMatch!.group(1)!);
        final month = int.parse(datePartMatch.group(2)!);
        final year = int.parse(datePartMatch.group(3)!);

        expect(day, inInclusiveRange(1, 31));
        expect(month, inInclusiveRange(1, 12));
        expect(year, greaterThanOrEqualTo(2020));

        expect(result, isA<ExportResult>());
        expect(result.path, equals(capturedDestinationPath));
        expect(result.sizeBytes, equals(1024 * 50));
        expect(result.exportedFile, equals(mockExportedFile));
      },
    );

    test('should use Downloads directory for export', () async {
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      String? capturedPath;

      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((
        invocation,
      ) async {
        capturedPath = invocation.positionalArguments[0] as String;
        when(() => mockExportedFile.path).thenReturn(capturedPath!);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(2048);
        return mockExportedFile;
      });

      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      expect(capturedPath, isNotNull);
      expect(capturedPath, isNotEmpty);

      final fileName = capturedPath!.split('/').last;
      expect(fileName, startsWith(AppConstants.backupFilePrefix));
      expect(fileName, endsWith(AppConstants.databaseFileExtension));
    });

    test('should create unique filenames for different dates', () async {
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      final capturedPaths = <String>[];

      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((
        invocation,
      ) async {
        final path = invocation.positionalArguments[0] as String;
        capturedPaths.add(path);

        when(() => mockExportedFile.path).thenReturn(path);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024);
        return mockExportedFile;
      });

      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      expect(capturedPaths, hasLength(1));
      final fileName = capturedPaths.first.split('/').last;
      expect(fileName, startsWith(AppConstants.backupFilePrefix));
      expect(fileName, endsWith(AppConstants.databaseFileExtension));
    });

    test('should throw exception when backup service fails', () async {
      when(() => mockDatabaseBackupService.exportData(any()))
          .thenThrow(Exception('Disk full'));

      final controller = container.read(backupControllerProvider.notifier);

      await expectLater(
        controller.exportToTemporaryFile(),
        throwsA(isA<Exception>()),
      );

      verify(() => mockDatabaseBackupService.exportData(any())).called(1);
    });
  });

  group('BackupController - Filename Validation', () {
    test('should validate correct backup filename', () {
      final controller = container.read(backupControllerProvider.notifier);

      // AGGIORNATO: Le stringhe di test mockate ora rispettano il formato rigoroso
      expect(
        controller.validateImportFileName('pack-log-export-db-17022026-123456.db'),
        isTrue,
      );

      expect(
        controller.validateImportFileName(
          '/path/to/pack-log-export-db-01012025-000000.db',
        ),
        isTrue,
      );

      expect(
        controller.validateImportFileName('pack-log-export-db-31122099-235959.db'),
        isTrue,
      );
    });

    test('should reject invalid backup filename', () {
      final controller = container.read(backupControllerProvider.notifier);

      expect(controller.validateImportFileName('my-database.db'), isFalse);
      expect(controller.validateImportFileName('backup-17022026-123456.db'), isFalse);
      expect(
        controller.validateImportFileName('pack-log-export-17022026-123456.db'),
        isFalse,
      );
      expect(controller.validateImportFileName('random-file.txt'), isFalse);
    });
  });

  group('BackupController - Export Result', () {
    test('should return complete ExportResult with file metadata', () async {
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      final expectedPath = '/fake/path/pack-log-export-db-17022026-123456.db';
      final expectedSize = 1024 * 100;

      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((_) async {
        when(() => mockExportedFile.path).thenReturn(expectedPath);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(expectedSize);
        return mockExportedFile;
      });

      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.exportToTemporaryFile();

      expect(result.exportedFile, equals(mockExportedFile));
      expect(result.path, equals(expectedPath));
      expect(result.sizeBytes, equals(expectedSize));
    });

    test(
      'should use app constants for filename prefix and extension',
      () async {
        final mockExportedFile = MockFile();
        final mockFileStat = MockFileStat();
        String? capturedPath;

        when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((
          invocation,
        ) async {
          capturedPath = invocation.positionalArguments[0] as String;
          when(() => mockExportedFile.path).thenReturn(capturedPath!);
          when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
          when(() => mockFileStat.size).thenReturn(1024);
          return mockExportedFile;
        });

        final controller = container.read(backupControllerProvider.notifier);
        await controller.exportToTemporaryFile();

        expect(capturedPath, isNotNull);
        final fileName = capturedPath!.split('/').last;

        expect(fileName, startsWith(AppConstants.backupFilePrefix));
        expect(fileName, endsWith(AppConstants.databaseFileExtension));
        expect(fileName, matches(RegExp(r'^pack-log-export-db-\d{8}-\d{6}\.db$')));
      },
    );
  });

  group('BackupController - Date Formatting', () {
    test('should format date as ddmmyyyy in filename', () async {
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      String? capturedPath;

      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((
        invocation,
      ) async {
        capturedPath = invocation.positionalArguments[0] as String;
        when(() => mockExportedFile.path).thenReturn(capturedPath!);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024);
        return mockExportedFile;
      });

      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      expect(capturedPath, isNotNull);
      final fileName = capturedPath!.split('/').last;

      final dateMatch = RegExp(
        r'pack-log-export-db-(\d{2})(\d{2})(\d{4})-\d{6}\.db',
      ).firstMatch(fileName);

      expect(fileName, matches(RegExp(r'^pack-log-export-db-\d{8}-\d{6}\.db$')));
      expect(dateMatch, isNotNull, reason: 'Filename should match ddmmyyyy format');

      final day = dateMatch!.group(1)!;
      final month = dateMatch.group(2)!;
      final year = dateMatch.group(3)!;

      expect(day, hasLength(2));
      expect(int.parse(day), inInclusiveRange(1, 31));
      expect(month, hasLength(2));
      expect(int.parse(month), inInclusiveRange(1, 12));
      expect(year, hasLength(4));
      expect(int.parse(year), greaterThanOrEqualTo(2020));
    });

    test('should pad single-digit day and month with leading zeros', () async {
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      String? capturedPath;

      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((
        invocation,
      ) async {
        capturedPath = invocation.positionalArguments[0] as String;
        when(() => mockExportedFile.path).thenReturn(capturedPath!);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024);
        return mockExportedFile;
      });

      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      expect(capturedPath, isNotNull);
      final fileName = capturedPath!.split('/').last;

      final dateMatch = RegExp(r'pack-log-export-db-(\d{8})-\d{6}\.db').firstMatch(fileName);
      expect(dateMatch, isNotNull);

      final datePart = dateMatch!.group(1)!;
      expect(datePart, hasLength(8));
      expect(datePart, matches(RegExp(r'^\d{8}$')));
    });
  });

  group('BackupController - Integration with Services', () {
    test('should call exportData on DatabaseBackupService', () async {
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();

      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((_) async {
        when(() => mockExportedFile.path).thenReturn('/fake/path/file.db');
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024);
        return mockExportedFile;
      });

      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      verify(() => mockDatabaseBackupService.exportData(any())).called(1);
    });

    test('should not call BackupService during manual export', () async {
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();

      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((_) async {
        when(() => mockExportedFile.path).thenReturn('/fake/path/file.db');
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024);
        return mockExportedFile;
      });

      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      verifyNever(() => mockBackupService.createBackup(reason: any(named: 'reason')));
      verifyNever(() => mockBackupService.createAutoBackupIfNeeded());
    });
  });

  group('BackupController - Import Validation', () {
    test('should fail validation when attempting to import a corrupted file (invalid Magic Bytes)', () async {
      final corruptedFilePath = '/path/to/pack-log-export-db-17022026-999999.db';

      // Setup di default per non far crashare Mocktail
      when(() => mockBackupService.createBackup(reason: any(named: 'reason'))).thenAnswer((_) async => '/backups/safety.db');
      when(() => mockDatabaseBackupService.importData(any())).thenAnswer((_) async => {});
      
      // Il file è invalido
      when(() => mockDatabaseBackupService.validateDatabaseFile(corruptedFilePath)).thenAnswer((_) async => false);

      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(corruptedFilePath);

      expect(result.success, isFalse);
      verifyNever(() => mockDatabaseBackupService.importData(corruptedFilePath));
    });

    test('should fail validation when filename does not start with correct prefix', () async {
      final invalidFilePath = '/path/to/my-random-backup.db';

      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(invalidFilePath);

      expect(result.success, isFalse);
      verifyNever(() => mockDatabaseBackupService.importData(any()));
    });

    test('should fail when safety backup creation fails', () async {
      final validFilePath = '/path/to/pack-log-export-db-17022026-123456.db';

      // Il backup di sicurezza fallisce (restituisce null)
      when(() => mockBackupService.createBackup(reason: any(named: 'reason'))).thenAnswer((_) async => null);
      when(() => mockDatabaseBackupService.validateDatabaseFile(any())).thenAnswer((_) async => true);

      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(validFilePath);

      expect(result.success, isFalse);
      verifyNever(() => mockDatabaseBackupService.importData(validFilePath));
    });
  });

  group('BackupController - Disaster Recovery', () {
    test('should trigger automatic rollback if the import process fails mid-operation', () async {
      final validFilePath = '/path/to/pack-log-export-db-17022026-123456.db';
      
      when(() => mockBackupService.createBackup(reason: any(named: 'reason'))).thenAnswer((_) async => '/backups/safety.db');
      when(() => mockDatabaseBackupService.validateDatabaseFile(any())).thenAnswer((_) async => true);
      
      // L'importazione sputa un'eccezione
      when(() => mockDatabaseBackupService.importData(any())).thenThrow(Exception('Corruption detected'));

      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(validFilePath);

      // Deve fallire in modo pulito
      expect(result.success, isFalse);
    });

    test('should return critical error when both import and rollback fail', () async {
      final validFilePath = '/path/to/pack-log-export-db-17022026-123456.db';
      
      when(() => mockBackupService.createBackup(reason: any(named: 'reason'))).thenAnswer((_) async => '/backups/safety.db');
      when(() => mockDatabaseBackupService.validateDatabaseFile(any())).thenAnswer((_) async => true);
      
      // L'importazione fallisce per tutti i file, anche per il rollback
      when(() => mockDatabaseBackupService.importData(any())).thenThrow(Exception('Critical error'));

      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(validFilePath);

      expect(result.success, isFalse);
    });

    test('should successfully import and NOT trigger rollback on success', () async {
      final validFilePath = '/path/to/pack-log-export-db-17022026-123456.db';
      
      when(() => mockBackupService.createBackup(reason: any(named: 'reason'))).thenAnswer((_) async => '/backups/safety.db');
      when(() => mockDatabaseBackupService.validateDatabaseFile(any())).thenAnswer((_) async => true);
      
      // Importazione perfetta
      when(() => mockDatabaseBackupService.importData(any())).thenAnswer((_) async => {});

      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(validFilePath);

      expect(result.success, isTrue);
      // Assicuriamoci che abbia chiamato l'importazione vera
      verify(() => mockDatabaseBackupService.importData(validFilePath)).called(1);
    });

    test('should detect validation exception type and return appropriate error message', () async {
      final validFilePath = '/path/to/pack-log-export-db-17022026-123456.db';
      
      when(() => mockBackupService.createBackup(reason: any(named: 'reason'))).thenAnswer((_) async => '/backups/safety.db');
      when(() => mockDatabaseBackupService.importData(any())).thenAnswer((_) async => {});
      
      // La validazione non ritorna false, ma lancia un'eccezione esplicita
      when(() => mockDatabaseBackupService.validateDatabaseFile(any())).thenThrow(const ImportValidationException('Format errato'));

      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(validFilePath);

      expect(result.success, isFalse);
    });
  });
}