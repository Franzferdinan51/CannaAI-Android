import 'package:drift/drift.dart';

import 'database.dart';

// User DAO
@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<CannaAIDatabase> with _$UserDaoMixin {
  UserDao(CannaAIDatabase db) : super(db);

  Future<User?> getUserById(int id, int userId) =>
    (select(users)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<User?> getUserByEmail(String email, int userId) =>
    (select(users)..where((tbl) => tbl.email.equals(email) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<User?> getUserByUsername(String username, int userId) =>
    (select(users)..where((tbl) => tbl.username.equals(username) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<User>> getAllUsers(int userId) =>
    (select(users)..where((tbl) => tbl.userId.equals(userId))).get();

  Future<bool> emailExists(String email, int userId) async {
    final result = await (selectOnly(users)
      ..addColumns([users.id])
      ..where((tbl) => tbl.email.equals(email) & tbl.userId.equals(userId)))
      .get();
    return result.isNotEmpty;
  }

  Future<bool> usernameExists(String username, int userId) async {
    final result = await (selectOnly(users)
      ..addColumns([users.id])
      ..where((tbl) => tbl.username.equals(username) & tbl.userId.equals(userId)))
      .get();
    return result.isNotEmpty;
  }

  Future<int> createUser(UsersCompanion user) => into(users).insert(user);

  Future<bool> updateUser(User user) => update(users).replace(user);

  Future<int> deleteUser(int id, int userId) =>
    (delete(users)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId))).go();

  Future<int> updateLastLogin(int id, int userId) =>
    (update(users)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(UsersCompanion(lastLoginAt: Value(DateTime.now())));

  Future<int> updatePreferences(int id, int userId, String preferences) =>
    (update(users)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(UsersCompanion(preferences: Value(preferences)));
}

// Room DAO
@DriftAccessor(tables: [Rooms])
class RoomDao extends DatabaseAccessor<CannaAIDatabase> with _$RoomDaoMixin {
  RoomDao(CannaAIDatabase db) : super(db);

  Future<Room?> getRoomById(int id, int userId) =>
    (select(rooms)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<Room>> getAllRooms(int userId) =>
    (select(rooms)..where((tbl) => tbl.userId.equals(userId) & tbl.isActive.equals(true))).get();

  Future<List<Room>> getRoomsByType(String roomType, int userId) =>
    (select(rooms)..where((tbl) => tbl.roomType.equals(roomType) &
                             tbl.userId.equals(userId) &
                             tbl.isActive.equals(true))).get();

  Future<int> createRoom(RoomsCompanion room) => into(rooms).insert(room);

  Future<bool> updateRoom(Room room) => update(rooms).replace(room);

  Future<int> deleteRoom(int id, int userId) =>
    (update(rooms)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(RoomsCompanion(isActive: const Value(false)));

  Future<int> updateRoomTargets(int id, int userId, {
    double? temperature,
    double? humidity,
    double? ph,
    double? ec,
  }) {
    final updates = <Column, dynamic>{};
    if (temperature != null) updates[rooms.targetTemperature] = temperature;
    if (humidity != null) updates[rooms.targetHumidity] = humidity;
    if (ph != null) updates[rooms.targetPh] = ph;
    if (ec != null) updates[rooms.targetEc] = ec;

    return (update(rooms)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(RoomsCompanion.custom(
        targetTemperature: temperature != null ? Value(temperature) : const Value.absent(),
        targetHumidity: humidity != null ? Value(humidity) : const Value.absent(),
        targetPh: ph != null ? Value(ph) : const Value.absent(),
        targetEc: ec != null ? Value(ec) : const Value.absent(),
      ));
  }
}

// Strain DAO
@DriftAccessor(tables: [Strains])
class StrainDao extends DatabaseAccessor<CannaAIDatabase> with _$StrainDaoMixin {
  StrainDao(CannaAIDatabase db) : super(db);

  Future<Strain?> getStrainById(int id, int userId) =>
    (select(strains)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<Strain>> getAllStrains(int userId) =>
    (select(strains)..where((tbl) => tbl.userId.equals(userId) & tbl.isActive.equals(true)))
      .get();

  Future<List<Strain>> getStrainsByType(String type, int userId) =>
    (select(strains)..where((tbl) => tbl.type.equals(type) &
                             tbl.userId.equals(userId) &
                             tbl.isActive.equals(true))).get();

  Future<List<Strain>> searchStrains(String query, int userId) =>
    (select(strains)..where((tbl) =>
      (tbl.name.contains(query) |
       tbl.breeder.contains(query) |
       tbl.description.contains(query)) &
      tbl.userId.equals(userId) &
      tbl.isActive.equals(true))).get();

  Future<int> createStrain(StrainsCompanion strain) => into(strains).insert(strain);

  Future<bool> updateStrain(Strain strain) => update(strains).replace(strain);

  Future<int> deleteStrain(int id, int userId) =>
    (update(strains)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(StrainsCompanion(isActive: const Value(false)));

  Future<bool> strainNameExists(String name, int userId) async {
    final result = await (selectOnly(strains)
      ..addColumns([strains.id])
      ..where((tbl) => tbl.name.equals(name) &
                      tbl.userId.equals(userId) &
                      tbl.isActive.equals(true)))
      .get();
    return result.isNotEmpty;
  }
}

// Plant DAO
@DriftAccessor(tables: [Plants])
class PlantDao extends DatabaseAccessor<CannaAIDatabase> with _$PlantDaoMixin {
  PlantDao(CannaAIDatabase db) : super(db);

  Future<Plant?> getPlantById(int id, int userId) =>
    (select(plants)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<Plant>> getAllPlants(int userId) =>
    (select(plants)..where((tbl) => tbl.userId.equals(userId) & tbl.isActive.equals(true)))
      .get();

  Future<List<Plant>> getPlantsByRoom(int roomId, int userId) =>
    (select(plants)..where((tbl) => tbl.roomId.equals(roomId) &
                             tbl.userId.equals(userId) &
                             tbl.isActive.equals(true))).get();

  Future<List<Plant>> getPlantsByStrain(int strainId, int userId) =>
    (select(plants)..where((tbl) => tbl.strainId.equals(strainId) &
                             tbl.userId.equals(userId) &
                             tbl.isActive.equals(true))).get();

  Future<List<Plant>> getPlantsByGrowthStage(String growthStage, int userId) =>
    (select(plants)..where((tbl) => tbl.growthStage.equals(growthStage) &
                             tbl.userId.equals(userId) &
                             tbl.isActive.equals(true))).get();

  Future<List<Plant>> getPlantsByHealthStatus(String healthStatus, int userId) =>
    (select(plants)..where((tbl) => tbl.healthStatus.equals(healthStatus) &
                             tbl.userId.equals(userId) &
                             tbl.isActive.equals(true))).get();

  Future<List<Plant>> getMotherPlants(int userId) =>
    (select(plants)..where((tbl) => tbl.isMotherPlant.equals(true) &
                             tbl.userId.equals(userId) &
                             tbl.isActive.equals(true))).get();

  Future<int> createPlant(PlantsCompanion plant) => into(plants).insert(plant);

  Future<bool> updatePlant(Plant plant) => update(plants).replace(plant);

  Future<int> deletePlant(int id, int userId) =>
    (update(plants)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(PlantsCompanion(isActive: const Value(false)));

  Future<int> updatePlantGrowthStage(int id, int userId, String growthStage) =>
    (update(plants)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(PlantsCompanion(growthStage: Value(growthStage)));

  Future<int> updatePlantHealthStatus(int id, int userId, String healthStatus) =>
    (update(plants)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(PlantsCompanion(healthStatus: Value(healthStatus)));

  Future<int> updatePlantMeasurements(int id, int userId, {
    double? height,
    double? weight,
    double? temperature,
    double? humidity,
    double? ph,
    double? ec,
    double? lightIntensity,
  }) {
    final updates = <Column, dynamic>{};
    if (height != null) updates[plants.height] = height;
    if (weight != null) updates[plants.weight] = weight;
    if (temperature != null) updates[plants.temperature] = temperature;
    if (humidity != null) updates[plants.humidity] = humidity;
    if (ph != null) updates[plants.ph] = ph;
    if (ec != null) updates[plants.ec] = ec;
    if (lightIntensity != null) updates[plants.lightIntensity] = lightIntensity;

    return (update(plants)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(PlantsCompanion.custom(
        height: height != null ? Value(height) : const Value.absent(),
        weight: weight != null ? Value(weight) : const Value.absent(),
        temperature: temperature != null ? Value(temperature) : const Value.absent(),
        humidity: humidity != null ? Value(humidity) : const Value.absent(),
        ph: ph != null ? Value(ph) : const Value.absent(),
        ec: ec != null ? Value(ec) : const Value.absent(),
        lightIntensity: lightIntensity != null ? Value(lightIntensity) : const Value.absent(),
      ));
  }

  Future<int> incrementWateringCount(int id, int userId) =>
    customUpdate('UPDATE plants SET watering_count = watering_count + 1, '
                 'last_watering_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ?',
                 variables: [Variable.withInt(id), Variable.withInt(userId)]);

  Future<int> incrementFeedingCount(int id, int userId) =>
    customUpdate('UPDATE plants SET feeding_count = feeding_count + 1, '
                 'last_feeding_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ?',
                 variables: [Variable.withInt(id), Variable.withInt(userId)]);
}

// Sensor Device DAO
@DriftAccessor(tables: [SensorDevices])
class SensorDeviceDao extends DatabaseAccessor<CannaAIDatabase> with _$SensorDeviceDaoMixin {
  SensorDeviceDao(CannaAIDatabase db) : super(db);

  Future<SensorDevice?> getDeviceById(int id, int userId) =>
    (select(sensorDevices)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<SensorDevice?> getDeviceByDeviceId(String deviceId, int userId) =>
    (select(sensorDevices)..where((tbl) => tbl.deviceId.equals(deviceId) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<SensorDevice>> getAllDevices(int userId) =>
    (select(sensorDevices)..where((tbl) => tbl.userId.equals(userId) & tbl.isActive.equals(true)))
      .get();

  Future<List<SensorDevice>> getDevicesByRoom(int roomId, int userId) =>
    (select(sensorDevices)..where((tbl) => tbl.roomId.equals(roomId) &
                                    tbl.userId.equals(userId) &
                                    tbl.isActive.equals(true))).get();

  Future<List<SensorDevice>> getDevicesByType(String type, int userId) =>
    (select(sensorDevices)..where((tbl) => tbl.type.equals(type) &
                                    tbl.userId.equals(userId) &
                                    tbl.isActive.equals(true))).get();

  Future<List<SensorDevice>> getOnlineDevices(int userId) =>
    (select(sensorDevices)..where((tbl) => tbl.isOnline.equals(true) &
                                    tbl.userId.equals(userId) &
                                    tbl.isActive.equals(true))).get();

  Future<int> createDevice(SensorDevicesCompanion device) => into(sensorDevices).insert(device);

  Future<bool> updateDevice(SensorDevice device) => update(sensorDevices).replace(device);

  Future<int> deleteDevice(int id, int userId) =>
    (update(sensorDevices)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(SensorDevicesCompanion(isActive: const Value(false)));

  Future<int> updateDeviceStatus(int id, int userId, {
    bool? isOnline,
    int? batteryLevel,
    DateTime? lastSeenAt,
  }) {
    final updates = <Column, dynamic>{};
    if (isOnline != null) updates[sensorDevices.isOnline] = isOnline;
    if (batteryLevel != null) updates[sensorDevices.batteryLevel] = batteryLevel;
    if (lastSeenAt != null) updates[sensorDevices.lastSeenAt] = lastSeenAt;

    return (update(sensorDevices)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(SensorDevicesCompanion.custom(
        isOnline: isOnline != null ? Value(isOnline) : const Value.absent(),
        batteryLevel: batteryLevel != null ? Value(batteryLevel) : const Value.absent(),
        lastSeenAt: lastSeenAt != null ? Value(lastSeenAt) : const Value.absent(),
      ));
  }

  Future<bool> deviceIdExists(String deviceId, int userId) async {
    final result = await (selectOnly(sensorDevices)
      ..addColumns([sensorDevices.id])
      ..where((tbl) => tbl.deviceId.equals(deviceId) &
                      tbl.userId.equals(userId) &
                      tbl.isActive.equals(true)))
      .get();
    return result.isNotEmpty;
  }
}

// Sensor Reading DAO
@DriftAccessor(tables: [SensorReadings])
class SensorReadingDao extends DatabaseAccessor<CannaAIDatabase> with _$SensorReadingDaoMixin {
  SensorReadingDao(CannaAIDatabase db) : super(db);

  Future<SensorReading?> getReadingById(int id, int userId) =>
    (select(sensorReadings)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<SensorReading>> getReadingsByDevice(int deviceId, int userId, {int limit = 100}) =>
    (select(sensorReadings)
      ..where((tbl) => tbl.deviceId.equals(deviceId) & tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)])
      ..limit(limit))
      .get();

  Future<List<SensorReading>> getReadingsByTimeRange(
    int deviceId,
    int userId,
    DateTime startTime,
    DateTime endTime,
  ) =>
    (select(sensorReadings)
      ..where((tbl) => tbl.deviceId.equals(deviceId) &
                      tbl.userId.equals(userId) &
                      tbl.timestamp.isBetweenValues(startTime, endTime)))
      .orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)])
      .get();

  Future<List<SensorReading>> getLatestReadingsForAllDevices(int userId) =>
    (select(sensorReadings)
      ..join([
        innerJoin(sensorDevices, sensorDevices.id.equalsExp(sensorReadings.deviceId)),
      ])
      ..where(sensorDevices.userId.equals(userId) &
              sensorDevices.isActive.equals(true) &
              sensorReadings.userId.equals(userId))
      ..orderBy([(sensorReadings) => OrderingTerm.desc(sensorReadings.timestamp)])
      ..limit(100))
      .get();

  Future<int> createReading(SensorReadingsCompanion reading) => into(sensorReadings).insert(reading);

  Future<int> deleteOldReadings(DateTime cutoffDate, int userId) =>
    (delete(sensorReadings)..where((tbl) => tbl.timestamp.isSmallerThanValue(cutoffDate) &
                                           tbl.userId.equals(userId)))
      .go();

  Future<SensorReading?> getLatestReading(int deviceId, int userId) =>
    (select(sensorReadings)
      ..where((tbl) => tbl.deviceId.equals(deviceId) & tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)])
      ..limit(1))
      .getSingleOrNull();

  Future<double?> getAverageReading(int deviceId, int userId, DateTime startTime, DateTime endTime) async {
    final result = await customSelect('''
      SELECT AVG(value) as avg_value
      FROM sensor_readings
      WHERE device_id = ? AND user_id = ? AND timestamp BETWEEN ? AND ?
    ''', variables: [
      Variable.withInt(deviceId),
      Variable.withInt(userId),
      Variable.withDateTime(startTime),
      Variable.withDateTime(endTime),
    ]).getSingle();

    return result.read<double>('avg_value');
  }
}

// Automation Rule DAO
@DriftAccessor(tables: [AutomationRules])
class AutomationRuleDao extends DatabaseAccessor<CannaAIDatabase> with _$AutomationRuleDaoMixin {
  AutomationRuleDao(CannaAIDatabase db) : super(db);

  Future<AutomationRule?> getRuleById(int id, int userId) =>
    (select(automationRules)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<AutomationRule>> getAllRules(int userId) =>
    (select(automationRules)..where((tbl) => tbl.userId.equals(userId) & tbl.isActive.equals(true)))
      .get();

  Future<List<AutomationRule>> getRulesByRoom(int roomId, int userId) =>
    (select(automationRules)..where((tbl) => tbl.roomId.equals(roomId) &
                                      tbl.userId.equals(userId) &
                                      tbl.isActive.equals(true))).get();

  Future<List<AutomationRule>> getRulesByDevice(int deviceId, int userId) =>
    (select(automationRules)..where((tbl) => tbl.deviceId.equals(deviceId) &
                                      tbl.userId.equals(userId) &
                                      tbl.isActive.equals(true))).get();

  Future<List<AutomationRule>> getRulesByTriggerType(String triggerType, int userId) =>
    (select(automationRules)..where((tbl) => tbl.triggerType.equals(triggerType) &
                                      tbl.userId.equals(userId) &
                                      tbl.isActive.equals(true))).get();

  Future<List<AutomationRule>> getRulesToExecute(DateTime currentTime, int userId) =>
    (select(automationRules)..where((tbl) => tbl.isActive.equals(true) &
                                      tbl.userId.equals(userId) &
                                      tbl.nextExecutionAt.isSmallerThanValue(currentTime)))
      .orderBy([(tbl) => OrderingTerm.asc(tbl.priority))])
      .get();

  Future<int> createRule(AutomationRulesCompanion rule) => into(automationRules).insert(rule);

  Future<bool> updateRule(AutomationRule rule) => update(automationRules).replace(rule);

  Future<int> deleteRule(int id, int userId) =>
    (update(automationRules)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(AutomationRulesCompanion(isActive: const Value(false)));

  Future<int> updateRuleExecution(int id, int userId, DateTime nextExecution) =>
    (update(automationRules)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .write(AutomationRulesCompanion(
        lastExecutedAt: Value(DateTime.now()),
        nextExecutionAt: Value(nextExecution),
        executionCount: automationRules.executionCount + 1,
      ));
}

// Plant Analysis DAO
@DriftAccessor(tables: [PlantAnalysis])
class PlantAnalysisDao extends DatabaseAccessor<CannaAIDatabase> with _$PlantAnalysisDaoMixin {
  PlantAnalysisDao(CannaAIDatabase db) : super(db);

  Future<PlantAnalysis?> getAnalysisById(int id, int userId) =>
    (select(plantAnalysis)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<PlantAnalysis>> getAnalysesByPlant(int plantId, int userId, {int limit = 50}) =>
    (select(plantAnalysis)
      ..where((tbl) => tbl.plantId.equals(plantId) & tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.analysisDate)])
      ..limit(limit))
      .get();

  Future<List<PlantAnalysis>> getAnalysesByType(String analysisType, int userId, {int limit = 100}) =>
    (select(plantAnalysis)
      ..where((tbl) => tbl.analysisType.equals(analysisType) & tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.analysisDate)])
      ..limit(limit))
      .get();

  Future<List<PlantAnalysis>> getRecentAnalyses(int userId, {int limit = 20}) =>
    (select(plantAnalysis)
      ..where((tbl) => tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.analysisDate)])
      ..limit(limit))
      .get();

  Future<int> createAnalysis(PlantAnalysisCompanion analysis) => into(plantAnalysis).insert(analysis);

  Future<bool> updateAnalysis(PlantAnalysis analysis) => update(plantAnalysis).replace(analysis);

  Future<int> deleteAnalysis(int id, int userId) =>
    (delete(plantAnalysis)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId))).go();

  Future<PlantAnalysis?> getLatestAnalysis(int plantId, int userId) =>
    (select(plantAnalysis)
      ..where((tbl) => tbl.plantId.equals(plantId) & tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.analysisDate)])
      ..limit(1))
      .getSingleOrNull();

  Future<List<PlantAnalysis>> getLowHealthAnalyses(int userId, {double threshold = 50.0}) =>
    (select(plantAnalysis)
      ..where((tbl) => tbl.healthScore.isSmallerThanValue(threshold) &
                      tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.analysisDate)])
      ..limit(50))
      .get();
}

// Automation Log DAO
@DriftAccessor(tables: [AutomationLogs])
class AutomationLogDao extends DatabaseAccessor<CannaAIDatabase> with _$AutomationLogDaoMixin {
  AutomationLogDao(CannaAIDatabase db) : super(db);

  Future<AutomationLog?> getLogById(int id, int userId) =>
    (select(automationLogs)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<AutomationLog>> getLogsByRule(int ruleId, int userId, {int limit = 100}) =>
    (select(automationLogs)
      ..where((tbl) => tbl.ruleId.equals(ruleId) & tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.executionDate)])
      ..limit(limit))
      .get();

  Future<List<AutomationLog>> getLogsByStatus(String status, int userId, {int limit = 100}) =>
    (select(automationLogs)
      ..where((tbl) => tbl.status.equals(status) & tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.executionDate)])
      ..limit(limit))
      .get();

  Future<List<AutomationLog>> getLogsByTimeRange(
    DateTime startTime,
    DateTime endTime,
    int userId,
    {int limit = 200}
  ) =>
    (select(automationLogs)
      ..where((tbl) => tbl.executionDate.isBetweenValues(startTime, endTime) &
                      tbl.userId.equals(userId)))
      .orderBy([(tbl) => OrderingTerm.desc(tbl.executionDate)])
      ..limit(limit))
      .get();

  Future<List<AutomationLog>> getFailedLogs(int userId, {int limit = 50}) =>
    (select(automationLogs)
      ..where((tbl) => tbl.status.equals('failed') & tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.executionDate)])
      ..limit(limit))
      .get();

  Future<int> createLog(AutomationLogsCompanion log) => into(automationLogs).insert(log);

  Future<int> deleteOldLogs(DateTime cutoffDate, int userId) =>
    (delete(automationLogs)..where((tbl) => tbl.executionDate.isSmallerThanValue(cutoffDate) &
                                            tbl.userId.equals(userId)))
      .go();
}

// Plant Note DAO
@DriftAccessor(tables: [PlantNotes])
class PlantNoteDao extends DatabaseAccessor<CannaAIDatabase> with _$PlantNoteDaoMixin {
  PlantNoteDao(CannaAIDatabase db) : super(db);

  Future<PlantNote?> getNoteById(int id, int userId) =>
    (select(plantNotes)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<PlantNote>> getNotesByPlant(int plantId, int userId, {int limit = 100}) =>
    (select(plantNotes)
      ..where((tbl) => tbl.plantId.equals(plantId) & tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.noteDate)])
      ..limit(limit))
      .get();

  Future<List<PlantNote>> getNotesByType(String type, int userId, {int limit = 100}) =>
    (select(plantNotes)
      ..where((tbl) => tbl.type.equals(type) & tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.noteDate)])
      ..limit(limit))
      .get();

  Future<List<PlantNote>> getRecentNotes(int userId, {int limit = 50}) =>
    (select(plantNotes)
      ..where((tbl) => tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.noteDate)])
      ..limit(limit))
      .get();

  Future<int> createNote(PlantNotesCompanion note) => into(plantNotes).insert(note);

  Future<bool> updateNote(PlantNote note) => update(plantNotes).replace(note);

  Future<int> deleteNote(int id, int userId) =>
    (delete(plantNotes)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId))).go();
}

// App Setting DAO
@DriftAccessor(tables: [AppSettings])
class AppSettingDao extends DatabaseAccessor<CannaAIDatabase> with _$AppSettingDaoMixin {
  AppSettingDao(CannaAIDatabase db) : super(db);

  Future<AppSetting?> getSettingByKey(String key, int userId) =>
    (select(appSettings)..where((tbl) => tbl.key.equals(key) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<AppSetting>> getAllSettings(int userId) =>
    (select(appSettings)..where((tbl) => tbl.userId.equals(userId))).get();

  Future<List<AppSetting>> getSettingsByCategory(String category, int userId) =>
    (select(appSettings)..where((tbl) => tbl.category.equals(category) & tbl.userId.equals(userId)))
      .get();

  Future<int> createSetting(AppSettingsCompanion setting) => into(appSettings).insert(setting);

  Future<bool> updateSetting(AppSetting setting) => update(appSettings).replace(setting);

  Future<int> upsertSetting(String key, String value, int userId, {
    String type = 'string',
    String category = 'general',
    String? description,
    bool isEncrypted = false,
  }) {
    final setting = AppSettingsCompanion.insert(
      key: key,
      value: value,
      userId: userId,
      type: type,
      category: category,
      isEncrypted: isEncrypted,
    );

    return into(appSettings).insertOnConflictUpdate(setting);
  }

  Future<int> deleteSetting(String key, int userId) =>
    (delete(appSettings)..where((tbl) => tbl.key.equals(key) & tbl.userId.equals(userId))).go();

  Future<String?> getSettingValue(String key, int userId) async {
    final setting = await getSettingByKey(key, userId);
    return setting?.value;
  }

  Future<T?> getTypedSetting<T>(String key, int userId) async {
    final setting = await getSettingByKey(key, userId);
    if (setting == null) return null;

    switch (setting.type.toLowerCase()) {
      case 'boolean':
        return setting.value.toLowerCase() == 'true' as T?;
      case 'number':
        return double.tryParse(setting.value) as T?;
      case 'integer':
        return int.tryParse(setting.value) as T?;
      default:
        return setting.value as T?;
    }
  }
}

// Backup Log DAO
@DriftAccessor(tables: [BackupLogs])
class BackupLogDao extends DatabaseAccessor<CannaAIDatabase> with _$BackupLogDaoMixin {
  BackupLogDao(CannaAIDatabase db) : super(db);

  Future<BackupLog?> getBackupById(int id, int userId) =>
    (select(backupLogs)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
      .getSingleOrNull();

  Future<List<BackupLog>> getAllBackups(int userId) =>
    (select(backupLogs)..where((tbl) => tbl.userId.equals(userId)))
      .orderBy([(tbl) => OrderingTerm.desc(tbl.backupDate)])
      .get();

  Future<List<BackupLog>> getBackupsByType(String backupType, int userId) =>
    (select(backupLogs)
      ..where((tbl) => tbl.backupType.equals(backupType) & tbl.userId.equals(userId)))
      .orderBy([(tbl) => OrderingTerm.desc(tbl.backupDate)])
      .get();

  Future<BackupLog?> getLatestBackup(int userId) =>
    (select(backupLogs)
      ..where((tbl) => tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.backupDate)])
      ..limit(1))
      .getSingleOrNull();

  Future<int> createBackupLog(BackupLogsCompanion log) => into(backupLogs).insert(log);

  Future<bool> updateBackupLog(BackupLog log) => update(backupLogs).replace(log);

  Future<int> deleteBackup(int id, int userId) =>
    (delete(backupLogs)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId))).go();

  Future<int> deleteOldBackups(DateTime cutoffDate, int userId) =>
    (delete(backupLogs)..where((tbl) => tbl.backupDate.isSmallerThanValue(cutoffDate) &
                                        tbl.userId.equals(userId)))
      .go();
}