import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../constants/app_constants.dart';
import 'local_data_service.dart';

/// Local sensor simulation and management service
/// Provides realistic sensor data without requiring hardware
class LocalSensorService {
  static final LocalSensorService _instance = LocalSensorService._internal();
  factory LocalSensorService() => _instance;
  LocalSensorService._internal();

  final Logger _logger = Logger();
  final Random _random = Random();
  final LocalDataService _dataService = LocalDataService();

  // Room configurations
  final Map<String, RoomSensorState> _roomStates = {};
  Timer? _simulationTimer;

  // Stream controllers for real-time updates
  final StreamController<Map<String, dynamic>> _sensorDataStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _alertStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream getters
  Stream<Map<String, dynamic>> get sensorDataStream => _sensorDataStreamController.stream;
  Stream<Map<String, dynamic>> get alertStream => _alertStreamController.stream;

  // Device sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  /// Initialize the local sensor service
  Future<void> initialize() async {
    try {
      await _initializeRoomStates();
      await _dataService.initialize();
      _startDeviceSensorMonitoring();
      _startSensorSimulation();
      _logger.i('Local sensor service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize local sensor service: $e');
      rethrow;
    }
  }

  /// Initialize default room configurations
  Future<void> _initializeRoomStates() async {
    final defaultRooms = [
      {'id': 'grow_room_1', 'name': 'Main Grow Room', 'is_active': true},
      {'id': 'grow_room_2', 'name': 'Vegetation Room', 'is_active': false},
      {'id': 'clone_room', 'name': 'Clone/Seedling Room', 'is_active': false},
    ];

    for (final room in defaultRooms) {
      final roomId = room['id'] as String;
      final roomName = room['name'] as String;
      final isActive = room['is_active'] as bool;

      _roomStates[roomId] = RoomSensorState(
        roomId: roomId,
        roomName: roomName,
        isActive: isActive,
        targetTemp: 24.0 + _random.nextDouble() * 4.0, // 24-28°C
        targetHumidity: 50.0 + _random.nextDouble() * 20.0, // 50-70%
        targetPh: 6.0 + _random.nextDouble(), // 6.0-7.0
        targetEc: 1.5 + _random.nextDouble() * 0.5, // 1.5-2.0
        targetCo2: 1000.0 + _random.nextDouble() * 200.0, // 1000-1200 ppm
      );

      // Save room configuration
      await _dataService.saveRoomConfig(
        roomId: roomId,
        name: roomName,
        settings: {
          'target_temperature': _roomStates[roomId]!.targetTemp,
          'target_humidity': _roomStates[roomId]!.targetHumidity,
          'target_ph': _roomStates[roomId]!.targetPh,
          'target_ec': _roomStates[roomId]!.targetEc,
          'target_co2': _roomStates[roomId]!.targetCo2,
          'is_active': isActive,
        },
      );
    }
  }

  /// Start monitoring device sensors
  void _startDeviceSensorMonitoring() {
    // Accelerometer for device orientation and movement
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      _processAccelerometerData(event);
    });

    // Gyroscope for device rotation
    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      _processGyroscopeData(event);
    });
  }

  /// Process accelerometer data
  void _processAccelerometerData(AccelerometerEvent event) {
    // Use device movement to enhance sensor simulation realism
    final movement = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    if (movement > 15.0) {
      // Device is being moved - add some variation to sensor readings
      _injectMovementNoise();
    }
  }

  /// Process gyroscope data
  void _processGyroscopeData(GyroscopeEvent event) {
    final rotation = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    if (rotation > 2.0) {
      // Device is being rotated - simulate environmental changes
      _simulateEnvironmentalChange();
    }
  }

  /// Start the main sensor simulation loop
  void _startSensorSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(AppConstants.sensorUpdateInterval, (_) {
      _simulateSensorReadings();
    });
    _logger.i('Sensor simulation started with ${AppConstants.sensorUpdateInterval.inSeconds}s interval');
  }

  /// Simulate sensor readings for all active rooms
  Future<void> _simulateSensorReadings() async {
    try {
      for (final roomId in _roomStates.keys) {
        final roomState = _roomStates[roomId]!;
        if (!roomState.isActive) continue;

        final readings = await _generateSensorReadings(roomState);

        // Store readings in local database
        for (final reading in readings) {
          await _dataService.saveSensorData(
            roomId: roomId,
            sensorType: reading['type'],
            value: reading['value'],
            unit: reading['unit'],
          );
        }

        // Broadcast sensor data
        _sensorDataStreamController.add({
          'room_id': roomId,
          'timestamp': DateTime.now().toIso8601String(),
          'readings': readings,
        });

        // Check for alerts
        await _checkForAlerts(roomId, readings);
      }
    } catch (e) {
      _logger.e('Error in sensor simulation: $e');
    }
  }

  /// Generate realistic sensor readings for a room
  Future<List<Map<String, dynamic>>> _generateSensorReadings(RoomSensorState roomState) async {
    final List<Map<String, dynamic>> readings = [];
    final now = DateTime.now();

    // Temperature simulation
    final tempReading = _generateTemperatureReading(roomState, now);
    readings.add(tempReading);

    // Humidity simulation
    final humidityReading = _generateHumidityReading(roomState, now);
    readings.add(humidityReading);

    // pH simulation
    final phReading = _generatePhReading(roomState, now);
    readings.add(phReading);

    // EC simulation
    final ecReading = _generateEcReading(roomState, now);
    readings.add(ecReading);

    // CO2 simulation
    final co2Reading = _generateCo2Reading(roomState, now);
    readings.add(co2Reading);

    // Light intensity simulation
    final lightReading = _generateLightReading(roomState, now);
    readings.add(lightReading);

    // VPD (Vapor Pressure Deficit) calculation
    final vpdReading = _generateVpdReading(tempReading['value'], humidityReading['value']);
    readings.add(vpdReading);

    // Soil moisture simulation
    final moistureReading = _generateSoilMoistureReading(roomState, now);
    readings.add(moistureReading);

    // Update room state with new readings
    roomState.updateFromReadings(readings);

    return readings;
  }

  /// Generate temperature reading with realistic variations
  Map<String, dynamic> _generateTemperatureReading(RoomSensorState roomState, DateTime now) {
    // Base temperature with daily cycle
    final hourOfDay = now.hour;
    final dailyVariation = sin((hourOfDay - 6) * 2 * pi / 24) * 2.0; // ±2°C daily cycle

    // Random noise
    final noise = (_random.nextDouble() - 0.5) * 0.5; // ±0.5°C

    // Add drift towards target
    final currentTemp = roomState.currentTemp ?? roomState.targetTemp;
    final drift = (roomState.targetTemp - currentTemp) * 0.1;

    final newTemp = roomState.targetTemp + dailyVariation + noise + drift;

    return {
      'type': 'temperature',
      'value': newTemp.clamp(15.0, 35.0),
      'unit': '°C',
      'target': roomState.targetTemp,
    };
  }

  /// Generate humidity reading with realistic variations
  Map<String, dynamic> _generateHumidityReading(RoomSensorState roomState, DateTime now) {
    final hourOfDay = now.hour;
    final dailyVariation = -sin((hourOfDay - 6) * 2 * pi / 24) * 10.0; // Opposite to temperature
    final noise = (_random.nextDouble() - 0.5) * 2.0; // ±1%

    final currentHumidity = roomState.currentHumidity ?? roomState.targetHumidity;
    final drift = (roomState.targetHumidity - currentHumidity) * 0.15;

    final newHumidity = roomState.targetHumidity + dailyVariation + noise + drift;

    return {
      'type': 'humidity',
      'value': newHumidity.clamp(20.0, 80.0),
      'unit': '%',
      'target': roomState.targetHumidity,
    };
  }

  /// Generate pH reading with realistic variations
  Map<String, dynamic> _generatePhReading(RoomSensorState roomState, DateTime now) {
    // pH changes slowly with small daily variations
    final noise = (_random.nextDouble() - 0.5) * 0.1; // ±0.05
    final dailyDrift = sin(now.millisecondsSinceEpoch * 0.0001) * 0.05;

    final currentPh = roomState.currentPh ?? roomState.targetPh;
    final correction = (roomState.targetPh - currentPh) * 0.05; // Slow correction

    final newPh = roomState.targetPh + noise + dailyDrift + correction;

    return {
      'type': 'ph',
      'value': newPh.clamp(5.0, 7.5),
      'unit': 'pH',
      'target': roomState.targetPh,
    };
  }

  /// Generate EC (Electrical Conductivity) reading
  Map<String, dynamic> _generateEcReading(RoomSensorState roomState, DateTime now) {
    final noise = (_random.nextDouble() - 0.5) * 0.1; // ±0.05 mS/cm
    final dailyVariation = cos(now.millisecondsSinceEpoch * 0.0001) * 0.1;

    final currentEc = roomState.currentEc ?? roomState.targetEc;
    final correction = (roomState.targetEc - currentEc) * 0.08;

    final newEc = roomState.targetEc + noise + dailyVariation + correction;

    return {
      'type': 'ec',
      'value': newEc.clamp(0.8, 3.0),
      'unit': 'mS/cm',
      'target': roomState.targetEc,
    };
  }

  /// Generate CO2 reading with realistic variations
  Map<String, dynamic> _generateCo2Reading(RoomSensorState roomState, DateTime now) {
    // CO2 varies with time of day and plant activity
    final hourOfDay = now.hour;
    final isLightsOn = hourOfDay >= 6 && hourOfDay <= 18;

    final baseVariation = isLightsOn ? 100.0 : 50.0;
    final noise = (_random.nextDouble() - 0.5) * 50.0;

    final currentCo2 = roomState.currentCo2 ?? roomState.targetCo2;
    final correction = (roomState.targetCo2 - currentCo2) * 0.2;

    final newCo2 = roomState.targetCo2 + baseVariation + noise + correction;

    return {
      'type': 'co2',
      'value': newCo2.clamp(400.0, 2000.0),
      'unit': 'ppm',
      'target': roomState.targetCo2,
    };
  }

  /// Generate light intensity reading
  Map<String, dynamic> _generateLightReading(RoomSensorState roomState, DateTime now) {
    final hourOfDay = now.hour;
    final isLightsOn = hourOfDay >= 6 && hourOfDay <= 18;

    if (!isLightsOn) {
      return {
        'type': 'light_intensity',
        'value': _random.nextDouble() * 50, // Minimal light
        'unit': 'µmol/m²/s',
        'target': 0.0,
      };
    }

    // Simulate different growth stages
    final growthStage = _getGrowthStage(now);
    double targetLight;

    switch (growthStage) {
      case 'vegetative':
        targetLight = 400.0 + _random.nextDouble() * 200.0; // 400-600
        break;
      case 'flowering':
        targetLight = 600.0 + _random.nextDouble() * 400.0; // 600-1000
        break;
      default:
        targetLight = 200.0 + _random.nextDouble() * 200.0; // 200-400
    }

    final noise = (_random.nextDouble() - 0.5) * 50.0;

    return {
      'type': 'light_intensity',
      'value': (targetLight + noise).clamp(0.0, 1200.0),
      'unit': 'µmol/m²/s',
      'target': targetLight,
    };
  }

  /// Generate VPD (Vapor Pressure Deficit) reading
  Map<String, dynamic> _generateVpdReading(double temperature, double humidity) {
    // Calculate VPD using simplified formula
    final tempCelsius = temperature;
    final relativeHumidity = humidity / 100.0;

    // Saturation vapor pressure (kPa)
    final svp = 0.6108 * exp(17.27 * tempCelsius / (tempCelsius + 237.3));

    // Actual vapor pressure
    final avp = svp * relativeHumidity;

    // VPD
    final vpd = svp - avp;

    return {
      'type': 'vpd',
      'value': vpd.clamp(0.0, 3.0),
      'unit': 'kPa',
      'optimal_range': '0.8-1.2 kPa',
    };
  }

  /// Generate soil moisture reading
  Map<String, dynamic> _generateSoilMoistureReading(RoomSensorState roomState, DateTime now) {
    final hourOfDay = now.hour;
    final isWateringTime = hourOfDay % 8 == 0; // Simulate watering every 8 hours

    double baseMoisture = 60.0 + _random.nextDouble() * 20.0; // 60-80%

    if (isWateringTime) {
      baseMoisture += _random.nextDouble() * 20.0; // Watering boost
    }

    // Gradual drying
    final drying = (_random.nextDouble() - 0.5) * 2.0;

    final finalMoisture = baseMoisture + drying;

    return {
      'type': 'soil_moisture',
      'value': finalMoisture.clamp(30.0, 95.0),
      'unit': '%',
      'optimal_range': '60-70%',
    };
  }

  /// Check for alerts and conditions
  Future<void> _checkForAlerts(String roomId, List<Map<String, dynamic>> readings) async {
    final List<String> alerts = [];

    for (final reading in readings) {
      final type = reading['type'] as String;
      final value = reading['value'] as double;
      final target = reading['target'] as double?;

      // Temperature alerts
      if (type == 'temperature') {
        if (value < 18.0) {
          alerts.add('Temperature too low: ${value.toStringAsFixed(1)}°C');
        } else if (value > 32.0) {
          alerts.add('Temperature too high: ${value.toStringAsFixed(1)}°C');
        }
      }

      // Humidity alerts
      if (type == 'humidity') {
        if (value < 35.0) {
          alerts.add('Humidity too low: ${value.toStringAsFixed(1)}%');
        } else if (value > 75.0) {
          alerts.add('Humidity too high: ${value.toStringAsFixed(1)}%');
        }
      }

      // pH alerts
      if (type == 'ph') {
        if (value < 5.5) {
          alerts.add('pH too low: ${value.toStringAsFixed(1)}');
        } else if (value > 7.0) {
          alerts.add('pH too high: ${value.toStringAsFixed(1)}');
        }
      }

      // EC alerts
      if (type == 'ec') {
        if (value < 1.0) {
          alerts.add('EC too low: ${value.toStringAsFixed(1)} mS/cm');
        } else if (value > 2.5) {
          alerts.add('EC too high: ${value.toStringAsFixed(1)} mS/cm');
        }
      }

      // CO2 alerts
      if (type == 'co2') {
        if (value < 600.0) {
          alerts.add('CO2 too low: ${value.toStringAsFixed(0)} ppm');
        } else if (value > 1500.0) {
          alerts.add('CO2 too high: ${value.toStringAsFixed(0)} ppm');
        }
      }
    }

    // Broadcast alerts if any
    if (alerts.isNotEmpty) {
      _alertStreamController.add({
        'room_id': roomId,
        'timestamp': DateTime.now().toIso8601String(),
        'alerts': alerts,
        'severity': alerts.length > 2 ? 'high' : 'medium',
      });
    }
  }

  /// Inject movement noise based on device accelerometer
  void _injectMovementNoise() {
    for (final roomState in _roomStates.values) {
      if (!roomState.isActive) continue;

      // Add small random variations to simulate environmental changes
      roomState.currentTemp = (roomState.currentTemp ?? roomState.targetTemp) + (_random.nextDouble() - 0.5) * 0.2;
      roomState.currentHumidity = (roomState.currentHumidity ?? roomState.targetHumidity) + (_random.nextDouble() - 0.5) * 1.0;
    }
  }

  /// Simulate environmental change based on device rotation
  void _simulateEnvironmentalChange() {
    // Simulate someone adjusting ventilation or lights
    for (final roomState in _roomStates.values) {
      if (!roomState.isActive) continue;

      // Small adjustments to environmental targets
      roomState.targetTemp += (_random.nextDouble() - 0.5) * 0.5;
      roomState.targetHumidity += (_random.nextDouble() - 0.5) * 2.0;
    }
  }

  /// Get current growth stage based on time (simulated)
  String _getGrowthStage(DateTime now) {
    final dayOfMonth = now.day;
    if (dayOfMonth < 10) return 'seedling';
    if (dayOfMonth < 20) return 'vegetative';
    return 'flowering';
  }

  // Public API methods

  /// Get current sensor data for all rooms
  Future<Map<String, Map<String, dynamic>>> getCurrentSensorData() async {
    return await _dataService.getLatestSensorData();
  }

  /// Get sensor data history for a specific room
  Future<List<Map<String, dynamic>>> getSensorHistory({
    required String roomId,
    required String sensorType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    return await _dataService.getSensorData(
      roomId: roomId,
      sensorType: sensorType,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Add a new room
  Future<void> addRoom({
    required String roomId,
    required String name,
    Map<String, dynamic>? settings,
  }) async {
    _roomStates[roomId] = RoomSensorState(
      roomId: roomId,
      roomName: name,
      isActive: false,
      targetTemp: settings?['target_temperature'] ?? 24.0,
      targetHumidity: settings?['target_humidity'] ?? 55.0,
      targetPh: settings?['target_ph'] ?? 6.0,
      targetEc: settings?['target_ec'] ?? 1.8,
      targetCo2: settings?['target_co2'] ?? 1000.0,
    );

    await _dataService.saveRoomConfig(
      roomId: roomId,
      name: name,
      settings: settings ?? {},
    );

    _logger.i('Room added: $roomId ($name)');
  }

  /// Update room settings
  Future<void> updateRoomSettings({
    required String roomId,
    Map<String, dynamic>? settings,
  }) async {
    final roomState = _roomStates[roomId];
    if (roomState == null) return;

    if (settings != null) {
      if (settings.containsKey('target_temperature')) {
        roomState.targetTemp = settings['target_temperature'];
      }
      if (settings.containsKey('target_humidity')) {
        roomState.targetHumidity = settings['target_humidity'];
      }
      if (settings.containsKey('target_ph')) {
        roomState.targetPh = settings['target_ph'];
      }
      if (settings.containsKey('target_ec')) {
        roomState.targetEc = settings['target_ec'];
      }
      if (settings.containsKey('target_co2')) {
        roomState.targetCo2 = settings['target_co2'];
      }
    }

    await _dataService.saveRoomConfig(
      roomId: roomId,
      name: roomState.roomName,
      settings: settings ?? {},
    );

    _logger.i('Room settings updated: $roomId');
  }

  /// Toggle room active status
  Future<void> toggleRoomStatus(String roomId) async {
    final roomState = _roomStates[roomId];
    if (roomState == null) return;

    roomState.isActive = !roomState.isActive;

    await _dataService.saveRoomConfig(
      roomId: roomId,
      name: roomState.roomName,
      settings: {
        'is_active': roomState.isActive,
        'target_temperature': roomState.targetTemp,
        'target_humidity': roomState.targetHumidity,
        'target_ph': roomState.targetPh,
        'target_ec': roomState.targetEc,
        'target_co2': roomState.targetCo2,
      },
    );

    _logger.i('Room ${roomState.isActive ? 'activated' : 'deactivated'}: $roomId');
  }

  /// Get list of all rooms
  List<Map<String, dynamic>> getAllRooms() {
    return _roomStates.entries.map((entry) {
      final state = entry.value;
      return {
        'id': state.roomId,
        'name': state.roomName,
        'is_active': state.isActive,
        'target_temperature': state.targetTemp,
        'target_humidity': state.targetHumidity,
        'target_ph': state.targetPh,
        'target_ec': state.targetEc,
        'target_co2': state.targetCo2,
        'current_temperature': state.currentTemp,
        'current_humidity': state.currentHumidity,
        'current_ph': state.currentPh,
        'current_ec': state.currentEc,
        'current_co2': state.currentCo2,
      };
    }).toList();
  }

  /// Get room state by ID
  RoomSensorState? getRoomState(String roomId) {
    return _roomStates[roomId];
  }

  /// Stop sensor simulation
  void stopSimulation() {
    _simulationTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _logger.i('Sensor simulation stopped');
  }

  /// Dispose of all resources
  void dispose() {
    stopSimulation();
    _sensorDataStreamController.close();
    _alertStreamController.close();
    _logger.i('Local sensor service disposed');
  }
}

/// Room sensor state management
class RoomSensorState {
  final String roomId;
  final String roomName;
  bool isActive;

  // Target values
  double targetTemp;
  double targetHumidity;
  double targetPh;
  double targetEc;
  double targetCo2;

  // Current readings
  double? currentTemp;
  double? currentHumidity;
  double? currentPh;
  double? currentEc;
  double? currentCo2;

  RoomSensorState({
    required this.roomId,
    required this.roomName,
    required this.isActive,
    required this.targetTemp,
    required this.targetHumidity,
    required this.targetPh,
    required this.targetEc,
    required this.targetCo2,
  });

  /// Update current readings from sensor data
  void updateFromReadings(List<Map<String, dynamic>> readings) {
    for (final reading in readings) {
      final type = reading['type'] as String;
      final value = reading['value'] as double;

      switch (type) {
        case 'temperature':
          currentTemp = value;
          break;
        case 'humidity':
          currentHumidity = value;
          break;
        case 'ph':
          currentPh = value;
          break;
        case 'ec':
          currentEc = value;
          break;
        case 'co2':
          currentCo2 = value;
          break;
      }
    }
  }
}