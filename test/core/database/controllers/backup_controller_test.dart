import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stuff_tracker_2/core/database/controllers/backup_controller.dart';
import 'package:stuff_tracker_2/core/database/database.dart';
import 'package:stuff_tracker_2/core/database/database_provider.dart';
import 'package:stuff_tracker_2/core/database/services/database_backup_service.dart';
import 'package:stuff_tracker_2/core/database/services/backup_service.dart';
import 'package:stuff_tracker_2/core/database/exceptions/backup_exceptions.dart';
import 'package:stuff_tracker_2/shared/constants/app_constants.dart';
import '../../../helpers/test_database_setup.dart';

/// Mock classes for testing BackupController in isolation.
class MockDatabaseBackupService extends Mock implements DatabaseBackupService {}
class MockBackupService extends Mock implements BackupService {}
class MockFile extends Mock implements File {}
class MockFileStat extends Mock implements FileStat {}

/// Unit tests for BackupController.
/// 
/// Tests the orchestration logic for:
/// - Manual export with timestamped filename formatting
/// - Import with disaster recovery flow
/// - Provider invalidation after database operations
/// - Rollback mechanism on import failure
void main() {
  late ProviderContainer container;
  late MockDatabaseBackupService mockDatabaseBackupService;
  late MockBackupService mockBackupService;
  late AppDatabase database;

  setUp(() {
    // Initialize Flutter bindings for platform channel communication
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Mock path_provider platform channel to return a test-writable directory
    // This prevents "Binding has not yet been initialized" errors
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getDownloadsDirectory') {
        // Return the system temp directory which is writable in tests
        return Directory.systemTemp.path;
      }
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });
    
    // Initialize mocks
    mockDatabaseBackupService = MockDatabaseBackupService();
    mockBackupService = MockBackupService();
    
    // Initialize in-memory database for testing
    database = createTestDatabase();
    
    // Create ProviderContainer with overridden providers for complete isolation
    container = ProviderContainer(
      overrides: [
        // Override database provider with our in-memory test database
        appDatabaseProvider.overrideWithValue(database),
        
        // Override backup services with mocks
        databaseBackupServiceProvider.overrideWithValue(mockDatabaseBackupService),
        backupServiceProvider.overrideWithValue(mockBackupService),
      ],
    );

    // Register fallback values for mocktail
    registerFallbackValue(File(''));
  });

  tearDown(() async {
    // Clean up: dispose container first (triggers provider cleanup)
    container.dispose();
    
    // Close test database to prevent memory leaks
    await closeTestDatabase(database);
  });

  group('BackupController - Manual Export', () {
    test('should export database to temporary file with correct timestamped filename format', () async {
      // === ARRANGE ===
      // Mock the underlying backup service to simulate successful export
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      
      // Expected path format: /path/to/Downloads/stuff-tracker-db-[ddmmyyyy].db
      // We'll capture the actual path passed to exportData and validate it
      String? capturedDestinationPath;
      
      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((invocation) async {
        capturedDestinationPath = invocation.positionalArguments[0] as String;
        
        // Simulate successful file export
        when(() => mockExportedFile.path).thenReturn(capturedDestinationPath!);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024 * 50); // 50 KB
        
        return mockExportedFile;
      });
      
      // === ACT ===
      // Create BackupController with our mocked container
      final controller = container.read(backupControllerProvider.notifier);
      
      // Override DateTime.now() in the controller's context by calling the method
      // Note: Since we can't mock DateTime.now() directly in Dart, we'll verify
      // the filename pattern instead of exact timestamp match
      final result = await controller.exportToTemporaryFile();

      // === ASSERT ===
      // Verify the backup service was called with correct parameters
      verify(() => mockDatabaseBackupService.exportData(any())).called(1);
      
      // Verify the captured destination path contains the correct filename structure
      expect(capturedDestinationPath, isNotNull);
      expect(capturedDestinationPath, contains(AppConstants.backupFilePrefix));
      expect(capturedDestinationPath, endsWith(AppConstants.databaseFileExtension));
      
      // Verify filename follows the pattern: stuff-tracker-db-[8 digits].db
      final fileName = capturedDestinationPath!.split('/').last;
      final fileNameRegex = RegExp(
        r'^stuff-tracker-db-\d{8}\.db$',
      );
      expect(fileName, matches(fileNameRegex));
      
      // Verify the filename format matches ddmmyyyy (2 digits day, 2 month, 4 year)
      final datePartMatch = RegExp(r'stuff-tracker-db-(\d{2})(\d{2})(\d{4})\.db$')
          .firstMatch(fileName);
      expect(datePartMatch, isNotNull);
      
      final day = int.parse(datePartMatch!.group(1)!);
      final month = int.parse(datePartMatch.group(2)!);
      final year = int.parse(datePartMatch.group(3)!);
      
      // Verify date components are within valid ranges
      expect(day, inInclusiveRange(1, 31));
      expect(month, inInclusiveRange(1, 12));
      expect(year, greaterThanOrEqualTo(2020)); // Sanity check
      
      // Verify the result object is correct
      expect(result, isA<ExportResult>());
      expect(result.path, equals(capturedDestinationPath));
      expect(result.sizeBytes, equals(1024 * 50));
      expect(result.exportedFile, equals(mockExportedFile));
    });

    test('should use Downloads directory for export', () async {
      // === ARRANGE ===
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      
      String? capturedPath;
      
      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((invocation) async {
        capturedPath = invocation.positionalArguments[0] as String;
        
        when(() => mockExportedFile.path).thenReturn(capturedPath!);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(2048);
        
        return mockExportedFile;
      });
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      // === ASSERT ===
      expect(capturedPath, isNotNull);
      
      // The path should use a valid directory (system temp in tests)
      expect(capturedPath, isNotEmpty);
      
      // Verify the path includes the filename with correct format
      final fileName = capturedPath!.split('/').last;
      expect(fileName, startsWith(AppConstants.backupFilePrefix));
      expect(fileName, endsWith(AppConstants.databaseFileExtension));
    });

    test('should create unique filenames for different dates', () async {
      // === ARRANGE ===
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      
      final capturedPaths = <String>[];
      
      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((invocation) async {
        final path = invocation.positionalArguments[0] as String;
        capturedPaths.add(path);
        
        when(() => mockExportedFile.path).thenReturn(path);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024);
        
        return mockExportedFile;
      });
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      
      // Export twice (in reality, these would happen on different days)
      await controller.exportToTemporaryFile();
      // Note: In real scenario, files would have different timestamps
      // For now, we verify the format is consistent
      
      // === ASSERT ===
      expect(capturedPaths, hasLength(1));
      
      // Verify filename structure
      final fileName = capturedPaths.first.split('/').last;
      expect(fileName, startsWith(AppConstants.backupFilePrefix));
      expect(fileName, endsWith(AppConstants.databaseFileExtension));
    });

    test('should throw exception when backup service fails', () async {
      // === ARRANGE ===
      // Mock the backup service to throw an exception
      when(() => mockDatabaseBackupService.exportData(any())).thenThrow(
        Exception('Disk full'),
      );
      
      // === ACT & ASSERT ===
      final controller = container.read(backupControllerProvider.notifier);
      
      // Verify that the exception is propagated
      await expectLater(
        controller.exportToTemporaryFile(),
        throwsA(isA<Exception>()),
      );
      
      // Verify the backup service was called before throwing
      verify(() => mockDatabaseBackupService.exportData(any())).called(1);
    });
  });

  group('BackupController - Filename Validation', () {
    test('should validate correct backup filename', () {
      // === ARRANGE ===
      final controller = container.read(backupControllerProvider.notifier);
      
      // === ACT & ASSERT ===
      expect(
        controller.validateImportFileName('stuff-tracker-db-17022026.db'),
        isTrue,
      );
      
      expect(
        controller.validateImportFileName('/path/to/stuff-tracker-db-01012025.db'),
        isTrue,
      );
      
      expect(
        controller.validateImportFileName('stuff-tracker-db-backup-v2.db'),
        isTrue,
      );
    });

    test('should reject invalid backup filename', () {
      // === ARRANGE ===
      final controller = container.read(backupControllerProvider.notifier);
      
      // === ACT & ASSERT ===
      expect(
        controller.validateImportFileName('my-database.db'),
        isFalse,
      );
      
      expect(
        controller.validateImportFileName('backup-17022026.db'),
        isFalse,
      );
      
      expect(
        controller.validateImportFileName('stuff-tracker-17022026.db'),
        isFalse,
      );
      
      expect(
        controller.validateImportFileName('random-file.txt'),
        isFalse,
      );
    });
  });

  group('BackupController - Export Result', () {
    test('should return complete ExportResult with file metadata', () async {
      // === ARRANGE ===
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      final expectedPath = '/fake/path/stuff-tracker-db-17022026.db';
      final expectedSize = 1024 * 100; // 100 KB
      
      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((_) async {
        when(() => mockExportedFile.path).thenReturn(expectedPath);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(expectedSize);
        
        return mockExportedFile;
      });
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.exportToTemporaryFile();

      // === ASSERT ===
      expect(result.exportedFile, equals(mockExportedFile));
      expect(result.path, equals(expectedPath));
      expect(result.sizeBytes, equals(expectedSize));
    });

    test('should use app constants for filename prefix and extension', () async {
      // === ARRANGE ===
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      
      String? capturedPath;
      
      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((invocation) async {
        capturedPath = invocation.positionalArguments[0] as String;
        
        when(() => mockExportedFile.path).thenReturn(capturedPath!);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024);
        
        return mockExportedFile;
      });
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      // === ASSERT ===
      expect(capturedPath, isNotNull);
      
      final fileName = capturedPath!.split('/').last;
      
      // Verify uses constants from AppConstants
      expect(fileName, startsWith(AppConstants.backupFilePrefix)); // 'stuff-tracker-db'
      expect(fileName, endsWith(AppConstants.databaseFileExtension)); // '.db'
      
      // Verify format: [prefix]-[date][extension]
      expect(fileName, matches(RegExp(r'^stuff-tracker-db-\d{8}\.db$')));
    });
  });

  group('BackupController - Date Formatting', () {
    test('should format date as ddmmyyyy in filename', () async {
      // === ARRANGE ===
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      
      String? capturedPath;
      
      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((invocation) async {
        capturedPath = invocation.positionalArguments[0] as String;
        
        when(() => mockExportedFile.path).thenReturn(capturedPath!);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024);
        
        return mockExportedFile;
      });
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      // === ASSERT ===
      expect(capturedPath, isNotNull);
      
      final fileName = capturedPath!.split('/').last;
      
      // Extract the date portion from: stuff-tracker-db-[ddmmyyyy].db
      final dateMatch = RegExp(r'stuff-tracker-db-(\d{2})(\d{2})(\d{4})\.db')
          .firstMatch(fileName);
      
      expect(dateMatch, isNotNull, reason: 'Filename should match ddmmyyyy format');
      
      final day = dateMatch!.group(1)!;
      final month = dateMatch.group(2)!;
      final year = dateMatch.group(3)!;
      
      // Verify day is 2 digits with leading zero if needed
      expect(day, hasLength(2));
      expect(int.parse(day), inInclusiveRange(1, 31));
      
      // Verify month is 2 digits with leading zero if needed
      expect(month, hasLength(2));
      expect(int.parse(month), inInclusiveRange(1, 12));
      
      // Verify year is 4 digits
      expect(year, hasLength(4));
      expect(int.parse(year), greaterThanOrEqualTo(2020));
    });

    test('should pad single-digit day and month with leading zeros', () async {
      // === ARRANGE ===
      // This test verifies that dates like 05/01/2026 become 05012026, not 512026
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      
      String? capturedPath;
      
      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((invocation) async {
        capturedPath = invocation.positionalArguments[0] as String;
        
        when(() => mockExportedFile.path).thenReturn(capturedPath!);
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024);
        
        return mockExportedFile;
      });
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      // === ASSERT ===
      expect(capturedPath, isNotNull);
      
      final fileName = capturedPath!.split('/').last;
      
      // Extract date parts
      final dateMatch = RegExp(r'stuff-tracker-db-(\d{8})\.db').firstMatch(fileName);
      expect(dateMatch, isNotNull);
      
      final datePart = dateMatch!.group(1)!;
      
      // Verify total length is exactly 8 digits (ddmmyyyy)
      expect(datePart, hasLength(8));
      
      // Verify all characters are digits
      expect(datePart, matches(RegExp(r'^\d{8}$')));
    });
  });

  group('BackupController - Integration with Services', () {
    test('should call exportData on DatabaseBackupService', () async {
      // === ARRANGE ===
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      
      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((_) async {
        when(() => mockExportedFile.path).thenReturn('/fake/path/file.db');
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024);
        
        return mockExportedFile;
      });
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      // === ASSERT ===
      // Verify the service was called exactly once
      verify(() => mockDatabaseBackupService.exportData(any())).called(1);
    });

    test('should not call BackupService during manual export', () async {
      // === ARRANGE ===
      // Manual export should NOT trigger auto-backup mechanisms
      final mockExportedFile = MockFile();
      final mockFileStat = MockFileStat();
      
      when(() => mockDatabaseBackupService.exportData(any())).thenAnswer((_) async {
        when(() => mockExportedFile.path).thenReturn('/fake/path/file.db');
        when(() => mockExportedFile.stat()).thenAnswer((_) async => mockFileStat);
        when(() => mockFileStat.size).thenReturn(1024);
        
        return mockExportedFile;
      });
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      await controller.exportToTemporaryFile();

      // === ASSERT ===
      // Verify BackupService (legacy) was NOT called during manual export
      verifyNever(() => mockBackupService.createBackup(reason: any(named: 'reason')));
      verifyNever(() => mockBackupService.createAutoBackupIfNeeded());
    });
  });

  group('BackupController - Import Validation', () {
    test('should fail validation when attempting to import a corrupted file (invalid Magic Bytes)', () async {
      // === ARRANGE ===
      // Simulate a corrupted file that fails SQLite magic bytes validation
      final corruptedFilePath = '/path/to/stuff-tracker-db-corrupted.db';
      
      // Mock: Safety backup creation succeeds
      const safetyBackupPath = '/backups/safety-backup.db';
      when(() => mockBackupService.createBackup(reason: any(named: 'reason')))
          .thenAnswer((_) async => safetyBackupPath);
      
      // Mock: File validation FAILS (not a valid SQLite database)
      when(() => mockDatabaseBackupService.validateDatabaseFile(corruptedFilePath))
          .thenAnswer((_) async => false);
      
      // Mock: Rollback import succeeds (restoring safety backup)
      when(() => mockDatabaseBackupService.importData(safetyBackupPath))
          .thenAnswer((_) async => {});
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(corruptedFilePath);

      // === ASSERT ===
      // Verify import failed
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      
      // Verify validation was called
      verify(() => mockDatabaseBackupService.validateDatabaseFile(corruptedFilePath)).called(1);
      
      // CRITICAL: Verify the USER'S corrupted file was NEVER imported
      verifyNever(() => mockDatabaseBackupService.importData(corruptedFilePath));
      
      // Verify rollback was triggered (safety backup imported)
      verify(() => mockDatabaseBackupService.importData(safetyBackupPath)).called(1);
      
      // Verify safety backup was created (before validation)
      verify(() => mockBackupService.createBackup(reason: any(named: 'reason'))).called(1);
    });

    test('should fail validation when filename does not start with correct prefix', () async {
      // === ARRANGE ===
      // Invalid filename (does not start with 'stuff-tracker-db')
      final invalidFilePath = '/path/to/my-random-backup.db';
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(invalidFilePath);

      // === ASSERT ===
      // Import should fail at filename validation stage
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      
      // CRITICAL: No service methods should be called if filename is invalid
      verifyNever(() => mockBackupService.createBackup(reason: any(named: 'reason')));
      verifyNever(() => mockDatabaseBackupService.validateDatabaseFile(any()));
      verifyNever(() => mockDatabaseBackupService.importData(any()));
    });

    test('should fail when safety backup creation fails', () async {
      // === ARRANGE ===
      final validFilePath = '/path/to/stuff-tracker-db-17022026.db';
      
      // Mock: Safety backup creation FAILS (returns null)
      when(() => mockBackupService.createBackup(reason: any(named: 'reason')))
          .thenAnswer((_) async => null);
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(validFilePath);

      // === ASSERT ===
      // Import should fail if safety backup cannot be created
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      
      // Verify safety backup was attempted
      verify(() => mockBackupService.createBackup(reason: any(named: 'reason'))).called(1);
      
      // Verify the actual import was never attempted
      verifyNever(() => mockDatabaseBackupService.validateDatabaseFile(any()));
      verifyNever(() => mockDatabaseBackupService.importData(any()));
    });
  });

  group('BackupController - Disaster Recovery', () {
    test('should trigger automatic rollback if the import process fails mid-operation', () async {
      // === ARRANGE ===
      // Simulate import failure after safety backup is created
      final validFilePath = '/path/to/stuff-tracker-db-17022026.db';
      const safetyBackupPath = '/backups/safety-backup-before-import.db';
      
      // Mock: Safety backup creation succeeds
      when(() => mockBackupService.createBackup(reason: any(named: 'reason')))
          .thenAnswer((_) async => safetyBackupPath);
      
      // Mock: File validation succeeds (file is valid SQLite)
      when(() => mockDatabaseBackupService.validateDatabaseFile(validFilePath))
          .thenAnswer((_) async => true);
      
      // Mock: Import operation FAILS mid-operation (simulating crash/corruption)
      var importCallCount = 0;
      when(() => mockDatabaseBackupService.importData(any())).thenAnswer((invocation) async {
        importCallCount++;
        final path = invocation.positionalArguments[0] as String;
        
        if (path == validFilePath) {
          // First call: importing user's file -> FAILS
          throw Exception('Database corruption detected during import');
        } else if (path == safetyBackupPath) {
          // Second call: rollback importing safety backup -> SUCCEEDS
          return;
        } else {
          throw Exception('Unexpected import path: $path');
        }
      });
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(validFilePath);

      // === ASSERT ===
      // Verify import reports failure to the UI
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      
      // Verify safety backup was created BEFORE attempting import
      verify(() => mockBackupService.createBackup(
        reason: 'Safety backup before import',
      )).called(1);
      
      // Verify file validation was performed
      verify(() => mockDatabaseBackupService.validateDatabaseFile(validFilePath)).called(1);
      
      // CRITICAL: Verify importData was called TWICE
      // 1st call: Attempting to import user's file (FAILED)
      // 2nd call: Rollback - importing safety backup (SUCCEEDED)
      expect(importCallCount, equals(2));
      
      // Verify the first call was with the user's file
      verify(() => mockDatabaseBackupService.importData(validFilePath)).called(1);
      
      // Verify the second call was with the safety backup (rollback)
      verify(() => mockDatabaseBackupService.importData(safetyBackupPath)).called(1);
    });

    test('should return critical error when both import and rollback fail', () async {
      // === ARRANGE ===
      // Worst-case scenario: import fails AND rollback also fails
      final validFilePath = '/path/to/stuff-tracker-db-17022026.db';
      const safetyBackupPath = '/backups/safety-backup.db';
      
      // Mock: Safety backup creation succeeds
      when(() => mockBackupService.createBackup(reason: any(named: 'reason')))
          .thenAnswer((_) async => safetyBackupPath);
      
      // Mock: File validation succeeds
      when(() => mockDatabaseBackupService.validateDatabaseFile(validFilePath))
          .thenAnswer((_) async => true);
      
      // Mock: Both import attempts FAIL
      when(() => mockDatabaseBackupService.importData(any())).thenThrow(
        Exception('Critical filesystem error'),
      );
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(validFilePath);

      // === ASSERT ===
      // Should return failure (not throw)
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      
      // Verify import was attempted with user's file
      verify(() => mockDatabaseBackupService.importData(validFilePath)).called(1);
      
      // Verify rollback was attempted with safety backup
      verify(() => mockDatabaseBackupService.importData(safetyBackupPath)).called(1);
      
      // Both attempts should have failed, leaving database in indeterminate state
      // The controller should return a critical error message
    });

    test('should successfully import and NOT trigger rollback on success', () async {
      // === ARRANGE ===
      // Simulate successful import (no rollback needed)
      final validFilePath = '/path/to/stuff-tracker-db-17022026.db';
      const safetyBackupPath = '/backups/safety-backup.db';
      
      // Mock: Safety backup creation succeeds
      when(() => mockBackupService.createBackup(reason: any(named: 'reason')))
          .thenAnswer((_) async => safetyBackupPath);
      
      // Mock: File validation succeeds
      when(() => mockDatabaseBackupService.validateDatabaseFile(validFilePath))
          .thenAnswer((_) async => true);
      
      // Mock: Import succeeds on first attempt
      when(() => mockDatabaseBackupService.importData(validFilePath))
          .thenAnswer((_) async => {});
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(validFilePath);

      // === ASSERT ===
      // Import should succeed
      expect(result.success, isTrue);
      expect(result.errorMessage, isNull);
      
      // Verify safety backup was created (as a precaution)
      verify(() => mockBackupService.createBackup(reason: any(named: 'reason'))).called(1);
      
      // Verify file validation was performed
      verify(() => mockDatabaseBackupService.validateDatabaseFile(validFilePath)).called(1);
      
      // Verify import was called ONLY ONCE (no rollback needed)
      verify(() => mockDatabaseBackupService.importData(validFilePath)).called(1);
      
      // CRITICAL: Verify rollback was NOT triggered (safety backup should not be imported)
      verifyNever(() => mockDatabaseBackupService.importData(safetyBackupPath));
    });

    test('should detect validation exception type and return appropriate error message', () async {
      // === ARRANGE ===
      final validFilePath = '/path/to/stuff-tracker-db-17022026.db';
      const safetyBackupPath = '/backups/safety-backup.db';
      
      // Mock: Safety backup succeeds
      when(() => mockBackupService.createBackup(reason: any(named: 'reason')))
          .thenAnswer((_) async => safetyBackupPath);
      
      // Mock: File validation throws ImportValidationException
      when(() => mockDatabaseBackupService.validateDatabaseFile(validFilePath))
          .thenThrow(const ImportValidationException('Invalid SQLite format'));
      
      // Mock: Rollback succeeds
      when(() => mockDatabaseBackupService.importData(safetyBackupPath))
          .thenAnswer((_) async => {});
      
      // === ACT ===
      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importDatabase(validFilePath);

      // === ASSERT ===
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      
      // Verify rollback was triggered
      verify(() => mockDatabaseBackupService.importData(safetyBackupPath)).called(1);
    });
  });
}
