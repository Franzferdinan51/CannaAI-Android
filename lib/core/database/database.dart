import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Rooms,
    Strains,
    Plants,
    SensorDevices,
    SensorReadings,
    AutomationRules,
    PlantAnalysis,
    AutomationLogs,
    PlantNotes,
    AppSettings,
    BackupLogs,
  ],
  daos: [
    UserDao,
    RoomDao,
    StrainDao,
    PlantDao,
    SensorDeviceDao,
    SensorReadingDao,
    AutomationRuleDao,
    PlantAnalysisDao,
    AutomationLogDao,
    PlantNoteDao,
    AppSettingDao,
    BackupLogDao,
  ],
)
class CannaAIDatabase extends _$CannaAIDatabase {
  CannaAIDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Create indexes for better performance
        await customStatement('CREATE INDEX idx_users_email ON users (email)');
        await customStatement('CREATE INDEX idx_users_username ON users (username)');
        await customStatement('CREATE INDEX idx_rooms_user_id ON rooms (user_id)');
        await customStatement('CREATE INDEX idx_strains_user_id ON strains (user_id)');
        await customStatement('CREATE INDEX idx_plants_user_id ON plants (user_id)');
        await customStatement('CREATE INDEX idx_plants_room_id ON plants (room_id)');
        await customStatement('CREATE INDEX idx_plants_strain_id ON plants (strain_id)');
        await customStatement('CREATE INDEX idx_plants_growth_stage ON plants (growth_stage)');
        await customStatement('CREATE INDEX idx_sensor_devices_user_id ON sensor_devices (user_id)');
        await customStatement('CREATE INDEX idx_sensor_devices_room_id ON sensor_devices (room_id)');
        await customStatement('CREATE INDEX idx_sensor_readings_device_id ON sensor_readings (device_id)');
        await customStatement('CREATE INDEX idx_sensor_readings_timestamp ON sensor_readings (timestamp)');
        await customStatement('CREATE INDEX idx_automation_rules_user_id ON automation_rules (user_id)');
        await customStatement('CREATE INDEX idx_automation_rules_room_id ON automation_rules (room_id)');
        await customStatement('CREATE INDEX idx_plant_analysis_plant_id ON plant_analysis (plant_id)');
        await customStatement('CREATE INDEX idx_plant_analysis_analysis_date ON plant_analysis (analysis_date)');
        await customStatement('CREATE INDEX idx_automation_logs_rule_id ON automation_logs (rule_id)');
        await customStatement('CREATE INDEX idx_automation_logs_execution_date ON automation_logs (execution_date)');
        await customStatement('CREATE INDEX idx_plant_notes_plant_id ON plant_notes (plant_id)');
        await customStatement('CREATE INDEX idx_plant_notes_note_date ON plant_notes (note_date)');
        await customStatement('CREATE INDEX idx_app_settings_user_id ON app_settings (user_id)');
        await customStatement('CREATE INDEX idx_backup_logs_user_id ON backup_logs (user_id)');

        // Create triggers for automatic timestamps
        await customStatement('''
          CREATE TRIGGER update_users_updated_at
          AFTER UPDATE ON users
          BEGIN
            UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
          END
        ''');

        await customStatement('''
          CREATE TRIGGER update_rooms_updated_at
          AFTER UPDATE ON rooms
          BEGIN
            UPDATE rooms SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
          END
        ''');

        await customStatement('''
          CREATE TRIGGER update_strains_updated_at
          AFTER UPDATE ON strains
          BEGIN
            UPDATE strains SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
          END
        ''');

        await customStatement('''
          CREATE TRIGGER update_plants_updated_at
          AFTER UPDATE ON plants
          BEGIN
            UPDATE plants SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
          END
        ''');

        await customStatement('''
          CREATE TRIGGER update_sensor_devices_updated_at
          AFTER UPDATE ON sensor_devices
          BEGIN
            UPDATE sensor_devices SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
          END
        ''');

        await customStatement('''
          CREATE TRIGGER update_automation_rules_updated_at
          AFTER UPDATE ON automation_rules
          BEGIN
            UPDATE automation_rules SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
          END
        ''');

        await customStatement('''
          CREATE TRIGGER update_app_settings_updated_at
          AFTER UPDATE ON app_settings
          BEGIN
            UPDATE app_settings SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
          END
        ''');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future migrations here
        if (from < 2) {
          // Example of adding new columns in future versions
          // await m.addColumn(table, column);
        }
      },
      beforeOpen: (OpeningDetails details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');

        // Set SQLite optimizations
        await customStatement('PRAGMA journal_mode = WAL');
        await customStatement('PRAGMA synchronous = NORMAL');
        await customStatement('PRAGMA cache_size = 10000');
        await customStatement('PRAGMA temp_store = MEMORY');

        // Set busy timeout for concurrent access
        await customStatement('PRAGMA busy_timeout = 30000');
      },
    );
  }

  // Database maintenance methods
  Future<void> optimize() async {
    await customStatement('VACUUM');
    await customStatement('ANALYZE');
  }

  Future<void> clearAllData() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }

  Future<Map<String, dynamic>> getDatabaseStats() async {
    final stats = <String, dynamic>{};

    for (final table in allTables) {
      final count = await customSelect('SELECT COUNT(*) as count FROM ${table.actualTableName}')
          .getSingle()
          .data['count'] as int;
      stats[table.actualTableName] = count;
    }

    return stats;
  }

  Future<void> backup(String filePath) async {
    await customStatement('VACUUM INTO ?', [filePath]);
  }

  Future<void> restore(String filePath) async {
    // Implementation would involve copying the database file
    // and reopening the connection
    throw UnimplementedError('Database restore needs to be implemented at the file system level');
  }

  Future<String> getDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, 'cannai.db');
  }

  Future<int> getDatabaseSize() async {
    final path = await getDatabasePath();
    final file = File(path);
    return await file.length();
  }
}

// Database connection opener
QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cannai.db'));

    // Also run drift on the web with fallback to native
    if (Platform.isIOS || Platform.isAndroid) {
      return NativeDatabase.createInBackground(file);
    } else {
      return NativeDatabase(file);
    }
  });
}

// Custom exception for database operations
class DatabaseException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;

  DatabaseException(this.message, {this.operation, this.originalError});

  @override
  String toString() {
    final buffer = StringBuffer('DatabaseException: $message');
    if (operation != null) {
      buffer.write(' (operation: $operation)');
    }
    if (originalError != null) {
      buffer.write(' (original error: $originalError)');
    }
    return buffer.toString();
  }
}

// Database transaction helper
extension TransactionHelper on CannaAIDatabase {
  Future<T> safeTransaction<T>(Future<T> Function(Transaction) action, {
    Duration? timeout,
    int? retryCount,
  }) async {
    final attempts = retryCount ?? 3;
    final timeoutDuration = timeout ?? const Duration(seconds: 30);

    for (int attempt = 0; attempt < attempts; attempt++) {
      try {
        return await transaction(action).timeout(timeoutDuration);
      } catch (e) {
        if (attempt == attempts - 1) rethrow;

        // Log the error and retry
        print('Database transaction failed (attempt ${attempt + 1}/$attempts): $e');
        await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
      }
    }

    throw DatabaseException('Transaction failed after $attempts attempts');
  }
}