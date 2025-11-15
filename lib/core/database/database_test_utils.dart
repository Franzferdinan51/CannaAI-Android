import 'dart:async';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'models.dart';
import 'database_service.dart';

// Test database configuration
class TestDatabaseConfig extends DatabaseConfig {
  const TestDatabaseConfig({
    String databaseName = 'test_cannai.db',
    bool enableForeignKeys = true,
    bool enableWALMode = false, // Disable WAL for testing
    int cacheSize = 1000,
    Duration busyTimeout = const Duration(seconds: 5),
    bool enableQueryLogging = false,
    Duration backupInterval = const Duration(hours: 24),
    int maxBackupFiles = 3,
    Duration dataRetentionPeriod = const Duration(days: 30),
  }) : super(
    databaseName: databaseName,
    enableForeignKeys: enableForeignKeys,
    enableWALMode: enableWALMode,
    cacheSize: cacheSize,
    busyTimeout: busyTimeout,
    enableQueryLogging: enableQueryLogging,
    backupInterval: backupInterval,
    maxBackupFiles: maxBackupFiles,
    dataRetentionPeriod: dataRetentionPeriod,
  );
}

// Test database service
class TestDatabaseService {
  static TestDatabaseService? _instance;
  late final CannaAIDatabase _database;
  late final Logger _logger;
  late final SharedPreferences _prefs;
  late final TestDatabaseConfig _config;

  TestDatabaseService._internal();

  static TestDatabaseService getInstance() {
    _instance ??= TestDatabaseService._internal();
    return _instance!;
  }

  Future<void> initialize({TestDatabaseConfig? config}) async {
    _config = config ?? const TestDatabaseConfig();
    _logger = Logger();
    _prefs = await SharedPreferences.getInstance();

    // Create in-memory database for testing
    _database = CannaAIDatabase(DatabaseConnection(NativeDatabase.memory()));

    await _database.customStatement('PRAGMA foreign_keys = ${_config.enableForeignKeys ? 'ON' : 'OFF'}');
  }

  CannaAIDatabase get database => _database;
  TestDatabaseConfig get config => _config;

  Future<void> close() async {
    await _database.close();
  }

  Future<void> reset() async {
    await _database.clearAllData();
    await _prefs.clear();
  }
}

// Test data factory
class TestDataFactory {
  static final Random _random = Random();
  static int _userIdCounter = 1;
  static int _roomIdCounter = 1;
  static int _strainIdCounter = 1;
  static int _plantIdCounter = 1;
  static int _deviceIdCounter = 1;

  static String _randomString({int length = 10}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
    ));
  }

  static double _randomDouble({double min = 0.0, double max = 100.0}) {
    return min + _random.nextDouble() * (max - min);
  }

  static int _randomInt({int min = 0, int max = 100}) {
    return min + _random.nextInt(max - min);
  }

  static DateTime _randomDateTime({DateTime? start, DateTime? end}) {
    start ??= DateTime.now().subtract(const Duration(days: 365));
    end ??= DateTime.now();
    return start.add(Duration(
      seconds: _random.nextInt(end.difference(start).inSeconds),
    ));
  }

  static List<String> _randomList({int minItems = 1, int maxItems = 5}) {
    final itemCount = _randomInt(min: minItems, max: maxItems);
    return List.generate(itemCount, (_) => _randomString(length: 5));
  }

  // Create test user
  static UsersCompanion createTestUser({
    int? id,
    String? email,
    String? username,
    String? displayName,
    String? avatarUrl,
    bool? isActive,
    bool? isAdmin,
    Map<String, dynamic>? preferences,
  }) {
    final userId = _userIdCounter++;
    return UsersCompanion.insert(
      email: email ?? 'user$userId@test.com',
      username: username ?? 'testuser$userId',
      passwordHash: 'hashed_password_$userId',
      displayName: displayName ?? 'Test User $userId',
      avatarUrl: Value(avatarUrl ?? 'https://example.com/avatar$userId.jpg'),
      isActive: Value(isActive ?? true),
      isAdmin: Value(isAdmin ?? false),
      preferences: Value(preferences != null ? jsonEncode(preferences) : null),
      createdAt: Value(_randomDateTime()),
      updatedAt: Value(_randomDateTime()),
      lastLoginAt: Value(_randomDateTime()),
      userId: Value(userId),
    );
  }

  // Create test room
  static RoomsCompanion createTestRoom({
    int? id,
    String? name,
    String? description,
    String? location,
    String? imageUrl,
    String? roomType,
    double? size,
    double? targetTemperature,
    double? targetHumidity,
    double? targetPh,
    double? targetEc,
    bool? isActive,
    int? userId,
  }) {
    final roomId = _roomIdCounter++;
    final roomTypes = ['vegetative', 'flowering', 'drying', 'general'];
    return RoomsCompanion.insert(
      name: name ?? 'Test Room $roomId',
      description: Value(description ?? 'Test room description $roomId'),
      location: Value(location ?? 'Building A, Floor $roomId'),
      imageUrl: Value(imageUrl ?? 'https://example.com/room$roomId.jpg'),
      roomType: Value(roomType ?? roomTypes[_random.nextInt(roomTypes.length)]),
      size: Value(size ?? _randomDouble(min: 5.0, max: 50.0)),
      targetTemperature: Value(targetTemperature ?? _randomDouble(min: 18.0, max: 28.0)),
      targetHumidity: Value(targetHumidity ?? _randomDouble(min: 40.0, max: 70.0)),
      targetPh: Value(targetPh ?? _randomDouble(min: 5.5, max: 6.5)),
      targetEc: Value(targetEc ?? _randomDouble(min: 1.0, max: 2.5)),
      isActive: Value(isActive ?? true),
      createdAt: Value(_randomDateTime()),
      updatedAt: Value(_randomDateTime()),
      userId: Value(userId ?? _userIdCounter),
    );
  }

  // Create test strain
  static StrainsCompanion createTestStrain({
    int? id,
    String? name,
    String? breeder,
    String? genetics,
    String? type,
    String? thcLevel,
    String? cbdLevel,
    String? floweringTime,
    String? yield,
    String? difficulty,
    String? description,
    String? imageUrl,
    String? flavorProfile,
    String? effects,
    String? medicalUses,
    String? growthCharacteristics,
    double? optimalTemperature,
    double? optimalHumidity,
    double? optimalPh,
    bool? isActive,
    int? userId,
  }) {
    final strainId = _strainIdCounter++;
    final types = ['indica', 'sativa', 'hybrid', 'ruderalis'];
    final difficulties = ['easy', 'medium', 'hard', 'expert'];
    return StrainsCompanion.insert(
      name: name ?? 'Test Strain $strainId',
      breeder: Value(breeder ?? 'Test Breeder $strainId'),
      genetics: Value(genetics ?? 'Genetics $strainId'),
      type: Value(type ?? types[_random.nextInt(types.length)]),
      thcLevel: Value(thcLevel ?? '${_randomInt(min: 15, max: 25)}%'),
      cbdLevel: Value(cbdLevel ?? '${_randomInt(min: 0, max: 15)}%'),
      floweringTime: Value(floweringTime ?? '${_randomInt(min: 6, max: 12)} weeks'),
      yield: Value(yield ?? '${_randomInt(min: 200, max: 600)} g/m²'),
      difficulty: Value(difficulty ?? difficulties[_random.nextInt(difficulties.length)]),
      description: Value(description ?? 'Test strain description $strainId'),
      imageUrl: Value(imageUrl ?? 'https://example.com/strain$strainId.jpg'),
      flavorProfile: Value(flavorProfile ?? 'Earthy, Sweet, Citrus'),
      effects: Value(effects ?? 'Relaxed, Happy, Euphoric'),
      medicalUses: Value(medicalUses ?? 'Pain, Stress, Insomnia'),
      growthCharacteristics: Value(growthCharacteristics ?? 'Medium height, bushy'),
      optimalTemperature: Value(optimalTemperature ?? _randomDouble(min: 20.0, max: 26.0)),
      optimalHumidity: Value(optimalHumidity ?? _randomDouble(min: 40.0, max: 60.0)),
      optimalPh: Value(optimalPh ?? _randomDouble(min: 5.8, max: 6.3)),
      isActive: Value(isActive ?? true),
      createdAt: Value(_randomDateTime()),
      updatedAt: Value(_randomDateTime()),
      userId: Value(userId ?? _userIdCounter),
    );
  }

  // Create test plant
  static PlantsCompanion createTestPlant({
    int? id,
    String? name,
    int? strainId,
    int? roomId,
    String? growthStage,
    String? healthStatus,
    DateTime? plantedDate,
    DateTime? expectedHarvestDate,
    DateTime? actualHarvestDate,
    double? height,
    double? weight,
    String? gender,
    String? phenotype,
    String? notes,
    String? imageUrl,
    double? temperature,
    double? humidity,
    double? ph,
    double? ec,
    double? lightIntensity,
    int? wateringCount,
    DateTime? lastWateringAt,
    int? feedingCount,
    DateTime? lastFeedingAt,
    bool? isActive,
    bool? isMotherPlant,
    int? userId,
  }) {
    final plantId = _plantIdCounter++;
    final growthStages = ['seedling', 'vegetative', 'flowering', 'harvesting'];
    final healthStatuses = ['healthy', 'warning', 'critical'];
    final genders = ['male', 'female', 'hermaphrodite'];

    final planted = plantedDate ?? _randomDateTime(start: DateTime.now().subtract(const Duration(days: 180)));
    final growthDuration = Duration(days: _randomInt(min: 21, max: 150));

    return PlantsCompanion.insert(
      name: name ?? 'Test Plant $plantId',
      strainId: Value(strainId ?? _strainIdCounter),
      roomId: Value(roomId ?? _roomIdCounter),
      growthStage: Value(growthStage ?? growthStages[_random.nextInt(growthStages.length)]),
      healthStatus: Value(healthStatus ?? healthStatuses[_random.nextInt(healthStatuses.length)]),
      plantedDate: Value(planted),
      expectedHarvestDate: Value(expectedHarvestDate ?? planted.add(growthDuration)),
      actualHarvestDate: Value(actualHarvestDate),
      height: Value(height ?? _randomDouble(min: 10.0, max: 200.0)),
      weight: Value(weight ?? _randomDouble(min: 50.0, max: 1000.0)),
      gender: Value(gender ?? genders[_random.nextInt(genders.length)]),
      phenotype: Value(phenotype ?? 'Test phenotype $plantId'),
      notes: Value(notes ?? 'Test notes for plant $plantId'),
      imageUrl: Value(imageUrl ?? 'https://example.com/plant$plantId.jpg'),
      temperature: Value(temperature ?? _randomDouble(min: 18.0, max: 28.0)),
      humidity: Value(humidity ?? _randomDouble(min: 40.0, max: 70.0)),
      ph: Value(ph ?? _randomDouble(min: 5.5, max: 6.5)),
      ec: Value(ec ?? _randomDouble(min: 1.0, max: 2.5)),
      lightIntensity: Value(lightIntensity ?? _randomDouble(min: 200.0, max: 1000.0)),
      wateringCount: Value(wateringCount ?? _randomInt(min: 0, max: 50)),
      lastWateringAt: Value(lastWateringAt ?? _randomDateTime(start: planted)),
      feedingCount: Value(feedingCount ?? _randomInt(min: 0, max: 25)),
      lastFeedingAt: Value(lastFeedingAt ?? _randomDateTime(start: planted)),
      isActive: Value(isActive ?? true),
      isMotherPlant: Value(isMotherPlant ?? false),
      createdAt: Value(_randomDateTime(start: planted)),
      updatedAt: Value(_randomDateTime()),
      userId: Value(userId ?? _userIdCounter),
    );
  }

  // Create test sensor device
  static SensorDevicesCompanion createTestSensorDevice({
    int? id,
    String? deviceId,
    String? name,
    String? type,
    String? manufacturer,
    String? model,
    String? firmwareVersion,
    String? bluetoothAddress,
    String? wifiAddress,
    double? calibrationOffset,
    double? calibrationScale,
    String? unit,
    double? minReading,
    double? maxReading,
    int? batteryLevel,
    bool? isOnline,
    bool? isActive,
    DateTime? lastSeenAt,
    DateTime? lastCalibrationAt,
    int? roomId,
    int? userId,
  }) {
    final deviceIdCounter = _deviceIdCounter++;
    final sensorTypes = ['temperature', 'humidity', 'ph', 'ec', 'light', 'co2'];
    final units = {
      'temperature': 'celsius',
      'humidity': 'percent',
      'ph': 'ph',
      'ec': 'ec',
      'light': 'lux',
      'co2': 'ppm',
    };

    return SensorDevicesCompanion.insert(
      deviceId: deviceId ?? 'DEVICE_$deviceIdCounter',
      name: name ?? 'Test Sensor $deviceIdCounter',
      type: Value(type ?? sensorTypes[_random.nextInt(sensorTypes.length)]),
      manufacturer: Value(manufacturer ?? 'Test Manufacturer'),
      model: Value(model ?? 'Model $deviceIdCounter'),
      firmwareVersion: Value(firmwareVersion ?? '1.0.$deviceIdCounter'),
      bluetoothAddress: Value(bluetoothAddress ?? '00:1B:44:11:3A:B7'),
      wifiAddress: Value(wifiAddress ?? '192.168.1.${_randomInt(min: 100, max: 200)}'),
      calibrationOffset: Value(calibrationOffset ?? _randomDouble(min: -1.0, max: 1.0)),
      calibrationScale: Value(calibrationScale ?? _randomDouble(min: 0.9, max: 1.1)),
      unit: Value(unit ?? units[sensorTypes[_random.nextInt(sensorTypes.length)]] ?? 'standard'),
      minReading: Value(minReading ?? _randomDouble(min: 0.0, max: 50.0)),
      maxReading: Value(maxReading ?? _randomDouble(min: 50.0, max: 100.0)),
      batteryLevel: Value(batteryLevel ?? _randomInt(min: 20, max: 100)),
      isOnline: Value(isOnline ?? _random.nextBool()),
      isActive: Value(isActive ?? true),
      lastSeenAt: Value(lastSeenAt ?? _randomDateTime()),
      lastCalibrationAt: Value(lastCalibrationAt ?? _randomDateTime()),
      roomId: Value(roomId),
      createdAt: Value(_randomDateTime()),
      updatedAt: Value(_randomDateTime()),
      userId: Value(userId ?? _userIdCounter),
    );
  }

  // Create test sensor reading
  static SensorReadingsCompanion createTestSensorReading({
    int? id,
    int? deviceId,
    double? value,
    String? unit,
    String? quality,
    String? notes,
    DateTime? timestamp,
    int? userId,
  }) {
    final qualities = ['good', 'poor', 'error'];
    return SensorReadingsCompanion.insert(
      deviceId: Value(deviceId ?? _deviceIdCounter),
      value: Value(value ?? _randomDouble(min: 0.0, max: 100.0)),
      unit: Value(unit ?? 'standard'),
      quality: Value(quality ?? qualities[_random.nextInt(qualities.length)]),
      notes: Value(notes ?? 'Test reading note'),
      timestamp: Value(timestamp ?? _randomDateTime()),
      userId: Value(userId ?? _userIdCounter),
    );
  }

  // Create test automation rule
  static AutomationRulesCompanion createTestAutomationRule({
    int? id,
    String? name,
    String? description,
    String? triggerType,
    Map<String, dynamic>? triggerCondition,
    String? actionType,
    Map<String, dynamic>? actionParameters,
    bool? isActive,
    DateTime? lastExecutedAt,
    DateTime? nextExecutionAt,
    int? executionCount,
    String? schedule,
    int? priority,
    int? roomId,
    int? deviceId,
    int? userId,
  }) {
    final triggerTypes = ['time', 'sensor_threshold', 'manual'];
    final actionTypes = ['watering', 'lighting', 'climate', 'notification'];

    return AutomationRulesCompanion.insert(
      name: name ?? 'Test Automation Rule $id',
      description: Value(description ?? 'Test automation rule description'),
      triggerType: Value(triggerType ?? triggerTypes[_random.nextInt(triggerTypes.length)]),
      triggerCondition: Value(triggerCondition != null ? jsonEncode(triggerCondition) : '{"sensor": "temperature", "operator": ">", "value": 25}'),
      actionType: Value(actionType ?? actionTypes[_random.nextInt(actionTypes.length)]),
      actionParameters: Value(actionParameters != null ? jsonEncode(actionParameters) : '{"duration": 300}'),
      isActive: Value(isActive ?? _random.nextBool()),
      lastExecutedAt: Value(lastExecutedAt),
      nextExecutionAt: Value(nextExecutionAt ?? _randomDateTime(start: DateTime.now())),
      executionCount: Value(executionCount ?? _randomInt(min: 0, max: 100)),
      schedule: Value(schedule ?? '0 9 * * *'), // Daily at 9 AM
      priority: Value(priority ?? _randomInt(min: 1, max: 10)),
      roomId: Value(roomId),
      deviceId: Value(deviceId),
      createdAt: Value(_randomDateTime()),
      updatedAt: Value(_randomDateTime()),
      userId: Value(userId ?? _userIdCounter),
    );
  }

  // Create test plant analysis
  static PlantAnalysisCompanion createTestPlantAnalysis({
    int? id,
    int? plantId,
    String? analysisType,
    List<String>? symptoms,
    double? healthScore,
    double? confidence,
    String? diagnosis,
    List<String>? recommendations,
    String? imageUrl,
    Map<String, dynamic>? imageAnalysisData,
    double? temperature,
    double? humidity,
    double? ph,
    double? ec,
    double? lightIntensity,
    double? co2Level,
    Map<String, dynamic>? environmentalConditions,
    String? notes,
    DateTime? analysisDate,
    int? userId,
  }) {
    final analysisTypes = ['health', 'growth', 'pest', 'nutrient'];

    return PlantAnalysisCompanion.insert(
      plantId: Value(plantId ?? _plantIdCounter),
      analysisType: Value(analysisType ?? analysisTypes[_random.nextInt(analysisTypes.length)]),
      symptoms: Value(symptoms != null ? jsonEncode(symptoms) : jsonEncode(['yellowing', 'wilting'])),
      healthScore: Value(healthScore ?? _randomDouble(min: 0.0, max: 100.0)),
      confidence: Value(confidence ?? _randomDouble(min: 0.5, max: 1.0)),
      diagnosis: Value(diagnosis ?? 'Test diagnosis'),
      recommendations: Value(recommendations != null ? jsonEncode(recommendations) : jsonEncode(['increase_watering', 'check_ph'])),
      imageUrl: Value(imageUrl ?? 'https://example.com/analysis$id.jpg'),
      imageAnalysisData: Value(imageAnalysisData != null ? jsonEncode(imageAnalysisData) : jsonEncode({})),
      temperature: Value(temperature ?? _randomDouble(min: 18.0, max: 28.0)),
      humidity: Value(humidity ?? _randomDouble(min: 40.0, max: 70.0)),
      ph: Value(ph ?? _randomDouble(min: 5.5, max: 6.5)),
      ec: Value(ec ?? _randomDouble(min: 1.0, max: 2.5)),
      lightIntensity: Value(lightIntensity ?? _randomDouble(min: 200.0, max: 1000.0)),
      co2Level: Value(co2Level ?? _randomDouble(min: 400.0, max: 1500.0)),
      environmentalConditions: Value(environmentalConditions != null ? jsonEncode(environmentalConditions) : jsonEncode({})),
      notes: Value(notes ?? 'Test analysis notes'),
      analysisDate: Value(analysisDate ?? _randomDateTime()),
      createdAt: Value(_randomDateTime()),
      userId: Value(userId ?? _userIdCounter),
    );
  }

  // Reset counters
  static void resetCounters() {
    _userIdCounter = 1;
    _roomIdCounter = 1;
    _strainIdCounter = 1;
    _plantIdCounter = 1;
    _deviceIdCounter = 1;
  }

  // Create a complete test dataset
  static Future<TestDataset> createCompleteDataset(CannaAIDatabase database) async {
    final dataset = TestDataset();

    // Create users
    dataset.users = [
      await database.into(database.users).insert(createTestUser(displayName: 'Admin User', isAdmin: true)),
      await database.into(database.users).insert(createTestUser(displayName: 'Regular User', isAdmin: false)),
    ];

    final userId = dataset.users.first;

    // Create rooms
    dataset.rooms = [
      await database.into(database.rooms).insert(createTestRoom(name: 'Vegetative Room', roomType: 'vegetative', userId: userId)),
      await database.into(database.rooms).insert(createTestRoom(name: 'Flowering Room', roomType: 'flowering', userId: userId)),
    ];

    // Create strains
    dataset.strains = [
      await database.into(database.strains).insert(createTestStrain(name: 'Test Indica', type: 'indica', userId: userId)),
      await database.into(database.strains).insert(createTestStrain(name: 'Test Sativa', type: 'sativa', userId: userId)),
    ];

    // Create plants
    dataset.plants = [
      await database.into(database.plants).insert(createTestPlant(name: 'Plant 1', strainId: dataset.strains.first, roomId: dataset.rooms.first, userId: userId)),
      await database.into(database.plants).insert(createTestPlant(name: 'Plant 2', strainId: dataset.strains.last, roomId: dataset.rooms.last, userId: userId)),
      await database.into(database.plants).insert(createTestPlant(name: 'Mother Plant', strainId: dataset.strains.first, roomId: dataset.rooms.first, isMotherPlant: true, userId: userId)),
    ];

    // Create sensor devices
    dataset.sensorDevices = [
      await database.into(database.sensorDevices).insert(createTestSensorDevice(name: 'Temp Sensor 1', type: 'temperature', roomId: dataset.rooms.first, userId: userId)),
      await database.into(database.sensorDevices).insert(createTestSensorDevice(name: 'Humidity Sensor 1', type: 'humidity', roomId: dataset.rooms.first, userId: userId)),
      await database.into(database.sensorDevices).insert(createTestSensorDevice(name: 'pH Sensor 1', type: 'ph', roomId: dataset.rooms.last, userId: userId)),
    ];

    // Create sensor readings
    dataset.sensorReadings = [];
    for (final deviceId in dataset.sensorDevices) {
      for (int i = 0; i < 10; i++) {
        dataset.sensorReadings.add(
          await database.into(database.sensorReadings).insert(
            createTestSensorReading(deviceId: deviceId, userId: userId)
          ),
        );
      }
    }

    // Create automation rules
    dataset.automationRules = [
      await database.into(database.automationRules).insert(
        createTestAutomationRule(name: 'Watering Rule', triggerType: 'time', actionType: 'watering', roomId: dataset.rooms.first, userId: userId)
      ),
      await database.into(database.automationRules).insert(
        createTestAutomationRule(name: 'Temperature Alert', triggerType: 'sensor_threshold', actionType: 'notification', roomId: dataset.rooms.first, userId: userId)
      ),
    ];

    // Create plant analyses
    dataset.plantAnalyses = [];
    for (final plantId in dataset.plants) {
      for (int i = 0; i < 3; i++) {
        dataset.plantAnalyses.add(
          await database.into(database.plantAnalysis).insert(
            createTestPlantAnalysis(plantId: plantId, userId: userId)
          ),
        );
      }
    }

    return dataset;
  }
}

// Test dataset container
class TestDataset {
  List<int> users = [];
  List<int> rooms = [];
  List<int> strains = [];
  List<int> plants = [];
  List<int> sensorDevices = [];
  List<int> sensorReadings = [];
  List<int> automationRules = [];
  List<int> plantAnalyses = [];

  int get totalRecords => users.length + rooms.length + strains.length + plants.length +
                          sensorDevices.length + sensorReadings.length +
                          automationRules.length + plantAnalyses.length;
}

// Database assertion utilities
class DatabaseAssertions {
  static Future<void> assertTableExists(CannaAIDatabase database, String tableName) async {
    final result = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      variables: [Variable.withString(tableName)]
    ).get();

    if (result.isEmpty) {
      throw AssertionError('Table $tableName does not exist');
    }
  }

  static Future<void> assertRecordCount(CannaAIDatabase database, String tableName, int expectedCount) async {
    final result = await database.customSelect(
      'SELECT COUNT(*) as count FROM $tableName'
    ).getSingle();

    final actualCount = result.read<int>('count');
    if (actualCount != expectedCount) {
      throw AssertionError('Expected $expectedCount records in $tableName, but found $actualCount');
    }
  }

  static Future<void> assertRecordExists(CannaAIDatabase database, String tableName, String condition) async {
    final result = await database.customSelect(
      'SELECT COUNT(*) as count FROM $tableName WHERE $condition'
    ).getSingle();

    final count = result.read<int>('count');
    if (count == 0) {
      throw AssertionError('No record found in $tableName with condition: $condition');
    }
  }

  static Future<void> assertForeignKeyConstraint(CannaAIDatabase database) async {
    final result = await database.customSelect('PRAGMA foreign_key_check').get();
    if (result.isNotEmpty) {
      throw AssertionError('Foreign key constraint violations found: ${result.length}');
    }
  }

  static Future<void> assertDatabaseIntegrity(CannaAIDatabase database) async {
    final result = await database.customSelect('PRAGMA integrity_check').getSingle();
    final integrity = result.read<String>('integrity_check');
    if (integrity != 'ok') {
      throw AssertionError('Database integrity check failed: $integrity');
    }
  }
}

// Performance testing utilities
class PerformanceTestUtils {
  static Future<Duration> measureQueryDuration(Future<void> Function() query) async {
    final stopwatch = Stopwatch()..start();
    await query();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  static Future<Map<String, Duration>> benchmarkQueries(CannaAIDatabase database) async {
    final results = <String, Duration>{};

    // Benchmark SELECT queries
    results['select_all_users'] = await measureQueryDuration(
      () => database.select(database.users).get()
    );

    results['select_all_plants'] = await measureQueryDuration(
      () => database.select(database.plants).get()
    );

    results['select_with_join'] = await measureQueryDuration(
      () => database.select(database.plants).join([
        innerJoin(database.rooms, database.rooms.id.equalsExp(database.plants.roomId)),
        innerJoin(database.strains, database.strains.id.equalsExp(database.plants.strainId)),
      ]).get()
    );

    // Benchmark INSERT queries
    results['insert_user'] = await measureQueryDuration(
      () => database.into(database.users).insert(TestDataFactory.createTestUser())
    );

    // Benchmark UPDATE queries
    final testUser = await (database.select(database.users)..limit(1)).getSingle();
    results['update_user'] = await measureQueryDuration(
      () => database.update(database.users).replace(testUser)
    );

    // Benchmark DELETE queries
    results['delete_user'] = await measureQueryDuration(
      () => database.delete(database.users)..where((tbl) => tbl.id.equals(testUser.id))
    );

    return results;
  }

  static Future<void> stressTestInserts(CannaAIDatabase database, int recordCount) async {
    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < recordCount; i++) {
      await database.into(database.sensorReadings).insert(
        TestDataFactory.createTestSensorReading()
      );
    }

    stopwatch.stop();

    final rate = recordCount / stopwatch.elapsedMilliseconds * 1000; // records per second
    print('Inserted $recordCount records in ${stopwatch.elapsedMilliseconds}ms (${rate.toStringAsFixed(2)} records/sec)');
  }
}