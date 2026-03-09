import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database.dart';

/// Configurazione per il retry delle operazioni.
class RetryConfig {
  /// Numero massimo di tentativi
  final int maxAttempts;
  
  /// Delay iniziale tra i tentativi (in millisecondi)
  final int initialDelayMs;
  
  /// Fattore di moltiplicazione del delay per ogni retry (exponential backoff)
  final double backoffMultiplier;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelayMs = 100,
    this.backoffMultiplier = 2.0,
  });
  
  /// Configurazione di default
  static const defaultConfig = RetryConfig();
  
  /// Configurazione per operazioni critiche (più tentativi)
  static const criticalConfig = RetryConfig(
    maxAttempts: 5,
    initialDelayMs: 200,
    backoffMultiplier: 2.0,
  );
}

/// Risultato di un'operazione database.
class DatabaseResult<T> {
  final T? data;
  final bool success;
  final String? error;
  final int attempts;

  DatabaseResult._({
    this.data,
    required this.success,
    this.error,
    required this.attempts,
  });

  factory DatabaseResult.success(T data, {int attempts = 1}) {
    return DatabaseResult._(
      data: data,
      success: true,
      attempts: attempts,
    );
  }

  factory DatabaseResult.failure(String error, {int attempts = 1}) {
    return DatabaseResult._(
      success: false,
      error: error,
      attempts: attempts,
    );
  }
}

/// Servizio per operazioni database robuste con retry automatico.
/// 
/// Fornisce:
/// - Retry automatico con exponential backoff
/// - Transazioni atomiche
/// - Logging delle operazioni
/// - Error handling centralizzato
class DatabaseService {
  final AppDatabase _database;
  
  DatabaseService(this._database);

  /// Esegue un'operazione con retry automatico.
  /// 
  /// Se l'operazione fallisce, viene ritentata secondo la configurazione.
  /// Usa exponential backoff per evitare di sovraccaricare il sistema.
  Future<DatabaseResult<T>> executeWithRetry<T>(
    Future<T> Function() operation, {
    String? operationName,
    RetryConfig config = RetryConfig.defaultConfig,
  }) async {
    int attempts = 0;
    int delayMs = config.initialDelayMs;
    Object? lastError;

    while (attempts < config.maxAttempts) {
      attempts++;
      
      try {
        final result = await operation();
        
        if (attempts > 1) {
          debugPrint(
            '[DatabaseService] ${operationName ?? 'Operazione'} '
            'completata dopo $attempts tentativi',
          );
        }
        
        return DatabaseResult.success(result, attempts: attempts);
      } catch (e) {
        lastError = e;
        
        debugPrint(
          '[DatabaseService] ${operationName ?? 'Operazione'} '
          'fallita (tentativo $attempts/${config.maxAttempts}): $e',
        );

        if (attempts < config.maxAttempts) {
          // Aspetta prima del prossimo tentativo (exponential backoff)
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs = (delayMs * config.backoffMultiplier).toInt();
        }
      }
    }

    debugPrint(
      '[DatabaseService] ${operationName ?? 'Operazione'} '
      'fallita definitivamente dopo $attempts tentativi',
    );
    
    return DatabaseResult.failure(
      lastError?.toString() ?? 'Errore sconosciuto',
      attempts: attempts,
    );
  }

  /// Esegue un'operazione in una transazione atomica.
  /// 
  /// Se qualsiasi parte dell'operazione fallisce, tutte le modifiche
  /// vengono annullate (rollback).
  Future<DatabaseResult<T>> executeInTransaction<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    try {
      final result = await _database.transaction(() async {
        return await operation();
      });
      
      return DatabaseResult.success(result);
    } catch (e) {
      debugPrint(
        '[DatabaseService] Transazione ${operationName ?? ''} fallita: $e',
      );
      return DatabaseResult.failure(e.toString());
    }
  }

  /// Esegue un'operazione in transazione con retry automatico.
  /// 
  /// Combina i vantaggi di entrambi: atomicità e resilienza.
  Future<DatabaseResult<T>> executeAtomicWithRetry<T>(
    Future<T> Function() operation, {
    String? operationName,
    RetryConfig config = RetryConfig.defaultConfig,
  }) async {
    return executeWithRetry(
      () => _database.transaction(() => operation()),
      operationName: operationName,
      config: config,
    );
  }

  /// Esegue un batch di operazioni in una singola transazione.
  /// 
  /// Utile per inserimenti multipli o operazioni correlate.
  Future<DatabaseResult<void>> executeBatch(
    Future<void> Function() operations, {
    String? operationName,
  }) async {
    return executeAtomicWithRetry(
      operations,
      operationName: operationName ?? 'Batch operation',
      config: RetryConfig.criticalConfig,
    );
  }

  /// Verifica che il database sia accessibile e funzionante.
  Future<bool> healthCheck() async {
    try {
      // Esegue una query semplice per verificare la connessione
      await _database.customSelect('SELECT 1').get();
      return true;
    } catch (e) {
      debugPrint('[DatabaseService] Health check fallito: $e');
      return false;
    }
  }

  /// Ottiene statistiche sul database.
  Future<Map<String, int>> getStats() async {
    try {
      final houses = await _database.customSelect(
        'SELECT COUNT(*) as count FROM houses',
      ).getSingle();
      
      final items = await _database.customSelect(
        'SELECT COUNT(*) as count FROM items',
      ).getSingle();
      
      final trips = await _database.customSelect(
        'SELECT COUNT(*) as count FROM trips',
      ).getSingle();
      
      final tripItems = await _database.customSelect(
        'SELECT COUNT(*) as count FROM trip_item_entries',
      ).getSingle();

      return {
        'houses': houses.read<int>('count'),
        'items': items.read<int>('count'),
        'trips': trips.read<int>('count'),
        'tripItems': tripItems.read<int>('count'),
      };
    } catch (e) {
      debugPrint('[DatabaseService] Errore ottenendo statistiche: $e');
      return {};
    }
  }
}
