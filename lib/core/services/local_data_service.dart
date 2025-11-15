import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';

/// Local-only data service replacing all backend API calls
/// Handles all data operations locally using SQLite and SharedPreferences
class LocalDataService {
  static final LocalDataService _instance = LocalDataService._internal();
  factory LocalDataService() => _instance;
  LocalDataService._internal();

  late final Database _database;
  late final SharedPreferences _prefs;
  final Logger _logger = Logger();

  /// Initialize local storage and database
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _initializeDatabase();
      _logger.i('Local data service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize local data service: $e');
      rethrow;
    }
  }

  /// Initialize SQLite database with all required tables
  Future<void> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, AppConstants.databaseName);

    _database = await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  /// Create all database tables
  Future<void> _createTables(Database db, int version) async {
    // Plant analysis results table
    await db.execute('''
      CREATE TABLE plant_analyses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        strain TEXT NOT NULL,
        symptoms TEXT,
        confidence_score REAL,
        recommendations TEXT,
        created_at TEXT NOT NULL,
        room_id TEXT DEFAULT 'default'
      )
    ''');

    // Sensor data table
    await db.execute('''
      CREATE TABLE sensor_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id TEXT NOT NULL,
        sensor_type TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // Strain profiles table
    await db.execute('''
      CREATE TABLE strain_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        optimal_temp_min REAL,
        optimal_temp_max REAL,
        optimal_humidity_min REAL,
        optimal_humidity_max REAL,
        optimal_ph_min REAL,
        optimal_ph_max REAL,
        flowering_time INTEGER,
        difficulty TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Automation schedules table
    await db.execute('''
      CREATE TABLE automation_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id TEXT NOT NULL,
        device_type TEXT NOT NULL,
        action TEXT NOT NULL,
        schedule_time TEXT NOT NULL,
        enabled INTEGER DEFAULT 1,
        parameters TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Chat history table
    await db.execute('''
      CREATE TABLE chat_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_message TEXT NOT NULL,
        ai_response TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        session_id TEXT
      )
    ''');

    // Room configurations table
    await db.execute('''
      CREATE TABLE room_configs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        settings TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Insert default strain profiles
    await _insertDefaultStrains(db);

    _logger.i('All database tables created successfully');
  }

  /// Insert default strain profiles into database
  Future<void> _insertDefaultStrains(Database db) async {
    final defaultStrains = [
      {
        'name': 'Blue Dream',
        'type': 'Hybrid',
        'description': 'Balanced hybrid known for relaxation and gentle cerebral stimulation',
        'optimal_temp_min': 20.0,
        'optimal_temp_max': 28.0,
        'optimal_humidity_min': 45.0,
        'optimal_humidity_max': 65.0,
        'optimal_ph_min': 5.5,
        'optimal_ph_max': 6.5,
        'flowering_time': 9,
        'difficulty': 'Easy',
      },
      {
        'name': 'Girl Scout Cookies',
        'type': 'Hybrid',
        'description': 'Potent hybrid with euphoric effects and full-body relaxation',
        'optimal_temp_min': 21.0,
        'optimal_temp_max': 29.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 60.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'flowering_time': 8,
        'difficulty': 'Medium',
      },
      {
        'name': 'OG Kush',
        'type': 'Hybrid',
        'description': 'Classic strain with stress-relieving effects',
        'optimal_temp_min': 22.0,
        'optimal_temp_max': 30.0,
        'optimal_humidity_min': 35.0,
        'optimal_humidity_max': 55.0,
        'optimal_ph_min': 6.0,
        'optimal_ph_max': 7.0,
        'flowering_time': 8,
        'difficulty': 'Medium',
      },
      {
        'name': 'Purple Haze',
        'type': 'Sativa',
        'description': 'Energizing sativa with dreamy, psychedelic effects',
        'optimal_temp_min': 19.0,
        'optimal_temp_max': 27.0,
        'optimal_humidity_min': 50.0,
        'optimal_humidity_max': 70.0,
        'optimal_ph_min': 5.5,
        'optimal_ph_max': 6.5,
        'flowering_time': 10,
        'difficulty': 'Hard',
      },
      {
        'name': 'Northern Lights',
        'type': 'Indica',
        'description': 'Relaxing indica with resinous buds and fast flowering',
        'optimal_temp_min': 18.0,
        'optimal_temp_max': 26.0,
        'optimal_humidity_min': 40.0,
        'optimal_humidity_max': 60.0,
        'optimal_ph_min': 5.8,
        'optimal_ph_max': 6.8,
        'flowering_time': 7,
        'difficulty': 'Easy',
      },
    ];

    final now = DateTime.now().toIso8601String();
    for (final strain in defaultStrains) {
      await db.insert(
        'strain_profiles',
        {...strain, 'created_at': now},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Upgrade database tables
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades in future versions
    _logger.i('Database upgraded from version $oldVersion to $newVersion');
  }

  // ==================== PLANT ANALYSIS ====================

  /// Save plant analysis results locally
  Future<Map<String, dynamic>> savePlantAnalysis({
    required String imagePath,
    required String strain,
    required List<String> symptoms,
    required double confidenceScore,
    required List<String> recommendations,
    String roomId = 'default',
  }) async {
    try {
      final analysisData = {
        'image_path': imagePath,
        'strain': strain,
        'symptoms': jsonEncode(symptoms),
        'confidence_score': confidenceScore,
        'recommendations': jsonEncode(recommendations),
        'created_at': DateTime.now().toIso8601String(),
        'room_id': roomId,
      };

      final id = await _database.insert('plant_analyses', analysisData);

      final result = await _database.query(
        'plant_analyses',
        where: 'id = ?',
        whereArgs: [id],
      );

      _logger.i('Plant analysis saved locally with ID: $id');
      return result.first;
    } catch (e) {
      _logger.e('Failed to save plant analysis: $e');
      rethrow;
    }
  }

  /// Get plant analysis history
  Future<List<Map<String, dynamic>>> getPlantAnalysisHistory({
    String? roomId,
    int? limit,
  }) async {
    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (roomId != null) {
        whereClause = 'room_id = ?';
        whereArgs.add(roomId);
      }

      final result = await _database.query(
        'plant_analyses',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'created_at DESC',
        limit: limit,
      );

      return result;
    } catch (e) {
      _logger.e('Failed to get plant analysis history: $e');
      rethrow;
    }
  }

  // ==================== SENSOR DATA ====================

  /// Save sensor reading
  Future<void> saveSensorData({
    required String roomId,
    required String sensorType,
    required double value,
    required String unit,
  }) async {
    try {
      final sensorData = {
        'room_id': roomId,
        'sensor_type': sensorType,
        'value': value,
        'unit': unit,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _database.insert('sensor_data', sensorData);
    } catch (e) {
      _logger.e('Failed to save sensor data: $e');
      rethrow;
    }
  }

  /// Get sensor data for a room
  Future<List<Map<String, dynamic>>> getSensorData({
    required String roomId,
    required String sensorType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      String whereClause = 'room_id = ? AND sensor_type = ?';
      List<dynamic> whereArgs = [roomId, sensorType];

      if (startDate != null) {
        whereClause += ' AND timestamp >= ?';
        whereArgs.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        whereClause += ' AND timestamp <= ?';
        whereArgs.add(endDate.toIso8601String());
      }

      final result = await _database.query(
        'sensor_data',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return result;
    } catch (e) {
      _logger.e('Failed to get sensor data: $e');
      rethrow;
    }
  }

  /// Get latest sensor readings for all rooms
  Future<Map<String, Map<String, dynamic>>> getLatestSensorData() async {
    try {
      final result = await _database.rawQuery('''
        SELECT room_id, sensor_type, value, unit, timestamp
        FROM sensor_data s1
        WHERE timestamp = (
          SELECT MAX(timestamp)
          FROM sensor_data s2
          WHERE s2.room_id = s1.room_id AND s2.sensor_type = s1.sensor_type
        )
        ORDER BY room_id, sensor_type
      ''');

      final Map<String, Map<String, dynamic>> roomData = {};

      for (final row in result) {
        final roomId = row['room_id'] as String;
        roomData.putIfAbsent(roomId, () => {});
        roomData[roomId]![row['sensor_type'] as String] = row;
      }

      return roomData;
    } catch (e) {
      _logger.e('Failed to get latest sensor data: $e');
      rethrow;
    }
  }

  // ==================== STRAIN PROFILES ====================

  /// Get all strain profiles
  Future<List<Map<String, dynamic>>> getStrainProfiles() async {
    try {
      final result = await _database.query(
        'strain_profiles',
        orderBy: 'name ASC',
      );
      return result;
    } catch (e) {
      _logger.e('Failed to get strain profiles: $e');
      rethrow;
    }
  }

  /// Save strain profile
  Future<Map<String, dynamic>> saveStrainProfile(Map<String, dynamic> strainData) async {
    try {
      final data = {
        ...strainData,
        'created_at': DateTime.now().toIso8601String(),
      };

      final id = await _database.insert(
        'strain_profiles',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final result = await _database.query(
        'strain_profiles',
        where: 'id = ?',
        whereArgs: [id],
      );

      _logger.i('Strain profile saved with ID: $id');
      return result.first;
    } catch (e) {
      _logger.e('Failed to save strain profile: $e');
      rethrow;
    }
  }

  // ==================== CHAT HISTORY ====================

  /// Save chat message
  Future<void> saveChatMessage({
    required String userMessage,
    required String aiResponse,
    String? sessionId,
  }) async {
    try {
      final chatData = {
        'user_message': userMessage,
        'ai_response': aiResponse,
        'timestamp': DateTime.now().toIso8601String(),
        'session_id': sessionId ?? 'default',
      };

      await _database.insert('chat_history', chatData);
    } catch (e) {
      _logger.e('Failed to save chat message: $e');
      rethrow;
    }
  }

  /// Get chat history
  Future<List<Map<String, dynamic>>> getChatHistory({
    String? sessionId,
    int? limit,
  }) async {
    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (sessionId != null) {
        whereClause = 'session_id = ?';
        whereArgs.add(sessionId);
      }

      final result = await _database.query(
        'chat_history',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return result;
    } catch (e) {
      _logger.e('Failed to get chat history: $e');
      rethrow;
    }
  }

  // ==================== AUTOMATION ====================

  /// Save automation schedule
  Future<Map<String, dynamic>> saveAutomationSchedule({
    required String roomId,
    required String deviceType,
    required String action,
    required String scheduleTime,
    bool enabled = true,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final scheduleData = {
        'room_id': roomId,
        'device_type': deviceType,
        'action': action,
        'schedule_time': scheduleTime,
        'enabled': enabled ? 1 : 0,
        'parameters': jsonEncode(parameters ?? {}),
        'created_at': DateTime.now().toIso8601String(),
      };

      final id = await _database.insert('automation_schedules', scheduleData);

      final result = await _database.query(
        'automation_schedules',
        where: 'id = ?',
        whereArgs: [id],
      );

      _logger.i('Automation schedule saved with ID: $id');
      return result.first;
    } catch (e) {
      _logger.e('Failed to save automation schedule: $e');
      rethrow;
    }
  }

  /// Get automation schedules for a room
  Future<List<Map<String, dynamic>>> getAutomationSchedules({
    required String roomId,
    bool? enabledOnly,
  }) async {
    try {
      String whereClause = 'room_id = ?';
      List<dynamic> whereArgs = [roomId];

      if (enabledOnly == true) {
        whereClause += ' AND enabled = ?';
        whereArgs.add(1);
      }

      final result = await _database.query(
        'automation_schedules',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'schedule_time ASC',
      );

      return result;
    } catch (e) {
      _logger.e('Failed to get automation schedules: $e');
      rethrow;
    }
  }

  // ==================== ROOM CONFIGURATION ====================

  /// Save room configuration
  Future<void> saveRoomConfig({
    required String roomId,
    required String name,
    required Map<String, dynamic> settings,
  }) async {
    try {
      final configData = {
        'room_id': roomId,
        'name': name,
        'settings': jsonEncode(settings),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _database.insert(
        'room_configs',
        configData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _logger.i('Room configuration saved for: $roomId');
    } catch (e) {
      _logger.e('Failed to save room config: $e');
      rethrow;
    }
  }

  /// Get room configuration
  Future<Map<String, dynamic>?> getRoomConfig(String roomId) async {
    try {
      final result = await _database.query(
        'room_configs',
        where: 'room_id = ?',
        whereArgs: [roomId],
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('Failed to get room config: $e');
      rethrow;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Clear old data to manage storage space
  Future<void> clearOldData({int daysToKeep = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      // Clear old sensor data
      await _database.delete(
        'sensor_data',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );

      // Clear old chat history
      await _database.delete(
        'chat_history',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );

      _logger.i('Old data cleared successfully');
    } catch (e) {
      _logger.e('Failed to clear old data: $e');
      rethrow;
    }
  }

  /// Export all data to JSON for backup
  Future<Map<String, dynamic>> exportAllData() async {
    try {
      final analyses = await _database.query('plant_analyses');
      final sensorData = await _database.query('sensor_data');
      final strains = await _database.query('strain_profiles');
      final schedules = await _database.query('automation_schedules');
      final chatHistory = await _database.query('chat_history');
      final roomConfigs = await _database.query('room_configs');

      return {
        'plant_analyses': analyses,
        'sensor_data': sensorData,
        'strain_profiles': strains,
        'automation_schedules': schedules,
        'chat_history': chatHistory,
        'room_configs': roomConfigs,
        'export_timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to export data: $e');
      rethrow;
    }
  }

  /// Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final analysisCount = Sqflite.firstIntValue(
        await _database.rawQuery('SELECT COUNT(*) FROM plant_analyses')
      ) ?? 0;

      final sensorDataCount = Sqflite.firstIntValue(
        await _database.rawQuery('SELECT COUNT(*) FROM sensor_data')
      ) ?? 0;

      final strainCount = Sqflite.firstIntValue(
        await _database.rawQuery('SELECT COUNT(*) FROM strain_profiles')
      ) ?? 0;

      final scheduleCount = Sqflite.firstIntValue(
        await _database.rawQuery('SELECT COUNT(*) FROM automation_schedules')
      ) ?? 0;

      return {
        'plant_analyses_count': analysisCount,
        'sensor_data_count': sensorDataCount,
        'strain_profiles_count': strainCount,
        'automation_schedules_count': scheduleCount,
        'database_size_bytes': await _getDatabaseSize(),
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to get database stats: $e');
      rethrow;
    }
  }

  /// Get database file size
  Future<int> _getDatabaseSize() async {
    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, AppConstants.databaseName);
      final file = await _database.openDatabase(path);
      // Note: Getting exact file size requires additional platform-specific code
      // This is a simplified implementation
      return 0; // Placeholder
    } catch (e) {
      _logger.e('Failed to get database size: $e');
      return 0;
    }
  }

  /// Close database connection
  Future<void> close() async {
    await _database.close();
    _logger.i('Local data service closed');
  }
}