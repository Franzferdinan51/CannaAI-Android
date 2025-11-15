import 'dart:async';
import 'dart:math';
import 'package:logger/logger.dart';
import '../events/event_bus.dart';
import '../models/sensor_data.dart';
import '../constants/app_constants.dart';

/// Sensor device configuration
class SensorDeviceConfig {
  final String id;
  final String name;
  final String roomId;
  final SensorType type;
  final Map<String, double> ranges;
  final Map<String, double> currentValues;
  final Duration updateInterval;
  final bool enabled;

  SensorDeviceConfig({
    required this.id,
    required this.name,
    required this.roomId,
    required this.type,
    required this.ranges,
    Map<String, double>? currentValues,
    this.updateInterval = const Duration(seconds: 5),
    this.enabled = true,
  }) : currentValues = currentValues ?? {};

  SensorDeviceConfig copyWith({
    String? id,
    String? name,
    String? roomId,
    SensorType? type,
    Map<String, double>? ranges,
    Map<String, double>? currentValues,
    Duration? updateInterval,
    bool? enabled,
  }) {
    return SensorDeviceConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      roomId: roomId ?? this.roomId,
      type: type ?? this.type,
      ranges: ranges ?? this.ranges,
      currentValues: currentValues ?? this.currentValues,
      updateInterval: updateInterval ?? this.updateInterval,
      enabled: enabled ?? this.enabled,
    );
  }
}

enum SensorType {
  environmental,  // Temperature, humidity, CO2, etc.
  hydroponic,     // pH, EC, water level
  lighting,       // Light intensity, spectrum
  soil,           // Soil moisture, temperature
  air,            // Air quality, pressure
  custom,
}

/// Simulated sensor data patterns
class SensorDataPattern {
  final String metric;
  final double baseValue;
  final double variance;
  final double driftPerHour;
  final List<double> hourlyVariation; // 24-hour pattern
  final double noiseLevel;

  SensorDataPattern({
    required this.metric,
    required this.baseValue,
    this.variance = 0.1,
    this.driftPerHour = 0.0,
    List<double>? hourlyVariation,
    this.noiseLevel = 0.05,
  }) : hourlyVariation = hourlyVariation ?? List.filled(24, 0.0);

  double generateValue(DateTime now, double currentValue) {
    final hour = now.hour;
    final minute = now.minute;
    final second = now.second;

    // Base value with hourly variation
    double value = baseValue + hourlyVariation[hour];

    // Add smooth transitions between hours
    if (minute > 0 || second > 0) {
      final nextHour = (hour + 1) % 24;
      final transitionFactor = (minute + second / 60.0) / 60.0;
      value = value * (1 - transitionFactor) +
              (baseValue + hourlyVariation[nextHour]) * transitionFactor;
    }

    // Add drift over time
    final hoursSinceStart = now.difference(DateTime(now.year, now.month, now.day)).inHours.toDouble();
    value += driftPerHour * hoursSinceStart;

    // Add realistic noise
    final random = Random();
    final noise = (random.nextDouble() - 0.5) * 2 * noiseLevel * baseValue;
    value += noise;

    // Add small random spikes (sensor glitches)
    if (random.nextDouble() < 0.001) { // 0.1% chance
      value += (random.nextDouble() - 0.5) * variance * baseValue * 2;
    }

    // Smooth the value change from current
    final smoothingFactor = 0.3; // 30% towards new value
    return currentValue * (1 - smoothingFactor) + value * smoothingFactor;
  }
}

/// Real-time sensor simulator
class SensorSimulator {
  static final SensorSimulator _instance = SensorSimulator._internal();
  factory SensorSimulator() => _instance;
  SensorSimulator._internal();

  final Logger _logger = Logger();
  final Map<String, SensorDeviceConfig> _devices = {};
  final Map<String, Timer> _deviceTimers = {};
  final Map<String, SensorDataPattern> _patterns = {};
  final Random _random = Random();
  bool _isRunning = false;

  /// Current simulated devices
  Map<String, SensorDeviceConfig> get devices => Map.unmodifiable(_devices);

  /// Running status
  bool get isRunning => _isRunning;

  /// Initialize with default devices and patterns
  Future<void> initialize() async {
    await _createDefaultPatterns();
    await _createDefaultDevices();
    _logger.i('Sensor simulator initialized with ${_devices.length} devices');
  }

  /// Start all sensor simulations
  Future<void> start() async {
    if (_isRunning) return;

    _isRunning = true;
    for (final device in _devices.values) {
      if (device.enabled) {
        _startDeviceSimulation(device);
      }
    }
    _logger.i('Sensor simulator started');
  }

  /// Stop all sensor simulations
  Future<void> stop() async {
    _isRunning = false;
    for (final timer in _deviceTimers.values) {
      timer.cancel();
    }
    _deviceTimers.clear();
    _logger.i('Sensor simulator stopped');
  }

  /// Add a new sensor device
  Future<void> addDevice(SensorDeviceConfig device) async {
    _devices[device.id] = device;
    if (_isRunning && device.enabled) {
      _startDeviceSimulation(device);
    }
    _logger.d('Added sensor device: ${device.name} (${device.id})');
  }

  /// Remove a sensor device
  Future<void> removeDevice(String deviceId) async {
    final timer = _deviceTimers.remove(deviceId);
    timer?.cancel();
    _devices.remove(deviceId);
    _logger.d('Removed sensor device: $deviceId');
  }

  /// Update device configuration
  Future<void> updateDevice(String deviceId, SensorDeviceConfig updatedDevice) async {
    final oldDevice = _devices[deviceId];
    if (oldDevice != null) {
      // Stop old simulation
      final timer = _deviceTimers.remove(deviceId);
      timer?.cancel();

      // Update and restart if needed
      _devices[deviceId] = updatedDevice;
      if (_isRunning && updatedDevice.enabled) {
        _startDeviceSimulation(updatedDevice);
      }
      _logger.d('Updated sensor device: $deviceId');
    }
  }

  /// Get current value for a specific device metric
  double? getCurrentValue(String deviceId, String metric) {
    return _devices[deviceId]?.currentValues[metric];
  }

  /// Get all current sensor data
  Map<String, Map<String, double>> getAllCurrentValues() {
    final result = <String, Map<String, double>>{};
    for (final device in _devices.values) {
      result[device.id] = Map.from(device.currentValues);
    }
    return result;
  }

  /// Simulate environmental anomaly (heat wave, cold snap, etc.)
  Future<void> simulateEnvironmentalAnomaly({
    required String roomId,
    required double temperatureChange,
    required double humidityChange,
    Duration duration = const Duration(hours: 4),
  }) async {
    final devicesInRoom = _devices.values.where((d) => d.roomId == roomId).toList();

    for (final device in devicesInRoom) {
      if (device.currentValues.containsKey('temperature')) {
        device.currentValues['temperature'] =
            (device.currentValues['temperature'] ?? 0) + temperatureChange;
      }
      if (device.currentValues.containsKey('humidity')) {
        device.currentValues['humidity'] =
            (device.currentValues['humidity'] ?? 0) + humidityChange;
      }

      // Emit immediate update
      _emitSensorData(device);
    }

    _logger.i('Environmental anomaly simulated in room $roomId: '
              'T+$temperatureChange°C, H+$humidityChange%');

    // Schedule restoration
    Timer(duration, () {
      for (final device in devicesInRoom) {
        if (device.currentValues.containsKey('temperature')) {
          device.currentValues['temperature'] =
              (device.currentValues['temperature'] ?? 0) - temperatureChange;
        }
        if (device.currentValues.containsKey('humidity')) {
          device.currentValues['humidity'] =
              (device.currentValues['humidity'] ?? 0) - humidityChange;
        }
        _emitSensorData(device);
      }
      _logger.i('Environmental anomaly restored in room $roomId');
    });
  }

  void _startDeviceSimulation(SensorDeviceConfig device) {
    final timer = Timer.periodic(device.updateInterval, (_) {
      if (!_isRunning) return;
      _updateDeviceData(device);
    });
    _deviceTimers[device.id] = timer;
    _logger.d('Started simulation for device: ${device.name}');
  }

  void _updateDeviceData(SensorDeviceConfig device) {
    final now = DateTime.now();
    final updatedValues = <String, double>{};

    for (final metric in device.ranges.keys) {
      final pattern = _patterns[metric];
      if (pattern != null) {
        final currentValue = device.currentValues[metric] ?? pattern.baseValue;
        final newValue = pattern.generateValue(now, currentValue);

        // Ensure value is within acceptable range
        final range = device.ranges[metric];
        final clampedValue = newValue.clamp(range * 0.8, range * 1.2);

        updatedValues[metric] = clampedValue;
        device.currentValues[metric] = clampedValue;
      }
    }

    // Calculate derived metrics
    _calculateDerivedMetrics(device);

    // Emit sensor data event
    _emitSensorData(device);

    // Check for alerts
    _checkForAlerts(device);
  }

  void _calculateDerivedMetrics(SensorDeviceConfig device) {
    final values = device.currentValues;

    // Calculate VPD (Vapor Pressure Deficit)
    if (values.containsKey('temperature') && values.containsKey('humidity')) {
      final temp = values['temperature']!;
      final humidity = values['humidity']!;

      // SVP calculation (simplified)
      final svp = 610.78 * pow((temp / (temp + 237.3)), 17.27);
      final vpa = svp * (humidity / 100);
      final vpd = (svp - vpa) / 1000; // Convert to kPa

      values['vpd'] = vpd.clamp(0.0, 5.0);
    }

    // Calculate heat index
    if (values.containsKey('temperature') && values.containsKey('humidity')) {
      final temp = values['temperature']!;
      final humidity = values['humidity']!;

      // Simplified heat index calculation
      if (temp > 26.7) { // Only calculate above 80°F
        final hi = -42.379 + 2.04901523 * temp + 10.14333127 * humidity
                  - 0.22475541 * temp * humidity - 6.83783e-3 * temp * temp
                  - 5.481717e-2 * humidity * humidity + 1.22874e-3 * temp * temp * humidity
                  + 8.5282e-4 * temp * humidity * humidity - 1.99e-6 * temp * temp * humidity * humidity;
        values['heatIndex'] = hi;
      } else {
        values['heatIndex'] = temp;
      }
    }
  }

  void _emitSensorData(SensorDeviceConfig device) {
    final sensorData = SensorData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: device.id,
      roomId: device.roomId,
      timestamp: DateTime.now(),
      metrics: SensorMetrics(
        temperature: device.currentValues['temperature'],
        humidity: device.currentValues['humidity'],
        ph: device.currentValues['ph'],
        ec: device.currentValues['ec'],
        co2: device.currentValues['co2'],
        vpd: device.currentValues['vpd'],
        lightIntensity: device.currentValues['lightIntensity'],
        soilMoisture: device.currentValues['soilMoisture'],
        waterLevel: device.currentValues['waterLevel'],
        airPressure: device.currentValues['airPressure'],
        windSpeed: device.currentValues['windSpeed'],
        customMetrics: Map.from(device.currentValues)
          ..removeWhere((key, value) => [
            'temperature', 'humidity', 'ph', 'ec', 'co2', 'vpd',
            'lightIntensity', 'soilMoisture', 'waterLevel',
            'airPressure', 'windSpeed'
          ].contains(key)),
      ),
      metadata: {
        'deviceName': device.name,
        'deviceType': device.type.toString(),
        'simulation': true,
      },
    );

    final event = SensorDataEvent(
      deviceId: device.id,
      roomId: device.roomId,
      sensorData: sensorData.toJson(),
      metadata: {
        'deviceName': device.name,
        'deviceType': device.type.toString(),
      },
    );

    eventBus.emit(event);
  }

  void _checkForAlerts(SensorDeviceConfig device) {
    final values = device.currentValues;
    final alerts = <String, String>{};

    // Temperature alerts
    if (values.containsKey('temperature')) {
      final temp = values['temperature']!;
      if (temp < 18.0) {
        alerts['temperature_low'] = 'Temperature too low: ${temp.toStringAsFixed(1)}°C';
      } else if (temp > 32.0) {
        alerts['temperature_high'] = 'Temperature too high: ${temp.toStringAsFixed(1)}°C';
      }
    }

    // Humidity alerts
    if (values.containsKey('humidity')) {
      final humidity = values['humidity']!;
      if (humidity < 30.0) {
        alerts['humidity_low'] = 'Humidity too low: ${humidity.toStringAsFixed(1)}%';
      } else if (humidity > 70.0) {
        alerts['humidity_high'] = 'Humidity too high: ${humidity.toStringAsFixed(1)}%';
      }
    }

    // pH alerts
    if (values.containsKey('ph')) {
      final ph = values['ph']!;
      if (ph < 5.5) {
        alerts['ph_low'] = 'pH too low: ${ph.toStringAsFixed(1)}';
      } else if (ph > 6.5) {
        alerts['ph_high'] = 'pH too high: ${ph.toStringAsFixed(1)}';
      }
    }

    // CO2 alerts
    if (values.containsKey('co2')) {
      final co2 = values['co2']!;
      if (co2 < 400.0) {
        alerts['co2_low'] = 'CO2 too low: ${co2.toStringAsFixed(0)}ppm';
      } else if (co2 > 1500.0) {
        alerts['co2_high'] = 'CO2 too high: ${co2.toStringAsFixed(0)}ppm';
      }
    }

    // Emit alert events
    for (final alert in alerts.entries) {
      final event = SensorAlertEvent(
        deviceId: device.id,
        roomId: device.roomId,
        alertType: alert.key,
        severity: _getAlertSeverity(alert.key),
        message: alert.value,
        recommendation: _getAlertRecommendation(alert.key),
      );
      eventBus.emit(event);
    }
  }

  String _getAlertSeverity(String alertType) {
    if (alertType.contains('high')) return 'high';
    if (alertType.contains('low')) return 'medium';
    return 'low';
  }

  String _getAlertRecommendation(String alertType) {
    switch (alertType) {
      case 'temperature_low':
        return 'Increase heating or check ventilation system';
      case 'temperature_high':
        return 'Increase ventilation or cooling system';
      case 'humidity_low':
        return 'Increase humidification or check for leaks';
      case 'humidity_high':
        return 'Increase dehumidification or ventilation';
      case 'ph_low':
        return 'Add pH up solution to nutrient mix';
      case 'ph_high':
        return 'Add pH down solution to nutrient mix';
      case 'co2_low':
        return 'Check CO2 injection system or ventilation';
      case 'co2_high':
        return 'Increase ventilation or reduce CO2 injection';
      default:
        return 'Check system and consult growing guide';
    }
  }

  Future<void> _createDefaultPatterns() async {
    // Temperature pattern (day/night cycle)
    _patterns['temperature'] = SensorDataPattern(
      metric: 'temperature',
      baseValue: 24.0,
      variance: 2.0,
      hourlyVariation: [
        -3.0, -3.5, -4.0, -4.5, -5.0, -4.5, -4.0, -3.0,  // 0-7: Night
        -2.0, -1.0, 0.0, 1.0, 2.0, 2.5, 3.0, 3.5,        // 8-15: Day warm-up
        3.0, 2.0, 1.0, 0.0, -1.0, -2.0, -2.5, -3.0,      // 16-23: Evening cool-down
      ],
      noiseLevel: 0.3,
    );

    // Humidity pattern (inverse of temperature)
    _patterns['humidity'] = SensorDataPattern(
      metric: 'humidity',
      baseValue: 55.0,
      variance: 5.0,
      hourlyVariation: [
        10.0, 12.0, 15.0, 18.0, 20.0, 18.0, 15.0, 12.0,   // 0-7: Higher humidity at night
        8.0, 5.0, 0.0, -3.0, -5.0, -8.0, -10.0, -12.0,  // 8-15: Lower humidity during day
        -10.0, -8.0, -5.0, -3.0, 0.0, 3.0, 5.0, 8.0,     // 16-23: Evening humidity rise
      ],
      noiseLevel: 2.0,
    );

    // CO2 pattern (related to plant activity)
    _patterns['co2'] = SensorDataPattern(
      metric: 'co2',
      baseValue: 1000.0,
      variance: 50.0,
      driftPerHour: -2.0, // Plants consume CO2 during day
      hourlyVariation: [
        -100, -150, -200, -250, -200, -150, -100, -50,   // 0-7: Night accumulation
        0, 50, 100, 150, 200, 150, 100, 50,             // 8-15: Day consumption
        0, -50, -100, -150, -100, -50, 0, -50,          // 16-23: Evening transition
      ],
      noiseLevel: 20.0,
    );

    // pH pattern (slow drift with occasional adjustments)
    _patterns['ph'] = SensorDataPattern(
      metric: 'ph',
      baseValue: 6.0,
      variance: 0.1,
      driftPerHour: 0.02, // Slow pH drift
      noiseLevel: 0.05,
    );

    // EC pattern (stable with occasional nutrient addition)
    _patterns['ec'] = SensorDataPattern(
      metric: 'ec',
      baseValue: 1.6,
      variance: 0.1,
      noiseLevel: 0.05,
    );

    // Light intensity pattern (day/night cycle)
    _patterns['lightIntensity'] = SensorDataPattern(
      metric: 'lightIntensity',
      baseValue: 500.0,
      variance: 50.0,
      hourlyVariation: [
        0, 0, 0, 0, 0, 0, 0, 0,                           // 0-7: Night
        100, 300, 500, 700, 900, 1000, 900, 700,         // 8-15: Daylight
        500, 300, 100, 0, 0, 0, 0, 0,                     // 16-23: Evening
      ],
      noiseLevel: 30.0,
    );

    // Soil moisture pattern (decreases, then watering resets)
    _patterns['soilMoisture'] = SensorDataPattern(
      metric: 'soilMoisture',
      baseValue: 65.0,
      variance: 5.0,
      driftPerHour: -2.0, // Drying out
      hourlyVariation: List.filled(24, 0.0),
      noiseLevel: 1.0,
    );

    // Water level pattern (decreases slowly)
    _patterns['waterLevel'] = SensorDataPattern(
      metric: 'waterLevel',
      baseValue: 80.0,
      variance: 2.0,
      driftPerHour: -0.5, // Slow consumption
      noiseLevel: 0.5,
    );

    _logger.d('Created ${_patterns.length} sensor data patterns');
  }

  Future<void> _createDefaultDevices() async {
    // Environmental sensor - Vegetative Room
    await addDevice(SensorDeviceConfig(
      id: 'env_sensor_veg_01',
      name: 'Environmental Sensor - Veg Room',
      roomId: 'vegetative_room_1',
      type: SensorType.environmental,
      ranges: {
        'temperature': 35.0,
        'humidity': 100.0,
        'co2': 2000.0,
        'vpd': 5.0,
        'airPressure': 1100.0,
      },
      currentValues: {
        'temperature': 24.0,
        'humidity': 55.0,
        'co2': 1000.0,
        'airPressure': 1013.25,
      },
      updateInterval: Duration(seconds: 5),
    ));

    // Hydroponic sensor - Vegetative Room
    await addDevice(SensorDeviceConfig(
      id: 'hydro_sensor_veg_01',
      name: 'Hydroponic Sensor - Veg Room',
      roomId: 'vegetative_room_1',
      type: SensorType.hydroponic,
      ranges: {
        'ph': 14.0,
        'ec': 3.0,
        'waterLevel': 100.0,
        'waterTemperature': 35.0,
      },
      currentValues: {
        'ph': 6.0,
        'ec': 1.6,
        'waterLevel': 80.0,
        'waterTemperature': 22.0,
      },
      updateInterval: Duration(seconds: 10),
    ));

    // Environmental sensor - Flowering Room
    await addDevice(SensorDeviceConfig(
      id: 'env_sensor_flower_01',
      name: 'Environmental Sensor - Flower Room',
      roomId: 'flowering_room_1',
      type: SensorType.environmental,
      ranges: {
        'temperature': 35.0,
        'humidity': 100.0,
        'co2': 2000.0,
        'vpd': 5.0,
        'airPressure': 1100.0,
      },
      currentValues: {
        'temperature': 26.0,
        'humidity': 50.0,
        'co2': 1200.0,
        'airPressure': 1013.25,
      },
      updateInterval: Duration(seconds: 5),
    ));

    // Lighting sensor - Flowering Room
    await addDevice(SensorDeviceConfig(
      id: 'light_sensor_flower_01',
      name: 'Lighting Sensor - Flower Room',
      roomId: 'flowering_room_1',
      type: SensorType.lighting,
      ranges: {
        'lightIntensity': 1500.0,
        'par': 2000.0,
        'ppfd': 1500.0,
      },
      currentValues: {
        'lightIntensity': 800.0,
        'par': 1200.0,
        'ppfd': 900.0,
      },
      updateInterval: Duration(seconds: 3),
    ));

    // Soil sensor - Mother Plant Room
    await addDevice(SensorDeviceConfig(
      id: 'soil_sensor_mother_01',
      name: 'Soil Sensor - Mother Room',
      roomId: 'mother_room_1',
      type: SensorType.soil,
      ranges: {
        'soilMoisture': 100.0,
        'soilTemperature': 40.0,
        'soilPh': 14.0,
        'ec': 5.0,
      },
      currentValues: {
        'soilMoisture': 70.0,
        'soilTemperature': 23.0,
        'soilPh': 6.2,
        'ec': 1.8,
      },
      updateInterval: Duration(seconds: 15),
    ));

    _logger.d('Created ${_devices.length} default sensor devices');
  }

  void dispose() {
    stop();
    _devices.clear();
    _patterns.clear();
    _logger.d('Sensor simulator disposed');
  }
}

/// Global sensor simulator instance
final sensorSimulator = SensorSimulator();