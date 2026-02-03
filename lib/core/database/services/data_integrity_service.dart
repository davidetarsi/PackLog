import 'package:flutter/foundation.dart';
import '../database.dart';

/// Tipo di problema di integrità.
enum IntegrityIssueType {
  /// Item senza casa associata
  orphanItem,
  /// Trip item senza viaggio associato
  orphanTripItem,
  /// Viaggio con casa di destinazione non esistente
  invalidDestinationHouse,
  /// Dati mancanti o corrotti
  corruptedData,
  /// Foreign key non valida
  invalidForeignKey,
}

/// Rappresenta un problema di integrità dei dati.
class IntegrityIssue {
  final IntegrityIssueType type;
  final String table;
  final String recordId;
  final String description;
  final bool canAutoFix;

  IntegrityIssue({
    required this.type,
    required this.table,
    required this.recordId,
    required this.description,
    this.canAutoFix = false,
  });

  @override
  String toString() => '[$type] $table($recordId): $description';
}

/// Risultato della verifica di integrità.
class IntegrityCheckResult {
  final List<IntegrityIssue> issues;
  final DateTime checkedAt;
  final Duration duration;

  IntegrityCheckResult({
    required this.issues,
    required this.checkedAt,
    required this.duration,
  });

  bool get isHealthy => issues.isEmpty;
  int get issueCount => issues.length;
  int get fixableIssueCount => issues.where((i) => i.canAutoFix).length;
}

/// Servizio per verificare e riparare l'integrità dei dati.
/// 
/// Fornisce:
/// - Verifica delle foreign key
/// - Rilevamento di dati orfani
/// - Riparazione automatica quando possibile
/// - Report dettagliato dei problemi
class DataIntegrityService {
  final AppDatabase _database;

  DataIntegrityService(this._database);

  /// Esegue una verifica completa dell'integrità dei dati.
  Future<IntegrityCheckResult> runFullCheck() async {
    final startTime = DateTime.now();
    final issues = <IntegrityIssue>[];

    debugPrint('[DataIntegrity] Avvio verifica integrità...');

    // 1. Verifica items orfani (senza casa)
    issues.addAll(await _checkOrphanItems());

    // 2. Verifica trip_items orfani (senza viaggio)
    issues.addAll(await _checkOrphanTripItems());

    // 3. Verifica viaggi con casa di destinazione non valida
    issues.addAll(await _checkInvalidDestinationHouses());

    // 4. Verifica consistenza dati base
    issues.addAll(await _checkDataConsistency());

    final duration = DateTime.now().difference(startTime);
    
    debugPrint(
      '[DataIntegrity] Verifica completata in ${duration.inMilliseconds}ms. '
      'Problemi trovati: ${issues.length}',
    );

    return IntegrityCheckResult(
      issues: issues,
      checkedAt: DateTime.now(),
      duration: duration,
    );
  }

  /// Verifica items senza casa associata.
  Future<List<IntegrityIssue>> _checkOrphanItems() async {
    final issues = <IntegrityIssue>[];
    
    try {
      final orphans = await _database.customSelect('''
        SELECT i.id, i.name, i.house_id 
        FROM items i 
        LEFT JOIN houses h ON i.house_id = h.id 
        WHERE h.id IS NULL
      ''').get();

      for (final row in orphans) {
        issues.add(IntegrityIssue(
          type: IntegrityIssueType.orphanItem,
          table: 'items',
          recordId: row.read<String>('id'),
          description: 'Item "${row.read<String>('name')}" ha house_id '
              '"${row.read<String>('house_id')}" che non esiste',
          canAutoFix: true, // Possiamo eliminare l'item orfano
        ));
      }
    } catch (e) {
      debugPrint('[DataIntegrity] Errore controllando items orfani: $e');
    }

    return issues;
  }

  /// Verifica trip_items senza viaggio associato.
  Future<List<IntegrityIssue>> _checkOrphanTripItems() async {
    final issues = <IntegrityIssue>[];
    
    try {
      final orphans = await _database.customSelect('''
        SELECT ti.id, ti.name, ti.trip_id 
        FROM trip_item_entries ti 
        LEFT JOIN trips t ON ti.trip_id = t.id 
        WHERE t.id IS NULL
      ''').get();

      for (final row in orphans) {
        issues.add(IntegrityIssue(
          type: IntegrityIssueType.orphanTripItem,
          table: 'trip_item_entries',
          recordId: row.read<String>('id'),
          description: 'Trip item "${row.read<String>('name')}" ha trip_id '
              '"${row.read<String>('trip_id')}" che non esiste',
          canAutoFix: true, // Possiamo eliminare il trip_item orfano
        ));
      }
    } catch (e) {
      debugPrint('[DataIntegrity] Errore controllando trip_items orfani: $e');
    }

    return issues;
  }

  /// Verifica viaggi con casa di destinazione non valida.
  Future<List<IntegrityIssue>> _checkInvalidDestinationHouses() async {
    final issues = <IntegrityIssue>[];
    
    try {
      final invalid = await _database.customSelect('''
        SELECT t.id, t.name, t.destination_house_id 
        FROM trips t 
        LEFT JOIN houses h ON t.destination_house_id = h.id 
        WHERE t.destination_house_id IS NOT NULL AND h.id IS NULL
      ''').get();

      for (final row in invalid) {
        issues.add(IntegrityIssue(
          type: IntegrityIssueType.invalidDestinationHouse,
          table: 'trips',
          recordId: row.read<String>('id'),
          description: 'Viaggio "${row.read<String>('name')}" ha destination_house_id '
              '"${row.read<String>('destination_house_id')}" che non esiste',
          canAutoFix: true, // Possiamo impostare a NULL
        ));
      }
    } catch (e) {
      debugPrint('[DataIntegrity] Errore controllando case destinazione: $e');
    }

    return issues;
  }

  /// Verifica consistenza generale dei dati.
  Future<List<IntegrityIssue>> _checkDataConsistency() async {
    final issues = <IntegrityIssue>[];
    
    try {
      // Verifica case con nome vuoto
      final emptyHouses = await _database.customSelect('''
        SELECT id FROM houses WHERE name IS NULL OR name = ''
      ''').get();

      for (final row in emptyHouses) {
        issues.add(IntegrityIssue(
          type: IntegrityIssueType.corruptedData,
          table: 'houses',
          recordId: row.read<String>('id'),
          description: 'Casa con nome vuoto o nullo',
          canAutoFix: false,
        ));
      }

      // Verifica items con nome vuoto
      final emptyItems = await _database.customSelect('''
        SELECT id FROM items WHERE name IS NULL OR name = ''
      ''').get();

      for (final row in emptyItems) {
        issues.add(IntegrityIssue(
          type: IntegrityIssueType.corruptedData,
          table: 'items',
          recordId: row.read<String>('id'),
          description: 'Item con nome vuoto o nullo',
          canAutoFix: false,
        ));
      }

      // Verifica viaggi con nome vuoto
      final emptyTrips = await _database.customSelect('''
        SELECT id FROM trips WHERE name IS NULL OR name = ''
      ''').get();

      for (final row in emptyTrips) {
        issues.add(IntegrityIssue(
          type: IntegrityIssueType.corruptedData,
          table: 'trips',
          recordId: row.read<String>('id'),
          description: 'Viaggio con nome vuoto o nullo',
          canAutoFix: false,
        ));
      }
    } catch (e) {
      debugPrint('[DataIntegrity] Errore controllando consistenza: $e');
    }

    return issues;
  }

  /// Ripara automaticamente i problemi che possono essere risolti.
  /// 
  /// Ritorna il numero di problemi riparati.
  Future<int> autoFix(IntegrityCheckResult checkResult) async {
    int fixed = 0;
    
    for (final issue in checkResult.issues.where((i) => i.canAutoFix)) {
      try {
        switch (issue.type) {
          case IntegrityIssueType.orphanItem:
            await _database.customStatement(
              'DELETE FROM items WHERE id = ?',
              [issue.recordId],
            );
            fixed++;
            debugPrint('[DataIntegrity] Eliminato item orfano: ${issue.recordId}');
            break;

          case IntegrityIssueType.orphanTripItem:
            await _database.customStatement(
              'DELETE FROM trip_item_entries WHERE id = ?',
              [issue.recordId],
            );
            fixed++;
            debugPrint('[DataIntegrity] Eliminato trip_item orfano: ${issue.recordId}');
            break;

          case IntegrityIssueType.invalidDestinationHouse:
            await _database.customStatement(
              'UPDATE trips SET destination_house_id = NULL WHERE id = ?',
              [issue.recordId],
            );
            fixed++;
            debugPrint('[DataIntegrity] Rimossa destinazione non valida: ${issue.recordId}');
            break;

          default:
            // Non auto-riparabile
            break;
        }
      } catch (e) {
        debugPrint('[DataIntegrity] Errore riparando ${issue.recordId}: $e');
      }
    }

    debugPrint('[DataIntegrity] Riparati $fixed problemi');
    return fixed;
  }

  /// Esegue una verifica rapida (solo conteggi).
  Future<bool> quickCheck() async {
    try {
      // Verifica che tutte le tabelle siano accessibili
      await _database.customSelect('SELECT COUNT(*) FROM houses').getSingle();
      await _database.customSelect('SELECT COUNT(*) FROM items').getSingle();
      await _database.customSelect('SELECT COUNT(*) FROM trips').getSingle();
      await _database.customSelect('SELECT COUNT(*) FROM trip_item_entries').getSingle();
      return true;
    } catch (e) {
      debugPrint('[DataIntegrity] Quick check fallito: $e');
      return false;
    }
  }
}
