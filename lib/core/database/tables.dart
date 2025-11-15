import 'package:drift/drift.dart';

// Users table - manages user accounts and profiles
@DataClassName('User')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get email => text().unique()();
  TextColumn get username => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get displayName => text()();
  TextColumn get avatarUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();
  BooleanColumn get isActive => boolean().withDefault(const Constant(true))();
  BooleanColumn get isAdmin => boolean().withDefault(const Constant(false))();
  TextColumn get preferences => text().nullable()(); // JSON for user preferences
}

// Rooms table - manages cultivation rooms/spaces
@DataClassName('Room')
class Rooms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get roomType => text().withDefault(const Constant('general'))(); // vegetative, flowering, drying, etc.
  RealColumn get size => real()(); // Room size in square meters/feet
  RealColumn get targetTemperature => real().withDefault(const Constant(22.0))();
  RealColumn get targetHumidity => real().withDefault(const Constant(50.0))();
  RealColumn get targetPh => real().withDefault(const Constant(6.0))();
  RealColumn get targetEc => real().withDefault(const Constant(1.5))();
  BooleanColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id, userId};
}

// Strains table - cannabis strain information
@DataClassName('Strain')
class Strains extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get breeder => text().nullable()();
  TextColumn get genetics => text().nullable()();
  TextColumn get type => text()(); // indica, sativa, hybrid, ruderalis
  TextColumn get thcLevel => text().nullable()();
  TextColumn get cbdLevel => text().nullable()();
  TextColumn get floweringTime => text().nullable()();
  TextColumn get yield => text().nullable()();
  TextColumn get difficulty => text().withDefault(const Constant('medium'))();
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get flavorProfile => text().nullable()();
  TextColumn get effects => text().nullable()();
  TextColumn get medicalUses => text().nullable()();
  TextColumn get growthCharacteristics => text().nullable()();
  RealColumn get optimalTemperature => real().nullable()();
  RealColumn get optimalHumidity => real().nullable()();
  RealColumn get optimalPh => real().nullable()();
  BooleanColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id, userId};
}

// Plants table - individual plant tracking
@DataClassName('Plant')
class Plants extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get strainId => integer().references(Strains, #id)();
  IntColumn get roomId => integer().references(Rooms, #id)();
  TextColumn get growthStage => text().withDefault(const Constant('seedling'))(); // seedling, vegetative, flowering, harvesting
  TextColumn get healthStatus => text().withDefault(const Constant('healthy'))(); // healthy, warning, critical
  DateTimeColumn get plantedDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expectedHarvestDate => dateTime().nullable()();
  DateTimeColumn get actualHarvestDate => dateTime().nullable()();
  RealColumn get height => real().nullable()(); // in cm
  RealColumn get weight => real().nullable()(); // in grams
  TextColumn get gender => text().nullable()(); // male, female, hermaphrodite
  TextColumn get phenotype => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  RealColumn get temperature => real().nullable()();
  RealColumn get humidity => real().nullable()();
  RealColumn get ph => real().nullable()();
  RealColumn get ec => real().nullable()();
  RealColumn get lightIntensity => real().nullable()();
  IntColumn get wateringCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastWateringAt => dateTime().nullable()();
  IntColumn get feedingCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastFeedingAt => dateTime().nullable()();
  BooleanColumn get isActive => boolean().withDefault(const Constant(true))();
  BooleanColumn get isMotherPlant => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id, userId};
}

// Sensor devices table
@DataClassName('SensorDevice')
class SensorDevices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text().unique()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // temperature, humidity, ph, ec, light, co2, etc.
  TextColumn get manufacturer => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get firmwareVersion => text().nullable()();
  TextColumn get bluetoothAddress => text().nullable()();
  TextColumn get wifiAddress => text().nullable()();
  RealColumn get calibrationOffset => real().withDefault(const Constant(0.0))();
  RealColumn get calibrationScale => real().withDefault(const Constant(1.0))();
  TextColumn get unit => text().withDefault(const Constant('standard'))(); // metric, imperial
  RealColumn get minReading => real().nullable()();
  RealColumn get maxReading => real().nullable()();
  IntColumn get batteryLevel => integer().nullable()();
  BooleanColumn get isOnline => boolean().withDefault(const Constant(false))();
  BooleanColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  DateTimeColumn get lastCalibrationAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get roomId => integer().references(Rooms, #id).nullable()();
  IntColumn get userId => integer().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id, userId};
}

// Sensor readings table
@DataClassName('SensorReading')
class SensorReadings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deviceId => integer().references(SensorDevices, #id)();
  RealColumn get value => real()();
  TextColumn get unit => text()();
  TextColumn get quality => text().withDefault(const Constant('good'))(); // good, poor, error
  TextColumn get notes => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id, userId};
}

// Automation rules table
@DataClassName('AutomationRule')
class AutomationRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get triggerType => text()(); // time, sensor_threshold, manual
  TextColumn get triggerCondition => text()(); // JSON for trigger conditions
  TextColumn get actionType => text()(); // watering, lighting, climate, notification
  TextColumn get actionParameters => text()(); // JSON for action parameters
  BooleanColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastExecutedAt => dateTime().nullable()();
  DateTimeColumn get nextExecutionAt => dateTime().nullable()();
  IntColumn get executionCount => integer().withDefault(const Constant(0))();
  TextColumn get schedule => text().nullable()(); // Cron expression or simple schedule
  IntColumn get priority => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get roomId => integer().references(Rooms, #id).nullable()();
  IntColumn get deviceId => integer().references(SensorDevices, #id).nullable()();
  IntColumn get userId => integer().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id, userId};
}

// Plant analysis history table
@DataClassName('PlantAnalysis')
class PlantAnalysis extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get plantId => integer().references(Plants, #id)();
  TextColumn get analysisType => text()(); // health, growth, pest, nutrient, etc.
  TextColumn get symptoms => text().nullable()(); // JSON array of detected symptoms
  RealColumn get healthScore => real()(); // 0-100 health score
  RealColumn get confidence => real()(); // 0-1 confidence level
  TextColumn get diagnosis => text().nullable()();
  TextColumn get recommendations => text().nullable()(); // JSON array of recommendations
  TextColumn get imageUrl => text().nullable()();
  TextColumn get imageAnalysisData => text().nullable()(); // JSON for detailed image analysis
  RealColumn get temperature => real().nullable()();
  RealColumn get humidity => real().nullable()();
  RealColumn get ph => real().nullable()();
  RealColumn get ec => real().nullable()();
  RealColumn get lightIntensity => real().nullable()();
  RealColumn get co2Level => real().nullable()();
  TextColumn get environmentalConditions => text().nullable()(); // JSON for environment snapshot
  TextColumn get notes => text().nullable()();
  DateTimeColumn get analysisDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id, userId};
}

// Automation execution log table
@DataClassName('AutomationLog')
class AutomationLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ruleId => integer().references(AutomationRules, #id)();
  TextColumn get actionType => text()();
  TextColumn get actionParameters => text()(); // JSON
  TextColumn get status => text()(); // success, failed, partial
  TextColumn get errorMessage => text().nullable()();
  TextColumn get result => text().nullable()(); // JSON for execution result
  DateTimeColumn get executionDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get duration => real().nullable()(); // Execution time in seconds
  TextColumn get notes => text().nullable()();
  IntColumn get userId => integer().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id, userId};
}

// Plant notes table for daily observations
@DataClassName('PlantNote')
class PlantNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get plantId => integer().references(Plants, #id)();
  TextColumn get note => text()();
  TextColumn get type => text().withDefault(const Constant('general'))(); // watering, feeding, observation, maintenance
  TextColumn get images => text().nullable()(); // JSON array of image URLs
  RealColumn get temperature => real().nullable()();
  RealColumn get humidity => real().nullable()();
  RealColumn get ph => real().nullable()();
  RealColumn get ec => real().nullable()();
  RealColumn get waterAmount => real().nullable()(); // in ml
  TextColumn get nutrients => text().nullable()(); // JSON for nutrient mix
  TextColumn get actions => text().nullable()(); // JSON for actions taken
  DateTimeColumn get noteDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id, userId};
}

// Settings table for app configuration
@DataClassName('AppSetting')
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
  TextColumn get type => text().withDefault(const Constant('string'))(); // string, number, boolean, json
  TextColumn get category => text().withDefault(const Constant('general'))();
  TextColumn get description => text().nullable()();
  BooleanColumn get isEncrypted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id, userId};
}

// Backup logs table
@DataClassName('BackupLog')
class BackupLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get backupType => text()(); // full, incremental, manual, auto
  TextColumn get filePath => text()();
  IntColumn get fileSize => integer()(); // in bytes
  IntColumn get recordCount => integer()(); // number of records backed up
  TextColumn get status => text()(); // success, failed, partial
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get backupDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get restoreDate => dateTime().nullable()();
  TextColumn get checksum => text().nullable()(); // backup file checksum
  TextColumn get version => text()(); // app/database version
  IntColumn get userId => integer().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id, userId};
}