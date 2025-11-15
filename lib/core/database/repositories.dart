import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import 'database.dart';
import 'models.dart';

// Base repository with common functionality
abstract class BaseRepository<T, TInsert, TUpdate> {
  final CannaAIDatabase _database;
  final Logger _logger;
  final SharedPreferences _prefs;
  final String _cachePrefix;
  final Duration _cacheTimeout;

  BaseRepository(
    this._database,
    this._logger,
    this._prefs, {
    required String cachePrefix,
    Duration cacheTimeout = const Duration(minutes: 5),
  }) : _cachePrefix = cachePrefix,
       _cacheTimeout = cacheTimeout;

  // Abstract methods to be implemented by specific repositories
  Future<T?> getById(int id, int userId);
  Future<List<T>> getAll(int userId);
  Future<int> create(TInsert entity);
  Future<bool> update(T entity);
  Future<int> delete(int id, int userId);

  // Cache helpers
  String _getCacheKey(String key, int userId) => '${_cachePrefix}_$key\_$userId';

  Future<void> _setCache(String key, dynamic data, int userId) async {
    try {
      final cacheData = {
        'data': data is List ? data.map((e) => e.toJson()).toList() : data.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await _prefs.setString(_getCacheKey(key, userId), json.encode(cacheData));
    } catch (e) {
      _logger.w('Failed to set cache for key $key: $e');
    }
  }

  Future<T?> _getCache<T>(String key, int userId) async {
    try {
      final cachedData = _prefs.getString(_getCacheKey(key, userId));
      if (cachedData == null) return null;

      final cache = json.decode(cachedData) as Map<String, dynamic>;
      final timestamp = cache['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - timestamp > _cacheTimeout.inMilliseconds) {
        await _clearCache(key, userId);
        return null;
      }

      return cache['data'] as T?;
    } catch (e) {
      _logger.w('Failed to get cache for key $key: $e');
      return null;
    }
  }

  Future<void> _clearCache(String key, int userId) async {
    try {
      await _prefs.remove(_getCacheKey(key, userId));
    } catch (e) {
      _logger.w('Failed to clear cache for key $key: $e');
    }
  }

  Future<void> clearAllCache(int userId) async {
    try {
      final keys = _prefs.getKeys().where((key) => key.startsWith('${_cachePrefix}_') && key.endsWith('_$userId'));
      for (final key in keys) {
        await _prefs.remove(key);
      }
    } catch (e) {
      _logger.w('Failed to clear all cache: $e');
    }
  }

  // Safe database operation with error handling
  Future<R> safeOperation<R>(
    String operation,
    Future<R> Function() action, {
    int? userId,
  }) async {
    try {
      _logger.d('Starting $operation');
      final result = await action();
      _logger.d('Completed $operation successfully');

      // Clear relevant cache after successful operation
      if (userId != null) {
        await clearAllCache(userId);
      }

      return result;
    } catch (e, stackTrace) {
      _logger.e('Failed $operation: $e', error: e, stackTrace: stackTrace);
      throw RepositoryException('Failed to $operation', originalError: e);
    }
  }

  // Transaction helper
  Future<R> transaction<R>(Future<R> Function(Transaction txn) action) async {
    try {
      return await _database.transaction(action);
    } catch (e) {
      _logger.e('Transaction failed: $e');
      throw RepositoryException('Transaction failed', originalError: e);
    }
  }
}

// Repository exception
class RepositoryException implements Exception {
  final String message;
  final dynamic originalError;
  final String? operation;

  RepositoryException(this.message, {this.originalError, this.operation});

  @override
  String toString() {
    final buffer = StringBuffer('RepositoryException: $message');
    if (operation != null) buffer.write(' (operation: $operation)');
    if (originalError != null) buffer.write(' (original error: $originalError)');
    return buffer.toString();
  }
}

// User Repository
class UserRepository extends BaseRepository<UserModel, UsersCompanion, UserModel> {
  late final UserDao _dao;

  UserRepository(CannaAIDatabase database, Logger logger, SharedPreferences prefs)
      : super(database, logger, prefs, cachePrefix: 'user') {
    _dao = database.userDao;
  }

  @override
  Future<UserModel?> getById(int id, int userId) async {
    final cacheKey = 'user_$id';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return UserModel.fromJson(cached as Map<String, dynamic>);
    }

    return await safeOperation('get user by id', () async {
      final user = await _dao.getUserById(id, userId);
      if (user == null) return null;

      final model = _convertToModel(user);
      await _setCache(cacheKey, model, userId);
      return model;
    });
  }

  Future<UserModel?> getByEmail(String email, int userId) async {
    final cacheKey = 'user_email_$email';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return UserModel.fromJson(cached as Map<String, dynamic>);
    }

    return await safeOperation('get user by email', () async {
      final user = await _dao.getUserByEmail(email, userId);
      if (user == null) return null;

      final model = _convertToModel(user);
      await _setCache(cacheKey, model, userId);
      return model;
    });
  }

  @override
  Future<List<UserModel>> getAll(int userId) async {
    const cacheKey = 'all_users';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get all users', () async {
      final users = await _dao.getAllUsers(userId);
      final models = users.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  @override
  Future<int> create(UsersCompanion user) async {
    return await safeOperation('create user', () async {
      return await _dao.createUser(user);
    }, userId: user.userId.value);
  }

  @override
  Future<bool> update(UserModel user) async {
    return await safeOperation('update user', () async {
      final userEntity = _convertToEntity(user);
      return await _dao.updateUser(userEntity);
    }, userId: user.id);
  }

  @override
  Future<int> delete(int id, int userId) async {
    return await safeOperation('delete user', () async {
      return await _dao.deleteUser(id, userId);
    }, userId: userId);
  }

  Future<bool> emailExists(String email, int userId) async {
    return await safeOperation('check email exists', () async {
      return await _dao.emailExists(email, userId);
    });
  }

  Future<bool> usernameExists(String username, int userId) async {
    return await safeOperation('check username exists', () async {
      return await _dao.usernameExists(username, userId);
    });
  }

  Future<int> updateLastLogin(int id, int userId) async {
    return await safeOperation('update last login', () async {
      return await _dao.updateLastLogin(id, userId);
    }, userId: userId);
  }

  Future<int> updatePreferences(int id, int userId, Map<String, dynamic> preferences) async {
    return await safeOperation('update preferences', () async {
      final preferencesJson = json.encode(preferences);
      return await _dao.updatePreferences(id, userId, preferencesJson);
    }, userId: userId);
  }

  UserModel _convertToModel(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      lastLoginAt: user.lastLoginAt,
      isActive: user.isActive,
      isAdmin: user.isAdmin,
      preferences: user.preferences != null ? json.decode(user.preferences!) : null,
    );
  }

  User _convertToEntity(UserModel model) {
    return User(
      id: model.id,
      email: model.email,
      username: model.username,
      displayName: model.displayName,
      avatarUrl: model.avatarUrl,
      passwordHash: '', // This should be handled separately for security
      preferences: model.preferences != null ? json.encode(model.preferences) : null,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      lastLoginAt: model.lastLoginAt,
      isActive: model.isActive,
      isAdmin: model.isAdmin,
      userId: 1, // This should be managed by the database
    );
  }
}

// Room Repository
class RoomRepository extends BaseRepository<RoomModel, RoomsCompanion, RoomModel> {
  late final RoomDao _dao;

  RoomRepository(CannaAIDatabase database, Logger logger, SharedPreferences prefs)
      : super(database, logger, prefs, cachePrefix: 'room') {
    _dao = database.roomDao;
  }

  @override
  Future<RoomModel?> getById(int id, int userId) async {
    final cacheKey = 'room_$id';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return RoomModel.fromJson(cached as Map<String, dynamic>);
    }

    return await safeOperation('get room by id', () async {
      final room = await _dao.getRoomById(id, userId);
      if (room == null) return null;

      final model = _convertToModel(room);
      await _setCache(cacheKey, model, userId);
      return model;
    });
  }

  @override
  Future<List<RoomModel>> getAll(int userId) async {
    const cacheKey = 'all_rooms';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get all rooms', () async {
      final rooms = await _dao.getAllRooms(userId);
      final models = rooms.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  Future<List<RoomModel>> getByType(String roomType, int userId) async {
    final cacheKey = 'rooms_type_$roomType';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get rooms by type', () async {
      final rooms = await _dao.getRoomsByType(roomType, userId);
      final models = rooms.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  @override
  Future<int> create(RoomsCompanion room) async {
    return await safeOperation('create room', () async {
      return await _dao.createRoom(room);
    }, userId: room.userId.value);
  }

  @override
  Future<bool> update(RoomModel room) async {
    return await safeOperation('update room', () async {
      final roomEntity = _convertToEntity(room);
      return await _dao.updateRoom(roomEntity);
    }, userId: room.id);
  }

  @override
  Future<int> delete(int id, int userId) async {
    return await safeOperation('delete room', () async {
      return await _dao.deleteRoom(id, userId);
    }, userId: userId);
  }

  Future<int> updateTargets(int id, int userId, {
    double? temperature,
    double? humidity,
    double? ph,
    double? ec,
  }) async {
    return await safeOperation('update room targets', () async {
      return await _dao.updateRoomTargets(id, userId,
        temperature: temperature,
        humidity: humidity,
        ph: ph,
        ec: ec,
      );
    }, userId: userId);
  }

  RoomModel _convertToModel(Room room) {
    return RoomModel(
      id: room.id,
      name: room.name,
      description: room.description,
      location: room.location,
      imageUrl: room.imageUrl,
      roomType: room.roomType,
      size: room.size,
      targetTemperature: room.targetTemperature,
      targetHumidity: room.targetHumidity,
      targetPh: room.targetPh,
      targetEc: room.targetEc,
      isActive: room.isActive,
      createdAt: room.createdAt,
      updatedAt: room.updatedAt,
    );
  }

  Room _convertToEntity(RoomModel model) {
    return Room(
      id: model.id,
      name: model.name,
      description: model.description,
      location: model.location,
      imageUrl: model.imageUrl,
      roomType: model.roomType,
      size: model.size,
      targetTemperature: model.targetTemperature,
      targetHumidity: model.targetHumidity,
      targetPh: model.targetPh,
      targetEc: model.targetEc,
      isActive: model.isActive,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      userId: 1, // This should be managed by the database
    );
  }
}

// Plant Repository
class PlantRepository extends BaseRepository<PlantModel, PlantsCompanion, PlantModel> {
  late final PlantDao _dao;

  PlantRepository(CannaAIDatabase database, Logger logger, SharedPreferences prefs)
      : super(database, logger, prefs, cachePrefix: 'plant') {
    _dao = database.plantDao;
  }

  @override
  Future<PlantModel?> getById(int id, int userId) async {
    final cacheKey = 'plant_$id';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return PlantModel.fromJson(cached as Map<String, dynamic>);
    }

    return await safeOperation('get plant by id', () async {
      final plant = await _dao.getPlantById(id, userId);
      if (plant == null) return null;

      final model = _convertToModel(plant);
      await _setCache(cacheKey, model, userId);
      return model;
    });
  }

  @override
  Future<List<PlantModel>> getAll(int userId) async {
    const cacheKey = 'all_plants';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => PlantModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get all plants', () async {
      final plants = await _dao.getAllPlants(userId);
      final models = plants.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  Future<List<PlantModel>> getByRoom(int roomId, int userId) async {
    final cacheKey = 'plants_room_$roomId';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => PlantModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get plants by room', () async {
      final plants = await _dao.getPlantsByRoom(roomId, userId);
      final models = plants.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  Future<List<PlantModel>> getByStrain(int strainId, int userId) async {
    final cacheKey = 'plants_strain_$strainId';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => PlantModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get plants by strain', () async {
      final plants = await _dao.getPlantsByStrain(strainId, userId);
      final models = plants.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  Future<List<PlantModel>> getByGrowthStage(String growthStage, int userId) async {
    final cacheKey = 'plants_stage_$growthStage';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => PlantModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get plants by growth stage', () async {
      final plants = await _dao.getPlantsByGrowthStage(growthStage, userId);
      final models = plants.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  Future<List<PlantModel>> getByHealthStatus(String healthStatus, int userId) async {
    final cacheKey = 'plants_health_$healthStatus';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => PlantModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get plants by health status', () async {
      final plants = await _dao.getPlantsByHealthStatus(healthStatus, userId);
      final models = plants.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  Future<List<PlantModel>> getMotherPlants(int userId) async {
    const cacheKey = 'mother_plants';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => PlantModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get mother plants', () async {
      final plants = await _dao.getMotherPlants(userId);
      final models = plants.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  @override
  Future<int> create(PlantsCompanion plant) async {
    return await safeOperation('create plant', () async {
      return await _dao.createPlant(plant);
    }, userId: plant.userId.value);
  }

  @override
  Future<bool> update(PlantModel plant) async {
    return await safeOperation('update plant', () async {
      final plantEntity = _convertToEntity(plant);
      return await _dao.updatePlant(plantEntity);
    }, userId: plant.id);
  }

  @override
  Future<int> delete(int id, int userId) async {
    return await safeOperation('delete plant', () async {
      return await _dao.deletePlant(id, userId);
    }, userId: userId);
  }

  Future<int> updateGrowthStage(int id, int userId, String growthStage) async {
    return await safeOperation('update plant growth stage', () async {
      return await _dao.updatePlantGrowthStage(id, userId, growthStage);
    }, userId: userId);
  }

  Future<int> updateHealthStatus(int id, int userId, String healthStatus) async {
    return await safeOperation('update plant health status', () async {
      return await _dao.updatePlantHealthStatus(id, userId, healthStatus);
    }, userId: userId);
  }

  Future<int> updateMeasurements(int id, int userId, {
    double? height,
    double? weight,
    double? temperature,
    double? humidity,
    double? ph,
    double? ec,
    double? lightIntensity,
  }) async {
    return await safeOperation('update plant measurements', () async {
      return await _dao.updatePlantMeasurements(id, userId,
        height: height,
        weight: weight,
        temperature: temperature,
        humidity: humidity,
        ph: ph,
        ec: ec,
        lightIntensity: lightIntensity,
      );
    }, userId: userId);
  }

  Future<int> incrementWateringCount(int id, int userId) async {
    return await safeOperation('increment watering count', () async {
      return await _dao.incrementWateringCount(id, userId);
    }, userId: userId);
  }

  Future<int> incrementFeedingCount(int id, int userId) async {
    return await safeOperation('increment feeding count', () async {
      return await _dao.incrementFeedingCount(id, userId);
    }, userId: userId);
  }

  PlantModel _convertToModel(Plant plant) {
    return PlantModel(
      id: plant.id,
      name: plant.name,
      strainId: plant.strainId,
      roomId: plant.roomId,
      growthStage: plant.growthStage,
      healthStatus: plant.healthStatus,
      plantedDate: plant.plantedDate,
      expectedHarvestDate: plant.expectedHarvestDate,
      actualHarvestDate: plant.actualHarvestDate,
      height: plant.height,
      weight: plant.weight,
      gender: plant.gender,
      phenotype: plant.phenotype,
      notes: plant.notes,
      imageUrl: plant.imageUrl,
      temperature: plant.temperature,
      humidity: plant.humidity,
      ph: plant.ph,
      ec: plant.ec,
      lightIntensity: plant.lightIntensity,
      wateringCount: plant.wateringCount,
      lastWateringAt: plant.lastWateringAt,
      feedingCount: plant.feedingCount,
      lastFeedingAt: plant.lastFeedingAt,
      isActive: plant.isActive,
      isMotherPlant: plant.isMotherPlant,
      createdAt: plant.createdAt,
      updatedAt: plant.updatedAt,
    );
  }

  Plant _convertToEntity(PlantModel model) {
    return Plant(
      id: model.id,
      name: model.name,
      strainId: model.strainId,
      roomId: model.roomId,
      growthStage: model.growthStage,
      healthStatus: model.healthStatus,
      plantedDate: model.plantedDate,
      expectedHarvestDate: model.expectedHarvestDate,
      actualHarvestDate: model.actualHarvestDate,
      height: model.height,
      weight: model.weight,
      gender: model.gender,
      phenotype: model.phenotype,
      notes: model.notes,
      imageUrl: model.imageUrl,
      temperature: model.temperature,
      humidity: model.humidity,
      ph: model.ph,
      ec: model.ec,
      lightIntensity: model.lightIntensity,
      wateringCount: model.wateringCount,
      lastWateringAt: model.lastWateringAt,
      feedingCount: model.feedingCount,
      lastFeedingAt: model.lastFeedingAt,
      isActive: model.isActive,
      isMotherPlant: model.isMotherPlant,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      userId: 1, // This should be managed by the database
    );
  }
}

// Sensor Device Repository
class SensorDeviceRepository extends BaseRepository<SensorDeviceModel, SensorDevicesCompanion, SensorDeviceModel> {
  late final SensorDeviceDao _dao;

  SensorDeviceRepository(CannaAIDatabase database, Logger logger, SharedPreferences prefs)
      : super(database, logger, prefs, cachePrefix: 'sensor_device') {
    _dao = database.sensorDeviceDao;
  }

  @override
  Future<SensorDeviceModel?> getById(int id, int userId) async {
    final cacheKey = 'sensor_device_$id';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return SensorDeviceModel.fromJson(cached as Map<String, dynamic>);
    }

    return await safeOperation('get sensor device by id', () async {
      final device = await _dao.getDeviceById(id, userId);
      if (device == null) return null;

      final model = _convertToModel(device);
      await _setCache(cacheKey, model, userId);
      return model;
    });
  }

  Future<SensorDeviceModel?> getByDeviceId(String deviceId, int userId) async {
    final cacheKey = 'sensor_device_id_$deviceId';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return SensorDeviceModel.fromJson(cached as Map<String, dynamic>);
    }

    return await safeOperation('get sensor device by device id', () async {
      final device = await _dao.getDeviceByDeviceId(deviceId, userId);
      if (device == null) return null;

      final model = _convertToModel(device);
      await _setCache(cacheKey, model, userId);
      return model;
    });
  }

  @override
  Future<List<SensorDeviceModel>> getAll(int userId) async {
    const cacheKey = 'all_sensor_devices';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => SensorDeviceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get all sensor devices', () async {
      final devices = await _dao.getAllDevices(userId);
      final models = devices.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  Future<List<SensorDeviceModel>> getByRoom(int roomId, int userId) async {
    final cacheKey = 'sensor_devices_room_$roomId';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => SensorDeviceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get sensor devices by room', () async {
      final devices = await _dao.getDevicesByRoom(roomId, userId);
      final models = devices.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  Future<List<SensorDeviceModel>> getByType(String type, int userId) async {
    final cacheKey = 'sensor_devices_type_$type';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => SensorDeviceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get sensor devices by type', () async {
      final devices = await _dao.getDevicesByType(type, userId);
      final models = devices.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  Future<List<SensorDeviceModel>> getOnlineDevices(int userId) async {
    const cacheKey = 'online_sensor_devices';
    final cached = await _getCache(cacheKey, userId);
    if (cached != null) {
      return (cached as List)
          .map((e) => SensorDeviceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return await safeOperation('get online sensor devices', () async {
      final devices = await _dao.getOnlineDevices(userId);
      final models = devices.map(_convertToModel).toList();
      await _setCache(cacheKey, models, userId);
      return models;
    });
  }

  @override
  Future<int> create(SensorDevicesCompanion device) async {
    return await safeOperation('create sensor device', () async {
      return await _dao.createDevice(device);
    }, userId: device.userId.value);
  }

  @override
  Future<bool> update(SensorDeviceModel device) async {
    return await safeOperation('update sensor device', () async {
      final deviceEntity = _convertToEntity(device);
      return await _dao.updateDevice(deviceEntity);
    }, userId: device.id);
  }

  @override
  Future<int> delete(int id, int userId) async {
    return await safeOperation('delete sensor device', () async {
      return await _dao.deleteDevice(id, userId);
    }, userId: userId);
  }

  Future<int> updateStatus(int id, int userId, {
    bool? isOnline,
    int? batteryLevel,
    DateTime? lastSeenAt,
  }) async {
    return await safeOperation('update sensor device status', () async {
      return await _dao.updateDeviceStatus(id, userId,
        isOnline: isOnline,
        batteryLevel: batteryLevel,
        lastSeenAt: lastSeenAt ?? DateTime.now(),
      );
    }, userId: userId);
  }

  Future<bool> deviceIdExists(String deviceId, int userId) async {
    return await safeOperation('check device id exists', () async {
      return await _dao.deviceIdExists(deviceId, userId);
    });
  }

  SensorDeviceModel _convertToModel(SensorDevice device) {
    return SensorDeviceModel(
      id: device.id,
      deviceId: device.deviceId,
      name: device.name,
      type: device.type,
      manufacturer: device.manufacturer,
      model: device.model,
      firmwareVersion: device.firmwareVersion,
      bluetoothAddress: device.bluetoothAddress,
      wifiAddress: device.wifiAddress,
      calibrationOffset: device.calibrationOffset,
      calibrationScale: device.calibrationScale,
      unit: device.unit,
      minReading: device.minReading,
      maxReading: device.maxReading,
      batteryLevel: device.batteryLevel,
      isOnline: device.isOnline,
      isActive: device.isActive,
      lastSeenAt: device.lastSeenAt,
      lastCalibrationAt: device.lastCalibrationAt,
      createdAt: device.createdAt,
      updatedAt: device.updatedAt,
      roomId: device.roomId,
    );
  }

  SensorDevice _convertToEntity(SensorDeviceModel model) {
    return SensorDevice(
      id: model.id,
      deviceId: model.deviceId,
      name: model.name,
      type: model.type,
      manufacturer: model.manufacturer,
      model: model.model,
      firmwareVersion: model.firmwareVersion,
      bluetoothAddress: model.bluetoothAddress,
      wifiAddress: model.wifiAddress,
      calibrationOffset: model.calibrationOffset,
      calibrationScale: model.calibrationScale,
      unit: model.unit,
      minReading: model.minReading,
      maxReading: model.maxReading,
      batteryLevel: model.batteryLevel,
      isOnline: model.isOnline,
      isActive: model.isActive,
      lastSeenAt: model.lastSeenAt,
      lastCalibrationAt: model.lastCalibrationAt,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      roomId: model.roomId,
      userId: 1, // This should be managed by the database
    );
  }
}

// Repository factory
class RepositoryFactory {
  final CannaAIDatabase _database;
  final Logger _logger;
  final SharedPreferences _prefs;

  RepositoryFactory(this._database, this._logger, this._prefs);

  UserRepository get users => UserRepository(_database, _logger, _prefs);
  RoomRepository get rooms => RoomRepository(_database, _logger, _prefs);
  PlantRepository get plants => PlantRepository(_database, _logger, _prefs);
  SensorDeviceRepository get sensorDevices => SensorDeviceRepository(_database, _logger, _prefs);

  // Clear all caches
  Future<void> clearAllCaches(int userId) async {
    await users.clearAllCache(userId);
    await rooms.clearAllCache(userId);
    await plants.clearAllCache(userId);
    await sensorDevices.clearAllCache(userId);
  }
}