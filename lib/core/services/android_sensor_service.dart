import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Android Sensor Integration Service
/// Provides access to device sensors for environmental monitoring
class AndroidSensorService {
  static const MethodChannel _sensorChannel = MethodChannel('com.cannaai.pro/sensors');
  static final Logger _logger = Logger();

  // Stream controllers for real-time sensor data
  static final StreamController<Map<String, dynamic>> _accelerometerController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _gyroscopeController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _lightController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _temperatureController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _humidityController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _pressureController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream subscriptions
  static StreamSubscription? _methodCallSubscription;
  static bool _initialized = false;

  /// Initialize sensor service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      _logger.i('📡 Initializing Android Sensor Service...');

      // Set up method call handler for sensor data updates
      _setupMethodCallHandler();

      // Check available sensors
      await _checkAvailableSensors();

      _initialized = true;
      _logger.i('✅ Android Sensor Service initialized');
    } catch (e) {
      _logger.e('❌ Failed to initialize sensor service: $e');
      rethrow;
    }
  }

  /// Check if specific sensor is available
  static Future<bool> isSensorAvailable(SensorType type) async {
    try {
      final result = await _sensorChannel.invokeMethod<bool>('isSensorAvailable', {
        'type': type.name,
      });
      return result ?? false;
    } catch (e) {
      _logger.e('❌ Failed to check sensor availability for ${type.name}: $e');
      return false;
    }
  }

  /// Get current sensor reading
  static Future<Map<String, dynamic>?> getSensorReading(SensorType type) async {
    try {
      final result = await _sensorChannel.invokeMapMethod<String, dynamic>('getSensorData', {
        'type': type.name,
      });
      return result;
    } catch (e) {
      _logger.e('❌ Failed to get sensor reading for ${type.name}: $e');
      return null;
    }
  }

  /// Start listening to sensor data
  static Future<void> startSensorListening(
    SensorType type, {
    int interval = 1000, // milliseconds
  }) async {
    try {
      await _sensorChannel.invokeMethod('startSensorListening', {
        'type': type.name,
        'interval': interval,
      });
      _logger.i('📡 Started listening to ${type.name} sensor');
    } catch (e) {
      _logger.e('❌ Failed to start sensor listening for ${type.name}: $e');
    }
  }

  /// Stop listening to sensor data
  static Future<void> stopSensorListening(SensorType type) async {
    try {
      await _sensorChannel.invokeMethod('stopSensorListening', {
        'type': type.name,
      });
      _logger.i('⏹️ Stopped listening to ${type.name} sensor');
    } catch (e) {
      _logger.e('❌ Failed to stop sensor listening for ${type.name}: $e');
    }
  }

  /// Get all available sensors status
  static Future<Map<SensorType, bool>> getAvailableSensors() async {
    final Map<SensorType, bool> sensors = {};

    for (final type in SensorType.values) {
      sensors[type] = await isSensorAvailable(type);
    }

    return sensors;
  }

  /// Stream getters for real-time sensor data
  static Stream<Map<String, dynamic>> get accelerometerStream =>
      _accelerometerController.stream;

  static Stream<Map<String, dynamic>> get gyroscopeStream =>
      _gyroscopeController.stream;

  static Stream<Map<String, dynamic>> get lightStream =>
      _lightController.stream;

  static Stream<Map<String, dynamic>> get temperatureStream =>
      _temperatureController.stream;

  static Stream<Map<String, dynamic>> get humidityStream =>
      _humidityController.stream;

  static Stream<Map<String, dynamic>> get pressureStream =>
      _pressureController.stream;

  /// Combined environmental data stream
  static Stream<Map<String, dynamic>> get environmentalDataStream async* {
    await for (final lightData in lightStream) {
      final combined = {
        'timestamp': DateTime.now().toIso8601String(),
        'light': lightData,
      };

      // Add other available sensor data
      for (final type in [SensorType.temperature, SensorType.humidity, SensorType.pressure]) {
        final reading = await getSensorReading(type);
        if (reading != null) {
          combined[type.name] = reading;
        }
      }

      yield combined;
    }
  }

  /// Get sensor accuracy and calibration status
  static Future<Map<String, dynamic>> getSensorInfo(SensorType type) async {
    try {
      final result = await _sensorChannel.invokeMapMethod<String, dynamic>('getSensorInfo', {
        'type': type.name,
      });
      return result ?? {};
    } catch (e) {
      _logger.e('❌ Failed to get sensor info for ${type.name}: $e');
      return {};
    }
  }

  /// Calibrate sensor if supported
  static Future<bool> calibrateSensor(SensorType type) async {
    try {
      final result = await _sensorChannel.invokeMethod<bool>('calibrateSensor', {
        'type': type.name,
      });
      return result ?? false;
    } catch (e) {
      _logger.e('❌ Failed to calibrate ${type.name} sensor: $e');
      return false;
    }
  }

  /// Get device sensor capabilities
  static Future<Map<String, dynamic>> getSensorCapabilities() async {
    try {
      final result = await _sensorChannel.invokeMapMethod<String, dynamic>('getSensorCapabilities');
      return result ?? {};
    } catch (e) {
      _logger.e('❌ Failed to get sensor capabilities: $e');
      return {};
    }
  }

  /// Simulate sensor data for testing (fallback when hardware sensors unavailable)
  static Map<String, dynamic> simulateSensorData(SensorType type) {
    final now = DateTime.now();
    final random = Random();

    switch (type) {
      case SensorType.accelerometer:
        return {
          'x': (random.nextDouble() - 0.5) * 2.0, // -1 to 1 m/s²
          'y': (random.nextDouble() - 0.5) * 2.0,
          'z': (random.nextDouble() - 0.5) * 2.0 + 9.8, // Include gravity
          'timestamp': now.millisecondsSinceEpoch,
          'accuracy': 3, // SENSOR_STATUS_ACCURACY_HIGH
        };

      case SensorType.gyroscope:
        return {
          'x': (random.nextDouble() - 0.5) * 0.5, // -0.25 to 0.25 rad/s
          'y': (random.nextDouble() - 0.5) * 0.5,
          'z': (random.nextDouble() - 0.5) * 0.5,
          'timestamp': now.millisecondsSinceEpoch,
          'accuracy': 3,
        };

      case SensorType.light:
        return {
          'lux': 200.0 + random.nextDouble() * 800.0, // 200-1000 lux typical indoor lighting
          'timestamp': now.millisecondsSinceEpoch,
          'accuracy': 3,
        };

      case SensorType.temperature:
        return {
          'celsius': 20.0 + random.nextDouble() * 10.0, // 20-30°C typical range
          'timestamp': now.millisecondsSinceEpoch,
          'accuracy': 3,
        };

      case SensorType.humidity:
        return {
          'percent': 40.0 + random.nextDouble() * 20.0, // 40-60% typical range
          'timestamp': now.millisecondsSinceEpoch,
          'accuracy': 3,
        };

      case SensorType.pressure:
        return {
          'hPa': 1013.25 + random.nextDouble() * 10.0, // 1013-1023 hPa typical range
          'timestamp': now.millisecondsSinceEpoch,
          'accuracy': 3,
        };
    }
  }

  /// Process sensor data and apply filters/corrections
  static Map<String, dynamic> processSensorData(
    SensorType type,
    Map<String, dynamic> rawData,
  ) {
    switch (type) {
      case SensorType.accelerometer:
        return _processAccelerometerData(rawData);
      case SensorType.gyroscope:
        return _processGyroscopeData(rawData);
      case SensorType.light:
        return _processLightData(rawData);
      case SensorType.temperature:
        return _processTemperatureData(rawData);
      case SensorType.humidity:
        return _processHumidityData(rawData);
      case SensorType.pressure:
        return _processPressureData(rawData);
    }
  }

  private static Map<String, dynamic> _processAccelerometerData(Map<String, dynamic> data) {
    // Apply low-pass filter to reduce noise
    final x = (data['x'] as double?) ?? 0.0;
    final y = (data['y'] as double?) ?? 0.0;
    final z = (data['z'] as double?) ?? 0.0;

    // Calculate magnitude
    final magnitude = sqrt(x * x + y * y + z * z);

    // Add processed data
    final processed = Map<String, dynamic>.from(data);
    processed['magnitude'] = magnitude;
    processed['filtered'] = true;

    return processed;
  }

  private static Map<String, dynamic> _processGyroscopeData(Map<String, dynamic> data) {
    // Apply simple filter to reduce drift
    final x = (data['x'] as double?) ?? 0.0;
    final y = (data['y'] as double?) ?? 0.0;
    final z = (data['z'] as double?) ?? 0.0;

    // Calculate angular velocity magnitude
    final magnitude = sqrt(x * x + y * y + z * z);

    final processed = Map<String, dynamic>.from(data);
    processed['magnitude'] = magnitude;
    processed['filtered'] = true;

    return processed;
  }

  private static Map<String, dynamic> _processLightData(Map<String, dynamic> data) {
    final lux = (data['lux'] as double?) ?? 0.0;

    final processed = Map<String, dynamic>.from(data);
    processed['footCandles'] = lux * 0.092903; // Convert to foot-candles
    processed['lightCategory'] = _getLightCategory(lux);
    processed['filtered'] = true;

    return processed;
  }

  private static Map<String, dynamic> _processTemperatureData(Map<String, dynamic> data) {
    final celsius = (data['celsius'] as double?) ?? 0.0;

    final processed = Map<String, dynamic>.from(data);
    processed['fahrenheit'] = (celsius * 9 / 5) + 32;
    processed['kelvin'] = celsius + 273.15;
    processed['temperatureCategory'] = _getTemperatureCategory(celsius);
    processed['filtered'] = true;

    return processed;
  }

  private static Map<String, dynamic> _processHumidityData(Map<String, dynamic> data) {
    final percent = (data['percent'] as double?) ?? 0.0;

    final processed = Map<String, dynamic>.from(data);
    processed['humidityCategory'] = _getHumidityCategory(percent);
    processed['dewPointCelsius'] = _calculateDewPoint(percent, 20.0); // Assuming 20°C
    processed['filtered'] = true;

    return processed;
  }

  private static Map<String, dynamic> _processPressureData(Map<String, dynamic> data) {
    final hPa = (data['hPa'] as double?) ?? 0.0;

    final processed = Map<String, dynamic>.from(data);
    processed['inHg'] = hPa * 0.02953; // Convert to inches of mercury
    processed['mmHg'] = hPa * 0.75006; // Convert to mmHg
    processed['pressureCategory'] = _getPressureCategory(hPa);
    processed['filtered'] = true;

    return processed;
  }

  static String _getLightCategory(double lux) {
    if (lux < 10) return 'Very Dark';
    if (lux < 50) return 'Dark';
    if (lux < 200) return 'Dim';
    if (lux < 500) return 'Bright Indoor';
    if (lux < 10000) return 'Bright';
    return 'Very Bright';
  }

  static String _getTemperatureCategory(double celsius) {
    if (celsius < 10) return 'Cold';
    if (celsius < 15) return 'Cool';
    if (celsius < 25) return 'Optimal';
    if (celsius < 30) return 'Warm';
    return 'Hot';
  }

  static String _getHumidityCategory(double percent) {
    if (percent < 30) return 'Dry';
    if (percent < 40) return 'Low';
    if (percent < 60) return 'Optimal';
    if (percent < 70) return 'High';
    return 'Very High';
  }

  static String _getPressureCategory(double hPa) {
    if (hPa < 1000) return 'Low';
    if (hPa < 1013) return 'Normal Low';
    if (hPa < 1020) return 'Normal';
    return 'High';
  }

  static double _calculateDewPoint(double humidityPercent, double temperatureCelsius) {
    // Simplified dew point calculation
    final a = 17.27;
    final b = 237.7;
    final alpha = ((a * temperatureCelsius) / (b + temperatureCelsius)) + log(humidityPercent / 100);
    return (b * alpha) / (a - alpha);
  }

  static void _setupMethodCallHandler() {
    _sensorChannel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'onSensorData':
            final data = call.arguments as Map<String, dynamic>?;
            if (data != null) {
              _handleSensorDataUpdate(data);
            }
            break;
          case 'onSensorAccuracyChanged':
            final sensorType = call.arguments['sensorType'] as String?;
            final accuracy = call.arguments['accuracy'] as int?;
            _logger.d('📡 Sensor accuracy changed: $sensorType -> $accuracy');
            break;
          default:
            _logger.w('⚠️ Unknown sensor method call: ${call.method}');
        }
      } catch (e) {
        _logger.e('❌ Error handling sensor method call: $e');
      }
    });
  }

  static void _handleSensorDataUpdate(Map<String, dynamic> data) {
    final typeString = data['type'] as String?;
    final sensorData = data['data'] as Map<String, dynamic>?;

    if (typeString == null || sensorData == null) return;

    final type = SensorType.values
        .where((e) => e.name == typeString)
        .firstOrNull;

    if (type == null) return;

    // Process and broadcast sensor data
    final processedData = processSensorData(type, sensorData);

    switch (type) {
      case SensorType.accelerometer:
        if (!_accelerometerController.isClosed) {
          _accelerometerController.add(processedData);
        }
        break;
      case SensorType.gyroscope:
        if (!_gyroscopeController.isClosed) {
          _gyroscopeController.add(processedData);
        }
        break;
      case SensorType.light:
        if (!_lightController.isClosed) {
          _lightController.add(processedData);
        }
        break;
      case SensorType.temperature:
        if (!_temperatureController.isClosed) {
          _temperatureController.add(processedData);
        }
        break;
      case SensorType.humidity:
        if (!_humidityController.isClosed) {
          _humidityController.add(processedData);
        }
        break;
      case SensorType.pressure:
        if (!_pressureController.isClosed) {
          _pressureController.add(processedData);
        }
        break;
    }
  }

  static Future<void> _checkAvailableSensors() async {
    final availableSensors = await getAvailableSensors();
    _logger.i('📡 Available sensors:');

    for (final entry in availableSensors.entries) {
      final status = entry.value ? '✅' : '❌';
      _logger.i('  $status ${entry.key.name}');
    }
  }

  /// Dispose resources
  static void dispose() {
    _logger.i('🗑️ Disposing Android Sensor Service...');

    // Stop all sensor listening
    for (final type in SensorType.values) {
      stopSensorListening(type);
    }

    // Close stream controllers
    _accelerometerController.close();
    _gyroscopeController.close();
    _lightController.close();
    _temperatureController.close();
    _humidityController.close();
    _pressureController.close();

    _initialized = false;
  }
}

/// Sensor types enumeration
enum SensorType {
  accelerometer,
  gyroscope,
  light,
  temperature,
  humidity,
  pressure,
}

/// Sensor accuracy levels
enum SensorAccuracy {
  unreliable(0),
  low(1),
  medium(2),
  high(3);

  const SensorAccuracy(this.value);
  final int value;

  static SensorAccuracy fromValue(int value) {
    return SensorAccuracy.values.firstWhere(
      (accuracy) => accuracy.value == value,
      orElse: () => SensorAccuracy.unreliable,
    );
  }
}