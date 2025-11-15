import 'dart:async';
import 'dart:math';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import '../events/event_bus.dart';
import '../models/sensor_data.dart';
import '../constants/app_constants.dart';

/// Stream data types
enum StreamDataType {
  sensorMetrics,
  sensorAlerts,
  automationStatus,
  systemStatus,
  analysisResults,
  chartData,
  statistics,
}

/// Real-time data packet
class RealTimeDataPacket<T> {
  final String id;
  final StreamDataType type;
  final T data;
  final DateTime timestamp;
  final String? source;
  final Map<String, dynamic>? metadata;

  RealTimeDataPacket({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.source,
    this.metadata,
  });

  RealTimeDataPacket<T> copyWith({
    String? id,
    StreamDataType? type,
    T? data,
    DateTime? timestamp,
    String? source,
    Map<String, dynamic>? metadata,
  }) {
    return RealTimeDataPacket<T>(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Chart data point
class ChartDataPoint {
  final DateTime timestamp;
  final double value;
  final String? label;
  final Map<String, dynamic>? metadata;

  ChartDataPoint({
    required this.timestamp,
    required this.value,
    this.label,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'value': value,
      'label': label,
      'metadata': metadata,
    };
  }
}

/// Real-time chart data
class RealTimeChartData {
  final String metric;
  final String roomId;
  final List<ChartDataPoint> dataPoints;
  final int maxDataPoints;
  final Duration updateInterval;

  RealTimeChartData({
    required this.metric,
    required this.roomId,
    List<ChartDataPoint>? dataPoints,
    this.maxDataPoints = AppConstants.maxDataPoints,
    this.updateInterval = AppConstants.chartUpdateInterval,
  }) : dataPoints = dataPoints ?? [];

  void addDataPoint(ChartDataPoint point) {
    dataPoints.add(point);
    if (dataPoints.length > maxDataPoints) {
      dataPoints.removeAt(0);
    }
  }

  List<ChartDataPoint> get recentData {
    return dataPoints.take(50).toList();
  }

  double? get latestValue {
    return dataPoints.isNotEmpty ? dataPoints.last.value : null;
  }

  double get averageValue {
    if (dataPoints.isEmpty) return 0.0;
    final sum = dataPoints.fold<double>(0.0, (prev, point) => prev + point.value);
    return sum / dataPoints.length;
  }

  double get minValue {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((p) => p.value).reduce(min);
  }

  double get maxValue {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((p) => p.value).reduce(max);
  }
}

/// Stream configuration
class StreamConfig {
  final StreamDataType type;
  final Duration updateInterval;
  final int bufferSize;
  final bool enableCompression;
  final Map<String, dynamic>? filters;

  StreamConfig({
    required this.type,
    this.updateInterval = const Duration(seconds: 1),
    this.bufferSize = 100,
    this.enableCompression = false,
    this.filters,
  });
}

/// Real-time stream manager
class RealTimeStreamManager {
  static final RealTimeStreamManager _instance = RealTimeStreamManager._internal();
  factory RealTimeStreamManager() => _instance;
  RealTimeStreamManager._internal();

  final Logger _logger = Logger();
  final Map<StreamDataType, StreamController<RealTimeDataPacket>> _controllers = {};
  final Map<String, RealTimeChartData> _chartData = {};
  final Map<StreamDataType, StreamConfig> _configs = {};
  final Map<String, Timer> _timers = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  bool _isInitialized = false;
  bool _isRunning = false;

  /// Initialization status
  bool get isInitialized => _isInitialized;

  /// Running status
  bool get isRunning => _isRunning;

  /// Get stream for specific data type
  Stream<RealTimeDataPacket> getStream(StreamDataType type) {
    _ensureController(type);
    return _controllers[type]!.stream;
  }

  /// Get typed stream for sensor data
  Stream<RealTimeDataPacket<SensorData>> getSensorDataStream() {
    return getStream(StreamDataType.sensorMetrics)
        .where((packet) => packet.data is SensorData)
        .cast<RealTimeDataPacket<SensorData>>();
  }

  /// Get typed stream for alerts
  Stream<RealTimeDataPacket<SensorAlert>> getAlertStream() {
    return getStream(StreamDataType.sensorAlerts)
        .where((packet) => packet.data is SensorAlert)
        .cast<RealTimeDataPacket<SensorAlert>>();
  }

  /// Get typed stream for chart data
  Stream<RealTimeDataPacket<RealTimeChartData>> getChartStream() {
    return getStream(StreamDataType.chartData)
        .where((packet) => packet.data is RealTimeChartData)
        .cast<RealTimeDataPacket<RealTimeChartData>>();
  }

  /// Get chart data for specific metric and room
  RealTimeChartData? getChartData(String metric, String roomId) {
    final key = '${metric}_$roomId';
    return _chartData[key];
  }

  /// Initialize the stream manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create default stream configurations
      await _createDefaultConfigs();

      // Initialize controllers
      for (final type in StreamDataType.values) {
        _ensureController(type);
      }

      // Subscribe to event bus
      _subscribeToEvents();

      _isInitialized = true;
      _logger.i('Real-time stream manager initialized');
    } catch (e) {
      _logger.e('Failed to initialize stream manager: $e');
    }
  }

  /// Start all streams
  Future<void> start() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isRunning) return;

    _isRunning = true;

    // Start periodic data generation
    _startPeriodicUpdates();

    _logger.i('Real-time stream manager started');
  }

  /// Stop all streams
  Future<void> stop() async {
    _isRunning = false;

    // Cancel all timers
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();

    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    _logger.i('Real-time stream manager stopped');
  }

  /// Emit data to a stream
  void emitData<T>(StreamDataType type, T data, {String? source, Map<String, dynamic>? metadata}) {
    if (!_isRunning) return;

    final controller = _controllers[type];
    if (controller != null && !controller.isClosed) {
      final packet = RealTimeDataPacket<T>(
        id: _generateId(),
        type: type,
        data: data,
        timestamp: DateTime.now(),
        source: source,
        metadata: metadata,
      );

      controller.add(packet);
    }
  }

  /// Update chart data
  void updateChartData(String metric, String roomId, double value, {String? label}) {
    final key = '${metric}_$roomId';
    var chartData = _chartData[key];

    if (chartData == null) {
      chartData = RealTimeChartData(
        metric: metric,
        roomId: roomId,
        updateInterval: _configs[StreamDataType.chartData]?.updateInterval ?? Duration(seconds: 5),
      );
      _chartData[key] = chartData;
    }

    final dataPoint = ChartDataPoint(
      timestamp: DateTime.now(),
      value: value,
      label: label,
    );

    chartData.addDataPoint(dataPoint);

    // Emit chart data update
    emitData(StreamDataType.chartData, chartData, source: 'chart_updater');

    // Also emit individual metric update
    emitData(StreamDataType.sensorMetrics, value, source: 'chart_updater', metadata: {
      'metric': metric,
      'roomId': roomId,
      'value': value,
      'timestamp': dataPoint.timestamp.millisecondsSinceEpoch,
    });
  }

  /// Create a combined stream from multiple streams
  Stream<RealTimeDataPacket> combineStreams(List<StreamDataType> types) {
    final streams = types.map((type) => getStream(type)).toList();
    return Rx.merge(streams);
  }

  /// Create a filtered stream
  Stream<RealTimeDataPacket> createFilteredStream(
    StreamDataType type,
    bool Function(RealTimeDataPacket) filter,
  ) {
    return getStream(type).where(filter);
  }

  /// Create a debounced stream (reduces frequency of updates)
  Stream<RealTimeDataPacket> createDebouncedStream(
    StreamDataType type,
    Duration duration,
  ) {
    return getStream(type).debounceTime(duration);
  }

  /// Create a throttled stream (limits frequency of updates)
  Stream<RealTimeDataPacket> createThrottledStream(
    StreamDataType type,
    Duration duration,
  ) {
    return getStream(type).throttleTime(duration);
  }

  /// Create a buffered stream that emits batches
  Stream<List<RealTimeDataPacket>> createBufferedStream(
    StreamDataType type,
    Duration duration, {
    int maxSize = 50,
  }) {
    return getStream(type)
        .bufferTime(duration, count: maxSize)
        .where((batch) => batch.isNotEmpty);
  }

  /// Get recent stream statistics
  Map<String, dynamic> getStreamStatistics() {
    final stats = <String, dynamic>{};

    for (final type in StreamDataType.values) {
      final controller = _controllers[type];
      if (controller != null) {
        stats[type.toString()] = {
          'isClosed': controller.isClosed,
          'hasListener': controller.hasListener,
          'streamConfig': _configs[type]?.toString(),
        };
      }
    }

    stats['chartDataCount'] = _chartData.length;
    stats['activeTimers'] = _timers.length;
    stats['activeSubscriptions'] = _subscriptions.length;

    return stats;
  }

  void _ensureController(StreamDataType type) {
    _controllers.putIfAbsent(type, () {
      final config = _configs[type];
      return StreamController<RealTimeDataPacket>.broadcast(
        sync: false,
        onListen: () {
          _logger.d('Stream listener added for type: $type');
        },
        onCancel: () {
          _logger.d('Stream listener removed for type: $type');
        },
      );
    });
  }

  void _subscribeToEvents() {
    // Listen to sensor data events
    _subscriptions['sensor_data'] = eventBus.subscribeToType(
      EventType.sensorDataUpdated,
      (event) {
        if (event is SensorDataEvent) {
          final sensorData = SensorData.fromJson(event.sensorData);
          emitData(
            StreamDataType.sensorMetrics,
            sensorData,
            source: event.deviceId,
            metadata: {
              'roomId': event.roomId,
              'deviceId': event.deviceId,
            },
          );

          // Update chart data for each metric
          _updateChartDataFromSensor(sensorData);
        }
      },
    );

    // Listen to sensor alert events
    _subscriptions['sensor_alerts'] = eventBus.subscribeToType(
      EventType.sensorAlert,
      (event) {
        if (event is SensorAlertEvent) {
          final alert = SensorAlert(
            id: event.id,
            deviceId: event.deviceId,
            roomId: event.roomId,
            alertType: event.alertType,
            severity: event.severity,
            message: event.message,
            recommendation: event.recommendation,
            timestamp: event.timestamp,
          );

          emitData(
            StreamDataType.sensorAlerts,
            alert,
            source: event.deviceId,
            metadata: {
              'roomId': event.roomId,
              'alertType': event.alertType,
              'severity': event.severity,
            },
          );
        }
      },
    );

    // Listen to automation events
    _subscriptions['automation'] = eventBus.subscribeToType(
      EventType.automationTriggered,
      (event) {
        if (event is AutomationEvent) {
          emitData(
            StreamDataType.automationStatus,
            {
              'automationId': event.automationId,
              'roomId': event.roomId,
              'action': event.action,
              'success': event.success,
              'timestamp': event.timestamp.millisecondsSinceEpoch,
            },
            source: 'automation_system',
          );
        }
      },
    );
  }

  void _updateChartDataFromSensor(SensorData sensorData) {
    final metrics = sensorData.metrics;

    // Update temperature chart
    if (metrics.temperature != null) {
      updateChartData('temperature', sensorData.roomId, metrics.temperature!);
    }

    // Update humidity chart
    if (metrics.humidity != null) {
      updateChartData('humidity', sensorData.roomId, metrics.humidity!);
    }

    // Update pH chart
    if (metrics.ph != null) {
      updateChartData('ph', sensorData.roomId, metrics.ph!);
    }

    // Update EC chart
    if (metrics.ec != null) {
      updateChartData('ec', sensorData.roomId, metrics.ec!);
    }

    // Update CO2 chart
    if (metrics.co2 != null) {
      updateChartData('co2', sensorData.roomId, metrics.co2!);
    }

    // Update VPD chart
    if (metrics.vpd != null) {
      updateChartData('vpd', sensorData.roomId, metrics.vpd!);
    }

    // Update light intensity chart
    if (metrics.lightIntensity != null) {
      updateChartData('lightIntensity', sensorData.roomId, metrics.lightIntensity!);
    }

    // Update soil moisture chart
    if (metrics.soilMoisture != null) {
      updateChartData('soilMoisture', sensorData.roomId, metrics.soilMoisture!);
    }
  }

  void _startPeriodicUpdates() {
    // Start statistics stream updates
    _timers['statistics'] = Timer.periodic(Duration(seconds: 10), (_) {
      if (!_isRunning) return;
      _emitStatisticsUpdate();
    });

    // Start system status updates
    _timers['system_status'] = Timer.periodic(Duration(seconds: 30), (_) {
      if (!_isRunning) return;
      _emitSystemStatusUpdate();
    });

    // Start chart cleanup
    _timers['chart_cleanup'] = Timer.periodic(Duration(minutes: 5), (_) {
      if (!_isRunning) return;
      _cleanupChartData();
    });
  }

  void _emitStatisticsUpdate() {
    final stats = {
      'activeDevices': 5, // Simulated
      'activeAlerts': 2, // Simulated
      'dataPointsPerSecond': 8.5, // Simulated
      'systemUptime': DateTime.now().difference(DateTime.now().subtract(Duration(hours: 24))).inSeconds,
      'memoryUsage': _getSimulatedMemoryUsage(),
      'cpuUsage': _getSimulatedCpuUsage(),
    };

    emitData(
      StreamDataType.statistics,
      stats,
      source: 'system_monitor',
    );
  }

  void _emitSystemStatusUpdate() {
    final status = {
      'isHealthy': true,
      'lastUpdate': DateTime.now().toIso8601String(),
      'activeConnections': 3,
      'queueSize': 0,
      'errorRate': 0.02,
      'responseTime': 150, // milliseconds
    };

    emitData(
      StreamDataType.systemStatus,
      status,
      source: 'system_monitor',
    );
  }

  void _cleanupChartData() {
    for (final chartData in _chartData.values) {
      // Remove data points older than retention period
      final cutoffTime = DateTime.now().subtract(AppConstants.dataRetentionPeriod);
      chartData.dataPoints.removeWhere((point) => point.timestamp.isBefore(cutoffTime));
    }

    // Remove empty chart data
    _chartData.removeWhere((key, data) => data.dataPoints.isEmpty);
  }

  double _getSimulatedMemoryUsage() {
    final random = Random();
    return 60.0 + random.nextDouble() * 20.0; // 60-80%
  }

  double _getSimulatedCpuUsage() {
    final random = Random();
    return 20.0 + random.nextDouble() * 30.0; // 20-50%
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
           '_' + (Random().nextInt(10000)).toString();
  }

  Future<void> _createDefaultConfigs() async {
    _configs[StreamDataType.sensorMetrics] = StreamConfig(
      type: StreamDataType.sensorMetrics,
      updateInterval: Duration(seconds: 1),
      bufferSize: 500,
      enableCompression: false,
    );

    _configs[StreamDataType.sensorAlerts] = StreamConfig(
      type: StreamDataType.sensorAlerts,
      updateInterval: Duration.zero, // Event-driven
      bufferSize: 100,
      enableCompression: false,
    );

    _configs[StreamDataType.automationStatus] = StreamConfig(
      type: StreamDataType.automationStatus,
      updateInterval: Duration.zero, // Event-driven
      bufferSize: 200,
      enableCompression: false,
    );

    _configs[StreamDataType.systemStatus] = StreamConfig(
      type: StreamDataType.systemStatus,
      updateInterval: Duration(seconds: 30),
      bufferSize: 50,
      enableCompression: true,
    );

    _configs[StreamDataType.chartData] = StreamConfig(
      type: StreamDataType.chartData,
      updateInterval: Duration(seconds: 5),
      bufferSize: 100,
      enableCompression: false,
    );

    _configs[StreamDataType.statistics] = StreamConfig(
      type: StreamDataType.statistics,
      updateInterval: Duration(seconds: 10),
      bufferSize: 100,
      enableCompression: true,
    );

    _logger.d('Created ${_configs.length} default stream configurations');
  }

  void dispose() {
    stop();

    // Close all controllers
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();

    // Clear data
    _chartData.clear();
    _configs.clear();

    _logger.d('Real-time stream manager disposed');
  }
}

/// Global stream manager instance
final streamManager = RealTimeStreamManager();