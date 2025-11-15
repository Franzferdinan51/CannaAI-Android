import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';

// Logger provider
final loggerProvider = Provider<Logger>((ref) {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );
});

// SharedPreferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be provided in main()');
});

// Database configuration provider
final databaseConfigProvider = Provider<DatabaseConfig>((ref) {
  return const DatabaseConfig(
    enableForeignKeys: true,
    enableWALMode: true,
    cacheSize: 10000,
    busyTimeout: Duration(seconds: 30),
    enableQueryLogging: true,
    backupInterval: Duration(hours: 12), // More frequent for mobile
    maxBackupFiles: 3, // Limited storage on mobile
    dataRetentionPeriod: Duration(days: 180), // Shorter retention for mobile
  );
});

// Database service provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('DatabaseService must be initialized in main()');
});

// Async database service provider for initialization
final asyncDatabaseServiceProvider = FutureProvider<DatabaseService>((ref) async {
  final logger = ref.watch(loggerProvider);
  final config = ref.watch(databaseConfigProvider);

  return await DatabaseService.getInstance(
    config: config,
    logger: logger,
  );
});

// Repository factory provider
final repositoryFactoryProvider = Provider<RepositoryFactory>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.repositories;
});

// Individual repository providers
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final repositories = ref.watch(repositoryFactoryProvider);
  return repositories.users;
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  final repositories = ref.watch(repositoryFactoryProvider);
  return repositories.rooms;
});

final plantRepositoryProvider = Provider<PlantRepository>((ref) {
  final repositories = ref.watch(repositoryFactoryProvider);
  return repositories.plants;
});

final sensorDeviceRepositoryProvider = Provider<SensorDeviceRepository>((ref) {
  final repositories = ref.watch(repositoryFactoryProvider);
  return repositories.sensorDevices;
});

// Database health status provider
final databaseHealthProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.performHealthCheck();
});

// Database statistics provider
final databaseStatsProvider = FutureProvider<DatabaseStats>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getDatabaseStats();
});

// Database initialization status provider
final databaseInitializationStatusProvider = Provider<bool>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.isInitialized;
});

// Database performance metrics provider
final databasePerformanceProvider = Provider<Map<String, Map<String, dynamic>>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getQueryMetrics();
});

// Backup functionality providers
final createBackupProvider = FutureProvider.family<BackupInfo, String>((ref, backupType) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.createBackup(backupType);
});

// Export data provider
final exportDataProvider = FutureProvider.family<Map<String, dynamic>, int?>((ref, userId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.exportData(userId: userId);
});

// Database optimization provider
final optimizeDatabaseProvider = FutureProvider<void>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  await databaseService.optimizeDatabase();
});

// Clear caches provider
final clearAllCachesProvider = FutureProvider.family<void, int>((ref, userId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  await databaseService.clearAllCaches(userId);
});

// Database reset provider (use with caution)
final resetDatabaseProvider = FutureProvider<void>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  await databaseService.resetDatabase();
});

// Auto-refresh providers (for periodic updates)
final autoRefreshDatabaseStatsProvider = StreamProvider<DatabaseStats>((ref) async* {
  final databaseService = ref.watch(databaseServiceProvider);

  // Initial stats
  yield await databaseService.getDatabaseStats();

  // Update every 30 seconds
  ref.onListen(() {
    final timer = Stream.periodic(const Duration(seconds: 30), (_) async* {
      yield await databaseService.getDatabaseStats();
    });

    ref.onCancel(() {
      // Cleanup if needed
    });

    return timer;
  });
});

// Auto-refresh health check provider
final autoRefreshHealthProvider = StreamProvider<Map<String, dynamic>>((ref) async* {
  final databaseService = ref.watch(databaseServiceProvider);

  // Initial health check
  yield await databaseService.performHealthCheck();

  // Update every 5 minutes
  ref.onListen(() {
    final timer = Stream.periodic(const Duration(minutes: 5), (_) async* {
      yield await databaseService.performHealthCheck();
    });

    ref.onCancel(() {
      // Cleanup if needed
    });

    return timer;
  });
});