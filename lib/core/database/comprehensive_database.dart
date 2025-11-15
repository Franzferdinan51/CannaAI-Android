// Comprehensive database implementation for CannaAI Android
// Matches the data models from the web application

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'comprehensive_database.g.dart';

// ==================== DATABASE TABLES ====================

@DataClassName('UserData')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get name => text().nullable()();
  TextColumn get avatar => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // JSON fields for complex objects
  TextColumn get settingsJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RoomData')
class Rooms extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get type => text()();
  TextColumn get settingsJson => text()();
  BooleanColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StrainData')
class Strains extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get lineage => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get characteristicsJson => text()();
  TextColumn get optimalConditionsJson => text()();
  TextColumn get commonDeficienciesJson => text()();
  TextColumn get commonPestsJson => text()();
  TextColumn get specialNotesJson => text()();
  BooleanColumn get isPurpleStrain => boolean().withDefault(const Constant(false))();
  TextColumn get image => text().nullable()();
  BooleanColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlantData')
class Plants extends Table {
  TextColumn get id => text()();
  TextColumn get roomId => text()();
  TextColumn get strainId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get type => text()();
  TextColumn get currentStage => text()();
  TextColumn get healthStatus => text()();
  DateTimeColumn get plantedDate => dateTime()();
  DateTimeColumn get expectedHarvestDate => dateTime().nullable()();
  DateTimeColumn get actualHarvestDate => dateTime().nullable()();
  TextColumn get settingsJson => text()();
  BooleanColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SensorDataPoint')
class SensorData extends Table {
  TextColumn get id => text()();
  TextColumn get roomId => text()();
  RealColumn get temperature => real()(); // Celsius
  RealColumn get humidity => real()(); // Percentage
  RealColumn get soilMoisture => real()(); // Percentage
  RealColumn get lightIntensity => real()(); // Lux
  RealColumn get ph => real()(); // pH level
  RealColumn get ec => real()(); // Electrical conductivity
  RealColumn get co2 => real()(); // PPM
  RealColumn get vpd => real()(); // Vapor pressure deficit
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get deviceId => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlantMeasurementData')
class PlantMeasurements extends Table {
  TextColumn get id => text()();
  TextColumn get plantId => text()();
  TextColumn get type => text()();
  RealColumn get value => real()();
  TextColumn get unit => text()();
  DateTimeColumn get measuredAt => dateTime()();
  TextColumn get notes => text().nullable()();
  TextColumn get imagesJson => text()(); // JSON array
  TextColumn get environmentalContextJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AnalysisResultData')
class AnalysisResults extends Table {
  TextColumn get id => text()();
  TextColumn get plantId => text()();
  TextColumn get type => text()();
  RealColumn get healthScore => real()();
  TextColumn get issuesJson => text()(); // JSON array
  TextColumn get recommendationsJson => text()(); // JSON array
  RealColumn get confidence => real()();
  TextColumn get detailsJson => text()(); // JSON object
  TextColumn get imagesJson => text()(); // JSON array
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get analyzedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get aiProvider => text().nullable()();
  TextColumn get aiResponseJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AIChatSessionData')
class AIChatSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get messagesJson => text()(); // JSON array
  TextColumn get contextPlantId => text().nullable()();
  TextColumn get contextRoomId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BooleanColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AutomationRuleData')
class AutomationRules extends Table {
  TextColumn get id => text()();
  TextColumn get roomId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  BooleanColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get conditionsJson => text()(); // JSON object
  TextColumn get actionsJson => text()(); // JSON object
  TextColumn get schedule => text().withDefault(const Constant(''))();
  TextColumn get notificationRecipientsJson => text()(); // JSON array
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastExecuted => dateTime().nullable()();
  BooleanColumn get isCurrentlyActive => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AutomationHistoryData')
class AutomationHistory extends Table {
  TextColumn get id => text()();
  TextColumn get ruleId => text()();
  TextColumn get roomId => text()();
  TextColumn get type => text()();
  BooleanColumn get success => boolean()();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get inputDataJson => text().nullable()(); // JSON object
  TextColumn get outputDataJson => text().nullable()(); // JSON object
  DateTimeColumn get executedAt => dateTime()();
  IntColumn get executionTimeMs => integer()(); // Duration in milliseconds

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InventoryItemData')
class InventoryItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text()();
  TextColumn get supplier => text()();
  RealColumn get currentStock => real()();
  TextColumn get unit => text()();
  RealColumn get minStockLevel => real().withDefault(const Constant(0.0))();
  RealColumn get maxStockLevel => real().withDefault(const Constant(1000.0))();
  RealColumn get unitPrice => real()();
  TextColumn get sku => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get imagesJson => text()(); // JSON array
  TextColumn get propertiesJson => text().nullable()(); // JSON object
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HarvestRecordData')
class HarvestRecords extends Table {
  TextColumn get id => text()();
  TextColumn get plantId => text()();
  TextColumn get roomId => text()();
  RealColumn get wetWeight => real()();
  RealColumn get dryWeight => real()();
  RealColumn get thcContent => real().nullable()();
  RealColumn get cbdContent => real().nullable()();
  IntColumn get cureDays => integer().nullable()();
  TextColumn get quality => text()();
  TextColumn get imagesJson => text()(); // JSON array
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get harvestedAt => dateTime()();
  DateTimeColumn get driedAt => dateTime().nullable()();
  DateTimeColumn get curedAt => dateTime().nullable()();
  TextColumn get testingResultsJson => text().nullable()(); // JSON object

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== DATABASE CLASS ====================

@DriftDatabase(
  tables: [
    Users,
    Rooms,
    Strains,
    Plants,
    SensorData,
    PlantMeasurements,
    AnalysisResults,
    AIChatSessions,
    AutomationRules,
    AutomationHistory,
    InventoryItems,
    HarvestRecords,
  ],
)
class ComprehensiveDatabase extends _$ComprehensiveDatabase {
  ComprehensiveDatabase() : super(_openConnection());

  // ==================== USER MANAGEMENT ====================

  Future<UserData?> getCurrentUser() async {
    return await (select(users)..limit(1)).getSingleOrNull();
  }

  Future<void> saveUser(UserData user) async {
    await into(users).insertOnConflictUpdate(user);
  }

  // ==================== ROOM MANAGEMENT ====================

  Future<List<RoomData>> getAllRooms() async {
    return await (select(rooms)..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  Future<RoomData?> getRoomById(String id) async {
    return await (select(rooms)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> saveRoom(RoomData room) async {
    await into(rooms).insertOnConflictUpdate(room);
  }

  Future<void> deleteRoom(String id) async {
    await (delete(rooms)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ==================== STRAIN MANAGEMENT ====================

  Future<List<StrainData>> getAllStrains() async {
    return await (select(strains)..where((tbl) => tbl.isActive.equals(true))).get();
  }

  Future<StrainData?> getStrainById(String id) async {
    return await (select(strains)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> saveStrain(StrainData strain) async {
    await into(strains).insertOnConflictUpdate(strain);
  }

  // ==================== PLANT MANAGEMENT ====================

  Future<List<PlantData>> getAllPlants() async {
    return await (select(plants)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Future<List<PlantData>> getPlantsByRoom(String roomId) async {
    return await (select(plants)
          ..where((tbl) => tbl.roomId.equals(roomId))
          ..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  Future<PlantData?> getPlantById(String id) async {
    return await (select(plants)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> savePlant(PlantData plant) async {
    await into(plants).insertOnConflictUpdate(plant);
  }

  Future<void> deletePlant(String id) async {
    // Also delete related measurements and analysis results
    await transaction(() async {
      await (delete(plantMeasurements)..where((tbl) => tbl.plantId.equals(id))).go();
      await (delete(analysisResults)..where((tbl) => tbl.plantId.equals(id))).go();
      await (delete(plants)..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  // ==================== SENSOR DATA ====================

  Future<List<SensorDataPoint>> getSensorDataByRoom(String roomId, {int limit = 100}) async {
    return await (select(sensorData)
          ..where((tbl) => tbl.roomId.equals(roomId))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
          ..limit(limit)).get();
  }

  Future<SensorDataPoint?> getLatestSensorData(String roomId) async {
    return await (select(sensorData)
          ..where((tbl) => tbl.roomId.equals(roomId))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
          ..limit(1)).getSingleOrNull();
  }

  Future<void> saveSensorData(SensorDataPoint data) async {
    await into(sensorData).insert(data);
  }

  Future<void> saveBatchSensorData(List<SensorDataPoint> dataList) async {
    await batch((batch) {
      for (final data in dataList) {
        batch.insert(sensorData, data);
      }
    });
  }

  Future<void> cleanupOldSensorData({Duration olderThan = const Duration(days: 90)}) async {
    final cutoffDate = DateTime.now().subtract(olderThan);
    await (delete(sensorData)..where((tbl) => tbl.timestamp.isSmallerThanValue(cutoffDate))).go();
  }

  // ==================== PLANT MEASUREMENTS ====================

  Future<List<PlantMeasurementData>> getPlantMeasurements(String plantId) async {
    return await (select(plantMeasurements)
          ..where((tbl) => tbl.plantId.equals(plantId))
          ..orderBy([(t) => OrderingTerm(expression: t.measuredAt, mode: OrderingMode.desc)])).get();
  }

  Future<void> savePlantMeasurement(PlantMeasurementData measurement) async {
    await into(plantMeasurements).insert(measurement);
  }

  // ==================== ANALYSIS RESULTS ====================

  Future<List<AnalysisResultData>> getAnalysisResults(String plantId) async {
    return await (select(analysisResults)
          ..where((tbl) => tbl.plantId.equals(plantId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])).get();
  }

  Future<AnalysisResultData?> getLatestAnalysis(String plantId) async {
    return await (select(analysisResults)
          ..where((tbl) => tbl.plantId.equals(plantId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
          ..limit(1)).getSingleOrNull();
  }

  Future<void> saveAnalysisResult(AnalysisResultData result) async {
    await into(analysisResults).insert(result);
  }

  // ==================== AI CHAT ====================

  Future<List<AIChatSessionData>> getChatSessions() async {
    return await (select(aiChatSessions)
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)])).get();
  }

  Future<AIChatSessionData?> getChatSessionById(String id) async {
    return await (select(aiChatSessions)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> saveChatSession(AIChatSessionData session) async {
    await into(aiChatSessions).insertOnConflictUpdate(session);
  }

  Future<void> deleteChatSession(String id) async {
    await (delete(aiChatSessions)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ==================== AUTOMATION ====================

  Future<List<AutomationRuleData>> getAutomationRules(String roomId) async {
    return await (select(automationRules)
          ..where((tbl) => tbl.roomId.equals(roomId))
          ..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  Future<void> saveAutomationRule(AutomationRuleData rule) async {
    await into(automationRules).insertOnConflictUpdate(rule);
  }

  Future<void> deleteAutomationRule(String id) async {
    await (delete(automationRules)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> saveAutomationHistory(AutomationHistoryData history) async {
    await into(automationHistory).insert(history);
  }

  Future<List<AutomationHistoryData>> getAutomationHistory(String roomId, {int limit = 50}) async {
    return await (select(automationHistory)
          ..where((tbl) => tbl.roomId.equals(roomId))
          ..orderBy([(t) => OrderingTerm(expression: t.executedAt, mode: OrderingMode.desc)])
          ..limit(limit)).get();
  }

  // ==================== INVENTORY ====================

  Future<List<InventoryItemData>> getAllInventoryItems() async {
    return await (select(inventoryItems)..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  Future<List<InventoryItemData>> getLowStockItems() async {
    return await (select(inventoryItems)
          ..where((tbl) => tbl.currentStock.isSmallerThanValue(tbl.minStockLevel))).get();
  }

  Future<void> saveInventoryItem(InventoryItemData item) async {
    await into(inventoryItems).insertOnConflictUpdate(item);
  }

  Future<void> deleteInventoryItem(String id) async {
    await (delete(inventoryItems)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ==================== HARVEST RECORDS ====================

  Future<List<HarvestRecordData>> getHarvestRecords({String? roomId}) async {
    final query = select(harvestRecords)..orderBy([(t) => OrderingTerm(expression: t.harvestedAt, mode: OrderingMode.desc)]);

    if (roomId != null) {
      query.where((tbl) => tbl.roomId.equals(roomId));
    }

    return await query.get();
  }

  Future<void> saveHarvestRecord(HarvestRecordData record) async {
    await into(harvestRecords).insertOnConflictUpdate(record);
  }

  // ==================== DATABASE MAINTENANCE ====================

  Future<void> clearAllData() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }

  Future<Map<String, int>> getDatabaseStats() async {
    final stats = <String, int>{};

    for (final table in allTables) {
      final count = await (selectOnly(table).get()).then((rows) => rows.length);
      stats[table.actualTableName] = count;
    }

    return stats;
  }

  Future<void> exportToJsonFile(String filePath) async {
    final data = <String, dynamic>{};

    for (final table in allTables) {
      final tableData = await (select(table)).get();
      data[table.actualTableName] = tableData;
    }

    final file = File(filePath);
    await file.writeAsString(_prettyJsonEncode(data));
  }

  String _prettyJsonEncode(Map<String, dynamic> data) {
    // Simple pretty JSON encoding - in production, use a proper library
    return data.toString();
  }
}

// ==================== DATABASE CONNECTION ====================

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cannaai_database.sqlite'));

    return NativeDatabase(file, logStatements: true);
  });
}

// ==================== DATABASE SERVICE ====================

class DatabaseService {
  static ComprehensiveDatabase? _database;

  static ComprehensiveDatabase get instance {
    _database ??= ComprehensiveDatabase();
    return _database!;
  }

  static Future<void> initialize() async {
    final db = instance;
    // Run any migrations or initial data setup
    await db.customSelect('SELECT 1').get();
  }

  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

// ==================== DATA ACCESS OBJECTS (DAOs) ====================

class UserDao {
  final ComprehensiveDatabase _db;

  UserDao(this._db);

  Future<UserData?> getCurrentUser() => _db.getCurrentUser();
  Future<void> saveUser(UserData user) => _db.saveUser(user);
}

class RoomDao {
  final ComprehensiveDatabase _db;

  RoomDao(this._db);

  Future<List<RoomData>> getAllRooms() => _db.getAllRooms();
  Future<RoomData?> getRoomById(String id) => _db.getRoomById(id);
  Future<void> saveRoom(RoomData room) => _db.saveRoom(room);
  Future<void> deleteRoom(String id) => _db.deleteRoom(id);
}

class PlantDao {
  final ComprehensiveDatabase _db;

  PlantDao(this._db);

  Future<List<PlantData>> getAllPlants() => _db.getAllPlants();
  Future<List<PlantData>> getPlantsByRoom(String roomId) => _db.getPlantsByRoom(roomId);
  Future<PlantData?> getPlantById(String id) => _db.getPlantById(id);
  Future<void> savePlant(PlantData plant) => _db.savePlant(plant);
  Future<void> deletePlant(String id) => _db.deletePlant(id);
  Future<List<PlantMeasurementData>> getMeasurements(String plantId) => _db.getPlantMeasurements(plantId);
  Future<void> saveMeasurement(PlantMeasurementData measurement) => _db.savePlantMeasurement(measurement);
  Future<List<AnalysisResultData>> getAnalysisResults(String plantId) => _db.getAnalysisResults(plantId);
  Future<AnalysisResultData?> getLatestAnalysis(String plantId) => _db.getLatestAnalysis(plantId);
  Future<void> saveAnalysisResult(AnalysisResultData result) => _db.saveAnalysisResult(result);
}

class SensorDao {
  final ComprehensiveDatabase _db;

  SensorDao(this._db);

  Future<SensorDataPoint?> getLatestSensorData(String roomId) => _db.getLatestSensorData(roomId);
  Future<List<SensorDataPoint>> getSensorDataByRoom(String roomId, {int limit = 100}) =>
      _db.getSensorDataByRoom(roomId, limit: limit);
  Future<void> saveSensorData(SensorDataPoint data) => _db.saveSensorData(data);
  Future<void> saveBatchSensorData(List<SensorDataPoint> dataList) => _db.saveBatchSensorData(dataList);
  Future<void> cleanupOldData({Duration olderThan = const Duration(days: 90)}) =>
      _db.cleanupOldSensorData(olderThan: olderThan);
}

class AutomationDao {
  final ComprehensiveDatabase _db;

  AutomationDao(this._db);

  Future<List<AutomationRuleData>> getRules(String roomId) => _db.getAutomationRules(roomId);
  Future<void> saveRule(AutomationRuleData rule) => _db.saveAutomationRule(rule);
  Future<void> deleteRule(String id) => _db.deleteAutomationRule(id);
  Future<void> saveHistory(AutomationHistoryData history) => _db.saveAutomationHistory(history);
  Future<List<AutomationHistoryData>> getHistory(String roomId, {int limit = 50}) =>
      _db.getAutomationHistory(roomId, limit: limit);
}

class InventoryDao {
  final ComprehensiveDatabase _db;

  InventoryDao(this._db);

  Future<List<InventoryItemData>> getAllItems() => _db.getAllInventoryItems();
  Future<List<InventoryItemData>> getLowStockItems() => _db.getLowStockItems();
  Future<void> saveItem(InventoryItemData item) => _db.saveInventoryItem(item);
  Future<void> deleteItem(String id) => _db.deleteInventoryItem(id);
}

class HarvestDao {
  final ComprehensiveDatabase _db;

  HarvestDao(this._db);

  Future<List<HarvestRecordData>> getRecords({String? roomId}) => _db.getHarvestRecords(roomId: roomId);
  Future<void> saveRecord(HarvestRecordData record) => _db.saveHarvestRecord(record);
}