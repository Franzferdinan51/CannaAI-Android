# CannaAI Database Layer

A comprehensive, production-ready database layer for the CannaAI Flutter application using Drift (SQLite ORM). This database layer provides offline-first functionality, robust error handling, automated backups, and comprehensive testing capabilities.

## Architecture Overview

### Core Components

1. **Database Schema** (`tables.dart`)
   - 12 interconnected tables for cultivation management
   - Proper relationships, indexes, and constraints
   - Automatic timestamp triggers

2. **Database Class** (`database.dart`)
   - Main Drift database implementation
   - Migration strategies
   - Performance optimizations
   - Transaction helpers

3. **Data Access Objects** (`daos.dart`)
   - Type-safe CRUD operations for each entity
   - Complex queries and joins
   - Data validation and business logic

4. **Enhanced Models** (`models.dart`)
   - Rich model classes with validation
   - JSON serialization
   - Business logic and computed properties
   - Helper methods for UI integration

5. **Repository Pattern** (`repositories.dart`)
   - Abstraction layer over DAOs
   - Intelligent caching with SharedPreferences
   - Offline support and sync strategies
   - Error handling and recovery

6. **Database Service** (`database_service.dart`)
   - Central service orchestration
   - Automated backups and restores
   - Performance monitoring
   - Health checks and optimization

7. **Error Handling** (`database_error_handler.dart`)
   - Comprehensive error classification
   - Automatic recovery mechanisms
   - Health monitoring and alerts
   - Detailed error logging

8. **Testing Framework** (`database_test_utils.dart`)
   - Test data factories
   - Performance benchmarking
   - Assertion utilities
   - Stress testing tools

## Database Schema

### Tables Overview

| Table | Purpose | Key Features |
|-------|---------|--------------|
| `users` | User accounts and profiles | Authentication, preferences |
| `rooms` | Cultivation rooms/spaces | Environmental targets, monitoring |
| `strains` | Cannabis strain information | Growth characteristics, optimal conditions |
| `plants` | Individual plant tracking | Growth stages, health metrics, measurements |
| `sensor_devices` | IoT sensor management | Device calibration, connectivity |
| `sensor_readings` | Time-series sensor data | High-frequency data storage |
| `automation_rules` | Smart automation rules | Complex trigger/action systems |
| `plant_analysis` | AI-powered plant analysis | Health scoring, recommendations |
| `automation_logs` | Execution history | Performance tracking |
| `plant_notes` | Daily observations | Growth tracking, images |
| `app_settings` | Configuration management | User preferences, app settings |
| `backup_logs` | Backup tracking | Version control, integrity |

### Relationships

```
users (1:n) rooms
users (1:n) strains
users (1:n) plants
users (1:n) sensor_devices
users (1:n) automation_rules

rooms (1:n) plants
rooms (1:n) sensor_devices
rooms (1:n) automation_rules

strains (1:n) plants

plants (1:n) plant_analysis
plants (1:n) plant_notes

sensor_devices (1:n) sensor_readings
sensor_devices (1:n) automation_rules

automation_rules (1:n) automation_logs
```

## Usage Guide

### 1. Initialization

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'core/database/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final logger = Logger();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: CannaAIApp(),
    ),
  );
}
```

### 2. Database Service Initialization

```dart
final databaseService = await DatabaseService.getInstance(
  config: DatabaseConfig(
    enableQueryLogging: true,
    backupInterval: Duration(hours: 12),
    dataRetentionPeriod: Duration(days: 180),
  ),
  logger: Logger(),
);
```

### 3. Using Repositories

```dart
final plantRepository = ref.read(plantRepositoryProvider);

// Create a new plant
final plant = await plantRepository.create(
  PlantsCompanion.insert(
    name: 'Blue Dream #1',
    strainId: strainId,
    roomId: roomId,
    growthStage: 'vegetative',
    healthStatus: 'healthy',
    plantedDate: DateTime.now(),
    userId: userId,
  ),
);

// Get all plants for a user
final plants = await plantRepository.getAll(userId);

// Get plants by room
final roomPlants = await plantRepository.getByRoom(roomId, userId);

// Update plant measurements
await plantRepository.updateMeasurements(
  plantId,
  userId,
  height: 45.5,
  temperature: 22.3,
  humidity: 55.0,
);
```

### 4. Complex Queries with DAOs

```dart
final database = ref.read(databaseServiceProvider);

// Get plants with strain and room information
final result = await (database.select(database.plants)
  ..join([
    innerJoin(database.strains, database.strains.id.equalsExp(database.plants.strainId)),
    innerJoin(database.rooms, database.rooms.id.equalsExp(database.plants.roomId)),
  ])
  ..where(database.plants.userId.equals(userId))
  ..orderBy([(t) => OrderingTerm.desc(t.plants.createdAt)])
).get();
```

### 5. Working with Models

```dart
// Convert database entity to rich model
final plantModel = PlantModel(
  id: plant.id,
  name: plant.name,
  // ... other fields
);

// Use model helper methods
print('Plant age: ${plantModel.ageDisplay}');
print('Health status: ${plantModel.healthStatusDisplay}');
print('Growth progress: ${(plantModel.growthProgress * 100).toStringAsFixed(0)}%');

// Validation
final nameError = PlantModel.validateName(plantModel.name);
if (nameError != null) {
  // Handle validation error
}
```

### 6. Error Handling

```dart
final safeOperation = SafeDatabaseOperation(errorHandler);

final result = await safeOperation.execute(
  'create_plant',
  () async {
    return await plantRepository.create(plantData);
  },
  tableName: 'plants',
  fallbackValue: null,
);
```

### 7. Database Operations

```dart
// Create backup
final backup = await databaseService.createBackup('manual');

// Restore from backup
await databaseService.restoreFromBackup(backup.filePath);

// Optimize database
await databaseService.optimizeDatabase();

// Get health report
final health = await databaseService.performHealthCheck();
print('Database health: ${health['health_score']}%');

// Export data
final exportData = await databaseService.exportData(userId: userId);
```

## Performance Optimization

### 1. Indexes

The database includes strategic indexes for optimal query performance:

```sql
-- Room-based queries
CREATE INDEX idx_plants_room_id ON plants (room_id);

-- Time-series data
CREATE INDEX idx_sensor_readings_timestamp ON sensor_readings (timestamp);

-- User data isolation
CREATE INDEX idx_plants_user_id ON plants (user_id);
```

### 2. Caching Strategy

- **Memory Cache**: In-memory caching for frequently accessed data
- **SharedPreferences Cache**: Persistent cache for app session
- **Cache Timeout**: 5-minute default with configurable intervals
- **Smart Invalidation**: Automatic cache clearing on data changes

### 3. Query Optimization

```dart
// Use specific columns instead of SELECT *
final result = await (database.select(database.plants)
  ..addColumns([database.plants.id, database.plants.name])
  ..where(database.plants.userId.equals(userId))).get();

// Use limits for large datasets
final recentPlants = await (database.select(database.plants)
  ..where(database.plants.userId.equals(userId))
  ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
  ..limit(20)).get();
```

## Testing

### 1. Unit Tests

```dart
test('should create plant successfully', () async {
  final plantData = TestDataFactory.createTestPlant(
    name: 'Test Plant',
    userId: 1,
  );

  final plantId = await testDatabase.into(testDatabase.plants).insert(plantData);
  expect(plantId, isPositive);
});
```

### 2. Integration Tests

```dart
test('should perform complex plant analysis workflow', () async {
  // Setup test data
  final dataset = await TestDataFactory.createCompleteDataset(testDatabase);

  // Test workflow
  final analysis = await databaseService.repositories.plantAnalysis.create(
    PlantAnalysisCompanion.insert(
      plantId: dataset.plants.first,
      healthScore: 85.0,
      confidence: 0.9,
      userId: dataset.users.first,
    ),
  );

  expect(analysis.id, isPositive);
});
```

### 3. Performance Tests

```dart
test('should handle high-frequency sensor data', () async {
  await PerformanceTestUtils.stressTestInserts(testDatabase, 1000);

  final benchmark = await PerformanceTestUtils.benchmarkQueries(testDatabase);
  expect(benchmark['select_all_plants']!.inMilliseconds, lessThan(100));
});
```

## Configuration

### Database Config

```dart
final config = DatabaseConfig(
  databaseName: 'cannai.db',
  enableForeignKeys: true,
  enableWALMode: true,
  cacheSize: 10000,
  busyTimeout: Duration(seconds: 30),
  enableQueryLogging: true,
  backupInterval: Duration(hours: 12),
  maxBackupFiles: 5,
  dataRetentionPeriod: Duration(days: 365),
);
```

### Logger Config

```dart
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);
```

## Monitoring and Maintenance

### 1. Health Monitoring

```dart
// Regular health checks
final health = await databaseService.performHealthCheck();
if (health['health_score'] < 70) {
  // Send alert to user
  _showHealthWarning(health);
}
```

### 2. Performance Monitoring

```dart
// Query performance metrics
final metrics = databaseService.getQueryMetrics();
metrics.forEach((queryType, stats) {
  if (stats['average'] > 1000) { // 1 second
    // Log performance warning
    logger.w('Slow query detected: $queryType');
  }
});
```

### 3. Error Monitoring

```dart
// Error rate monitoring
final errorRate = errorHandler.getErrorRate();
if (errorRate > 10) { // More than 10 errors per hour
  // Send notification
  _notifyHighErrorRate(errorRate);
}
```

## Best Practices

### 1. Database Operations

- **Use transactions** for multi-table operations
- **Batch operations** for bulk inserts/updates
- **Use specific columns** instead of SELECT *
- **Implement proper error handling** for all operations
- **Cache frequently accessed data** appropriately

### 2. Data Modeling

- **Validate data** before database operations
- **Use appropriate data types** for efficiency
- **Implement business logic** in model classes
- **Use enums** for status fields
- **Document relationships** clearly

### 3. Performance

- **Monitor query performance** regularly
- **Optimize indexes** based on query patterns
- **Use connection pooling** for high-load scenarios
- **Implement proper caching** strategies
- **Archive old data** regularly

### 4. Security

- **Use parameterized queries** to prevent SQL injection
- **Implement proper user isolation** with user_id
- **Validate input data** before database operations
- **Use transactions** for data consistency
- **Implement proper backup** strategies

## Troubleshooting

### Common Issues

1. **Database Lock Errors**
   ```dart
   // Implement retry logic with exponential backoff
   final result = await safeOperation.executeWithRetry(
     'operation_name',
     () => riskyDatabaseOperation(),
     maxRetries: 3,
     delay: Duration(milliseconds: 100),
   );
   ```

2. **Memory Issues**
   ```dart
   // Use streaming for large datasets
   final stream = database.select(database.sensorReadings)
     .where((tbl) => tbl.timestamp.isBiggerThanValue(cutoff))
     .watch();
   ```

3. **Performance Issues**
   ```dart
   // Analyze slow queries
   final metrics = databaseService.getQueryMetrics();
   final slowQueries = metrics.entries
     .where((entry) => entry.value['average'] > 1000);
   ```

### Debug Mode

Enable detailed logging for debugging:

```dart
final config = DatabaseConfig(
  enableQueryLogging: true,
  // ... other config
);
```

This will log all SQL queries with execution times for performance analysis.

## Migration Guide

### Version 1 to Version 2

```dart
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Add new column
        await m.addColumn(plants, plants.newField);

        // Update existing data
        await customUpdate('UPDATE plants SET new_field = ? WHERE new_field IS NULL',
                         variables: [Variable.withString('default_value')]);
      }
    },
  );
}
```

## Contributing

When contributing to the database layer:

1. **Write tests** for all new functionality
2. **Update documentation** for schema changes
3. **Consider performance** implications
4. **Handle errors** gracefully
5. **Maintain backward compatibility** when possible

## License

This database layer is part of the CannaAI project and follows the same licensing terms.