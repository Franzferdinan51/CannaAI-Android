import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';

import 'database.dart';
import 'repositories.dart';

// Database configuration
class DatabaseConfig {
  final String databaseName;
  final bool enableForeignKeys;
  final bool enableWALMode;
  final int cacheSize;
  final Duration busyTimeout;
  final bool enableQueryLogging;
  final Duration backupInterval;
  final int maxBackupFiles;
  final Duration dataRetentionPeriod;

  const DatabaseConfig({
    this.databaseName = 'cannai.db',
    this.enableForeignKeys = true,
    this.enableWALMode = true,
    this.cacheSize = 10000,
    this.busyTimeout = const Duration(seconds: 30),
    this.enableQueryLogging = false,
    this.backupInterval = const Duration(hours: 24),
    this.maxBackupFiles = 5,
    this.dataRetentionPeriod = const Duration(days: 365),
  });
}

// Database statistics
class DatabaseStats {
  final Map<String, int> recordCounts;
  final int totalSize;
  final DateTime lastOptimized;
  final int totalQueries;
  final Duration averageQueryTime;

  const DatabaseStats({
    required this.recordCounts,
    required this.totalSize,
    required this.lastOptimized,
    required this.totalQueries,
    required this.averageQueryTime,
  });
}

// Backup information
class BackupInfo {
  final String fileName;
  final String filePath;
  final int fileSize;
  final DateTime backupDate;
  final int recordCount;
  final String checksum;
  final String version;

  const BackupInfo({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.backupDate,
    required this.recordCount,
    required this.checksum,
    required this.version,
  });
}

// Database service
class DatabaseService {
  static DatabaseService? _instance;
  static const String _versionKey = 'database_version';
  static const String _initializedKey = 'database_initialized';
  static const String _lastBackupKey = 'last_backup_date';
  static const String _lastOptimizationKey = 'last_optimization_date';

  late final CannaAIDatabase _database;
  late final RepositoryFactory _repositories;
  late final Logger _logger;
  late final SharedPreferences _prefs;
  late final DatabaseConfig _config;

  // Performance monitoring
  final Map<String, List<Duration>> _queryMetrics = {};
  int _totalQueries = 0;
  Timer? _backupTimer;
  Timer? _optimizationTimer;

  // Getters
  CannaAIDatabase get database => _database;
  RepositoryFactory get repositories => _repositories;
  DatabaseConfig get config => _config;
  bool get isInitialized => _prefs.getBool(_initializedKey) ?? false;

  // Private constructor for singleton
  DatabaseService._internal();

  // Initialize singleton instance
  static Future<DatabaseService> getInstance({
    DatabaseConfig? config,
    Logger? logger,
  }) async {
    if (_instance == null) {
      _instance = DatabaseService._internal();
      await _instance!._initialize(config, logger);
    }
    return _instance!;
  }

  // Initialize database service
  Future<void> _initialize(DatabaseConfig? config, Logger? logger) async {
    try {
      _config = config ?? const DatabaseConfig();
      _logger = logger ?? Logger();
      _prefs = await SharedPreferences.getInstance();

      _logger.i('Initializing CannaAI Database Service v${_getDatabaseVersion()}');

      // Initialize database
      _database = CannaAIDatabase();
      await _database.customStatement('PRAGMA foreign_keys = ${_config.enableForeignKeys ? 'ON' : 'OFF'}');

      // Initialize repositories
      _repositories = RepositoryFactory(_database, _logger, _prefs);

      // Check if database needs migration
      await _checkAndRunMigrations();

      // Set up performance monitoring
      if (_config.enableQueryLogging) {
        _setupPerformanceMonitoring();
      }

      // Set up automated backups
      _setupAutomatedBackups();

      // Set up periodic optimization
      _setupPeriodicOptimization();

      // Mark as initialized
      await _prefs.setBool(_initializedKey, true);

      _logger.i('Database service initialized successfully');
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize database service', error: e, stackTrace: stackTrace);
      throw DatabaseServiceException('Database initialization failed', originalError: e);
    }
  }

  // Migration management
  Future<void> _checkAndRunMigrations() async {
    try {
      final currentVersion = _getDatabaseVersion();
      final storedVersion = _prefs.getInt(_versionKey) ?? 0;

      _logger.i('Database version: $currentVersion, Stored version: $storedVersion');

      if (currentVersion > storedVersion) {
        _logger.i('Running database migrations from v$storedVersion to v$currentVersion');

        // Here you would implement specific migration logic
        // For now, Drift handles schema migrations automatically

        await _prefs.setInt(_versionKey, currentVersion);
        _logger.i('Database migrations completed successfully');
      }
    } catch (e) {
      _logger.e('Migration failed', error: e);
      throw DatabaseServiceException('Database migration failed', originalError: e);
    }
  }

  // Performance monitoring
  void _setupPerformanceMonitoring() {
    _database.addMonitoringListener((event) {
      if (event is QueryEvent) {
        _recordQueryMetric(event.sql, event.duration);
      }
    });
  }

  void _recordQueryMetric(String sql, Duration duration) {
    final queryType = _getQueryType(sql);
    _queryMetrics.putIfAbsent(queryType, () => <Duration>[]);
    _queryMetrics[queryType]!.add(duration);
    _totalQueries++;

    // Keep only last 1000 metrics per query type
    if (_queryMetrics[queryType]!.length > 1000) {
      _queryMetrics[queryType]!.removeRange(0, _queryMetrics[queryType]!.length - 1000);
    }
  }

  String _getQueryType(String sql) {
    final normalizedSql = sql.trim().toUpperCase();
    if (normalizedSql.startsWith('SELECT')) return 'SELECT';
    if (normalizedSql.startsWith('INSERT')) return 'INSERT';
    if (normalizedSql.startsWith('UPDATE')) return 'UPDATE';
    if (normalizedSql.startsWith('DELETE')) return 'DELETE';
    return 'OTHER';
  }

  // Automated backups
  void _setupAutomatedBackups() {
    _backupTimer = Timer.periodic(_config.backupInterval, (timer) async {
      try {
        await createBackup('auto');
        _logger.i('Automated backup completed');
      } catch (e) {
        _logger.e('Automated backup failed', error: e);
      }
    });
  }

  // Periodic optimization
  void _setupPeriodicOptimization() {
    // Run optimization weekly
    _optimizationTimer = Timer.periodic(const Duration(days: 7), (timer) async {
      try {
        await optimizeDatabase();
        _logger.i('Periodic database optimization completed');
      } catch (e) {
        _logger.e('Periodic optimization failed', error: e);
      }
    });
  }

  // Backup management
  Future<BackupInfo> createBackup(String backupType) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'cannai_backup_${backupType}_$timestamp.db';
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(directory.path, 'backups'));

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final backupPath = p.join(backupDir.path, fileName);

      // Get statistics before backup
      final stats = await getDatabaseStats();
      final recordCount = stats.recordCounts.values.fold(0, (a, b) => a + b);

      // Create backup
      await _database.backup(backupPath);

      // Calculate checksum
      final checksum = await _calculateFileChecksum(backupPath);

      // Get file size
      final file = File(backupPath);
      final fileSize = await file.length();

      final backupInfo = BackupInfo(
        fileName: fileName,
        filePath: backupPath,
        fileSize: fileSize,
        backupDate: DateTime.now(),
        recordCount: recordCount,
        checksum: checksum,
        version: _getDatabaseVersion().toString(),
      );

      // Log backup
      await _logBackup(backupInfo);

      // Clean old backups
      await _cleanupOldBackups();

      // Update last backup timestamp
      await _prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());

      _logger.i('Backup created: $fileName (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
      return backupInfo;
    } catch (e) {
      _logger.e('Backup creation failed', error: e);
      throw DatabaseServiceException('Backup creation failed', originalError: e);
    }
  }

  Future<String> _calculateFileChecksum(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _logBackup(BackupInfo backupInfo) async {
    final backupLog = BackupLogsCompanion.insert(
      backupType: 'manual',
      filePath: backupInfo.filePath,
      fileSize: backupInfo.fileSize,
      recordCount: backupInfo.recordCount,
      status: 'success',
      checksum: Value(backupInfo.checksum),
      version: backupInfo.version,
      userId: 1, // This should be managed properly
    );
    await _database.into(_database.backupLogs).insert(backupLog);
  }

  Future<void> _cleanupOldBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(directory.path, 'backups'));

      if (!await backupDir.exists()) return;

      final files = await backupDir.list().where((entity) => entity is File).cast<File>().toList();

      // Sort by modification time (newest first)
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      // Keep only the most recent backups
      if (files.length > _config.maxBackupFiles) {
        final filesToDelete = files.skip(_config.maxBackupFiles);
        for (final file in filesToDelete) {
          await file.delete();
          _logger.d('Deleted old backup: ${file.path}');
        }
      }
    } catch (e) {
      _logger.w('Failed to cleanup old backups: $e');
    }
  }

  // Restore from backup
  Future<void> restoreFromBackup(String backupPath) async {
    try {
      _logger.i('Starting database restore from: $backupPath');

      // Verify backup file exists
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw DatabaseServiceException('Backup file not found: $backupPath');
      }

      // Create current database backup before restore
      await createBackup('pre_restore');

      // Get current database path
      final currentPath = await _database.getDatabasePath();

      // Close current database
      await _database.close();

      // Replace current database with backup
      await backupFile.copy(currentPath);

      // Reopen database
      _database = CannaAIDatabase();

      _logger.i('Database restore completed successfully');
    } catch (e) {
      _logger.e('Database restore failed', error: e);
      throw DatabaseServiceException('Database restore failed', originalError: e);
    }
  }

  // Database optimization
  Future<void> optimizeDatabase() async {
    try {
      _logger.i('Starting database optimization');

      final stopwatch = Stopwatch()..start();

      // Run VACUUM to rebuild the database file
      await _database.customStatement('VACUUM');

      // Run ANALYZE to update statistics
      await _database.customStatement('ANALYZE');

      // Rebuild indexes
      await _database.customStatement('REINDEX');

      // Clear old data based on retention policy
      await _cleanupOldData();

      stopwatch.stop();

      // Update last optimization timestamp
      await _prefs.setString(_lastOptimizationKey, DateTime.now().toIso8601String());

      _logger.i('Database optimization completed in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      _logger.e('Database optimization failed', error: e);
      throw DatabaseServiceException('Database optimization failed', originalError: e);
    }
  }

  Future<void> _cleanupOldData() async {
    try {
      final cutoffDate = DateTime.now().subtract(_config.dataRetentionPeriod);

      // Clean old sensor readings
      await _database.sensorReadingDao.deleteOldReadings(cutoffDate, 1);

      // Clean old automation logs
      await _database.automationLogDao.deleteOldLogs(cutoffDate, 1);

      // Clean old backup logs
      await _database.backupLogDao.deleteOldBackups(cutoffDate, 1);

      _logger.d('Cleaned up data older than ${cutoffDate.toIso8601String()}');
    } catch (e) {
      _logger.w('Failed to cleanup old data: $e');
    }
  }

  // Database statistics
  Future<DatabaseStats> getDatabaseStats() async {
    try {
      final recordCounts = await _database.getDatabaseStats();
      final totalSize = await _database.getDatabaseSize();
      final lastOptimizedString = _prefs.getString(_lastOptimizationKey);
      final lastOptimized = lastOptimizedString != null
          ? DateTime.parse(lastOptimizedString)
          : DateTime.fromMillisecondsSinceEpoch(0);

      // Calculate average query time
      Duration totalQueryTime = Duration.zero;
      int totalMetrics = 0;
      for (final metrics in _queryMetrics.values) {
        for (final duration in metrics) {
          totalQueryTime += duration;
          totalMetrics++;
        }
      }
      final averageQueryTime = totalMetrics > 0
          ? Duration(microseconds: totalQueryTime.inMicroseconds ~/ totalMetrics)
          : Duration.zero;

      return DatabaseStats(
        recordCounts: recordCounts,
        totalSize: totalSize,
        lastOptimized: lastOptimized,
        totalQueries: _totalQueries,
        averageQueryTime: averageQueryTime,
      );
    } catch (e) {
      _logger.e('Failed to get database stats', error: e);
      throw DatabaseServiceException('Failed to get database stats', originalError: e);
    }
  }

  // Get query performance metrics
  Map<String, Map<String, dynamic>> getQueryMetrics() {
    final metrics = <String, Map<String, dynamic>>{};

    for (final entry in _queryMetrics.entries) {
      final durations = entry.value;
      if (durations.isEmpty) continue;

      durations.sort((a, b) => a.compareTo(b));

      final totalTime = durations.fold(Duration.zero, (sum, d) => sum + d);
      final averageTime = Duration(microseconds: totalTime.inMicroseconds ~/ durations.length);

      metrics[entry.key] = {
        'count': durations.length,
        'average': averageTime.inMilliseconds,
        'min': durations.first.inMilliseconds,
        'max': durations.last.inMilliseconds,
        'total': totalTime.inMilliseconds,
      };
    }

    return metrics;
  }

  // Database health check
  Future<Map<String, dynamic>> performHealthCheck() async {
    try {
      final results = <String, dynamic>{};

      // Check database connectivity
      try {
        await _database.customSelect('SELECT 1').getSingle();
        results['connectivity'] = 'OK';
      } catch (e) {
        results['connectivity'] = 'FAILED: $e';
      }

      // Check foreign key constraints
      try {
        final fkResult = await _database.customSelect('PRAGMA foreign_key_check').get();
        results['foreign_keys'] = fkResult.isEmpty ? 'OK' : 'VIOLATIONS: ${fkResult.length}';
      } catch (e) {
        results['foreign_keys'] = 'ERROR: $e';
      }

      // Check database integrity
      try {
        final integrityResult = await _database.customSelect('PRAGMA integrity_check').getSingle();
        results['integrity'] = integrityResult.data['integrity_check'].toString() == 'ok' ? 'OK' : 'FAILED';
      } catch (e) {
        results['integrity'] = 'ERROR: $e';
      }

      // Get database stats
      final stats = await getDatabaseStats();
      results['stats'] = {
        'total_size_mb': (stats.totalSize / 1024 / 1024).toStringAsFixed(2),
        'total_records': stats.recordCounts.values.fold(0, (a, b) => a + b),
        'last_optimized': stats.lastOptimized.toIso8601String(),
        'total_queries': stats.totalQueries,
        'avg_query_time_ms': stats.averageQueryTime.inMilliseconds,
      };

      // Check last backup
      final lastBackupString = _prefs.getString(_lastBackupKey);
      final lastBackup = lastBackupString != null ? DateTime.parse(lastBackupString) : null;
      final now = DateTime.now();
      final daysSinceBackup = lastBackup != null ? now.difference(lastBackup).inDays : null;

      results['backup_status'] = {
        'last_backup': lastBackup?.toIso8601String(),
        'days_since_backup': daysSinceBackup,
        'status': daysSinceBackup != null && daysSinceBackup <= 7 ? 'OK' : 'WARNING',
      };

      // Performance metrics
      results['performance'] = getQueryMetrics();

      return results;
    } catch (e) {
      _logger.e('Health check failed', error: e);
      throw DatabaseServiceException('Health check failed', originalError: e);
    }
  }

  // Clear all caches
  Future<void> clearAllCaches(int userId) async {
    try {
      await _repositories.clearAllCaches(userId);
      _logger.d('Cleared all caches for user $userId');
    } catch (e) {
      _logger.e('Failed to clear caches', error: e);
      throw DatabaseServiceException('Failed to clear caches', originalError: e);
    }
  }

  // Reset database
  Future<void> resetDatabase() async {
    try {
      _logger.w('Resetting database - this will delete all data');

      // Create backup before reset
      await createBackup('pre_reset');

      // Clear all data
      await _database.clearAllData();

      // Clear caches
      await _prefs.clear();

      // Reset initialization flag
      await _prefs.setBool(_initializedKey, false);

      _logger.w('Database reset completed');
    } catch (e) {
      _logger.e('Database reset failed', error: e);
      throw DatabaseServiceException('Database reset failed', originalError: e);
    }
  }

  // Close database service
  Future<void> close() async {
    try {
      _backupTimer?.cancel();
      _optimizationTimer?.cancel();
      await _database.close();
      _logger.i('Database service closed');
    } catch (e) {
      _logger.e('Failed to close database service', error: e);
    }
  }

  // Get database version
  int _getDatabaseVersion() {
    // This should match the schemaVersion in the database class
    return 1;
  }

  // Export data for analysis
  Future<Map<String, dynamic>> exportData({int? userId}) async {
    try {
      final exportData = <String, dynamic>{};
      final exportTime = DateTime.now().toIso8601String();

      exportData['metadata'] = {
        'exported_at': exportTime,
        'version': _getDatabaseVersion(),
        'user_id': userId,
      };

      // Export each table
      exportData['users'] = await _exportTable('users', userId);
      exportData['rooms'] = await _exportTable('rooms', userId);
      exportData['strains'] = await _exportTable('strains', userId);
      exportData['plants'] = await _exportTable('plants', userId);
      exportData['sensor_devices'] = await _exportTable('sensor_devices', userId);
      exportData['sensor_readings'] = await _exportTable('sensor_readings', userId);
      exportData['automation_rules'] = await _exportTable('automation_rules', userId);
      exportData['plant_analysis'] = await _exportTable('plant_analysis', userId);
      exportData['automation_logs'] = await _exportTable('automation_logs', userId);
      exportData['plant_notes'] = await _exportTable('plant_notes', userId);
      exportData['app_settings'] = await _exportTable('app_settings', userId);

      return exportData;
    } catch (e) {
      _logger.e('Data export failed', error: e);
      throw DatabaseServiceException('Data export failed', originalError: e);
    }
  }

  Future<List<Map<String, dynamic>>> _exportTable(String tableName, int? userId) async {
    try {
      String query = 'SELECT * FROM $tableName';
      if (userId != null) {
        query += ' WHERE user_id = $userId';
      }

      final results = await _database.customSelect(query).get();
      return results.map((row) => row.data).toList();
    } catch (e) {
      _logger.w('Failed to export table $tableName: $e');
      return [];
    }
  }

  // Import data from export
  Future<void> importData(Map<String, dynamic> exportData, {int? userId}) async {
    try {
      final metadata = exportData['metadata'] as Map<String, dynamic>?;
      if (metadata == null) {
        throw DatabaseServiceException('Invalid export data: missing metadata');
      }

      _logger.i('Importing data exported at ${metadata['exported_at']}');

      // Import each table
      await _importTable('users', exportData['users'] as List?, userId);
      await _importTable('rooms', exportData['rooms'] as List?, userId);
      await _importTable('strains', exportData['strains'] as List?, userId);
      await _importTable('plants', exportData['plants'] as List?, userId);
      await _importTable('sensor_devices', exportData['sensor_devices'] as List?, userId);
      await _importTable('sensor_readings', exportData['sensor_readings'] as List?, userId);
      await _importTable('automation_rules', exportData['automation_rules'] as List?, userId);
      await _importTable('plant_analysis', exportData['plant_analysis'] as List?, userId);
      await _importTable('automation_logs', exportData['automation_logs'] as List?, userId);
      await _importTable('plant_notes', exportData['plant_notes'] as List?, userId);
      await _importTable('app_settings', exportData['app_settings'] as List?, userId);

      _logger.i('Data import completed successfully');
    } catch (e) {
      _logger.e('Data import failed', error: e);
      throw DatabaseServiceException('Data import failed', originalError: e);
    }
  }

  Future<void> _importTable(String tableName, List? data, int? userId) async {
    if (data == null || data.isEmpty) return;

    try {
      await _database.transaction(() async {
        for (final record in data) {
          if (record is Map<String, dynamic>) {
            final recordMap = Map<String, dynamic>.from(record);

            // Override user_id if provided
            if (userId != null) {
              recordMap['user_id'] = userId;
            }

            // Remove auto-increment primary key if present
            recordMap.remove('id');

            // Build INSERT query
            final columns = recordMap.keys.join(', ');
            final values = recordMap.values.map((v) => '\'$v\'').join(', ');

            await _database.customSelect(
              'INSERT OR REPLACE INTO $tableName ($columns) VALUES ($values)'
            ).getSingle();
          }
        }
      });

      _logger.d('Imported ${data.length} records into $tableName');
    } catch (e) {
      _logger.e('Failed to import table $tableName: $e');
      throw DatabaseServiceException('Failed to import table $tableName', originalError: e);
    }
  }
}

// Database service exception
class DatabaseServiceException implements Exception {
  final String message;
  final dynamic originalError;

  DatabaseServiceException(this.message, {this.originalError});

  @override
  String toString() {
    final buffer = StringBuffer('DatabaseServiceException: $message');
    if (originalError != null) buffer.write(' (original error: $originalError)');
    return buffer.toString();
  }
}