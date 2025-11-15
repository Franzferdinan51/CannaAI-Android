import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import '../database/database_service.dart';
import '../events/event_bus.dart';
import 'real_time_streams.dart';
import '../constants/app_constants.dart';

/// Stream processing operators
enum StreamOperator {
  filter,
  map,
  buffer,
  debounce,
  throttle,
  merge,
  combineLatest,
  zip,
  distinct,
  scan,
  take,
  skip,
}

/// Data stream configuration
class DataStreamConfig {
  final String streamId;
  final StreamDataType sourceType;
  final Map<String, dynamic> filters;
  final List<StreamOperator> operators;
  final Duration? interval;
  final int? bufferSize;
  final bool enablePersistence;

  DataStreamConfig({
    required this.streamId,
    required this.sourceType,
    this.filters = const {},
    this.operators = const [],
    this.interval,
    this.bufferSize,
    this.enablePersistence = false,
  });
}

/// Stream processing stage
class StreamProcessingStage {
  final String id;
  final StreamOperator operator;
  final Map<String, dynamic> parameters;
  final String? description;

  StreamProcessingStage({
    required this.id,
    required this.operator,
    this.parameters = const {},
    this.description,
  });
}

/// Data stream pipeline
class DataStreamPipeline {
  final String id;
  final String name;
  final StreamDataType sourceType;
  final List<StreamProcessingStage> stages;
  final Stream<RealTimeDataPacket> inputStream;
  final StreamSubscription? subscription;
  final bool isActive;

  DataStreamPipeline({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.stages,
    required this.inputStream,
    this.subscription,
    this.isActive = false,
  });

  DataStreamPipeline copyWith({
    String? id,
    String? name,
    StreamDataType? sourceType,
    List<StreamProcessingStage>? stages,
    Stream<RealTimeDataPacket>? inputStream,
    StreamSubscription? subscription,
    bool? isActive,
  }) {
    return DataStreamPipeline(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceType: sourceType ?? this.sourceType,
      stages: stages ?? this.stages,
      inputStream: inputStream ?? this.inputStream,
      subscription: subscription ?? this.subscription,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Stream analytics data
class StreamAnalytics {
  final String streamId;
  final int totalEvents;
  final int eventsPerSecond;
  final double averageLatency;
  final int errorCount;
  final DateTime lastEventTime;
  final Map<String, dynamic> customMetrics;

  StreamAnalytics({
    required this.streamId,
    this.totalEvents = 0,
    this.eventsPerSecond = 0,
    this.averageLatency = 0.0,
    this.errorCount = 0,
    required this.lastEventTime,
    this.customMetrics = const {},
  });
}

/// Advanced data streaming architecture
class DataStreamingArchitecture {
  static final DataStreamingArchitecture _instance = DataStreamingArchitecture._internal();
  factory DataStreamingArchitecture() => _instance;
  DataStreamingArchitecture._internal();

  final Logger _logger = Logger();
  final Map<String, DataStreamPipeline> _pipelines = {};
  final Map<String, StreamController<RealTimeDataPacket>> _customStreams = {};
  final Map<String, StreamAnalytics> _analytics = {};
  final Map<String, Timer> _analyticsTimers = {};
  final Map<String, List<Function>> _streamSubscribers = {};
  bool _isInitialized = false;
  bool _isRunning = false;

  /// Current pipelines
  Map<String, DataStreamPipeline> get pipelines => Map.unmodifiable(_pipelines);

  /// Stream analytics
  Map<String, StreamAnalytics> get analytics => Map.unmodifiable(_analytics);

  /// Running status
  bool get isRunning => _isRunning;

  /// Initialize the streaming architecture
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create default pipelines
      await _createDefaultPipelines();

      _isInitialized = true;
      _logger.i('Data streaming architecture initialized');
    } catch (e) {
      _logger.e('Failed to initialize streaming architecture: $e');
    }
  }

  /// Start all pipelines
  Future<void> start() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isRunning) return;

    _isRunning = true;

    // Start all pipelines
    for (final pipeline in _pipelines.values) {
      await _startPipeline(pipeline);
    }

    // Start analytics collection
    _startAnalyticsCollection();

    _logger.i('Data streaming architecture started with ${_pipelines.length} pipelines');
  }

  /// Stop all pipelines
  Future<void> stop() async {
    _isRunning = false;

    // Stop all pipelines
    for (final pipeline in _pipelines.values) {
      await _stopPipeline(pipeline);
    }

    // Stop analytics collection
    for (final timer in _analyticsTimers.values) {
      timer.cancel();
    }
    _analyticsTimers.clear();

    _logger.i('Data streaming architecture stopped');
  }

  /// Create a new data stream pipeline
  Future<String> createPipeline(DataStreamConfig config) async {
    final pipelineId = config.streamId;

    try {
      // Create processing stages from config
      final stages = <StreamProcessingStage>[];

      for (final operator in config.operators) {
        stages.add(StreamProcessingStage(
          id: '${pipelineId}_${operator.toString()}',
          operator: operator,
          parameters: config.filters,
        ));
      }

      // Get input stream
      final inputStream = streamManager.getStream(config.sourceType);

      // Create pipeline
      final pipeline = DataStreamPipeline(
        id: pipelineId,
        name: 'Pipeline $pipelineId',
        sourceType: config.sourceType,
        stages: stages,
        inputStream: inputStream,
      );

      _pipelines[pipelineId] = pipeline;

      // Initialize analytics
      _analytics[pipelineId] = StreamAnalytics(
        streamId: pipelineId,
        lastEventTime: DateTime.now(),
      );

      // Start pipeline if system is running
      if (_isRunning) {
        await _startPipeline(pipeline);
      }

      _logger.d('Created pipeline: $pipelineId');
      return pipelineId;
    } catch (e) {
      _logger.e('Failed to create pipeline $pipelineId: $e');
      rethrow;
    }
  }

  /// Create a filtered data stream
  Stream<RealTimeDataPacket> createFilteredStream({
    required StreamDataType sourceType,
    required Map<String, dynamic> filters,
    String? streamId,
  }) {
    final id = streamId ?? 'filtered_${sourceType.toString()}_${DateTime.now().millisecondsSinceEpoch}';

    Stream<RealTimeDataPacket> stream = streamManager.getStream(sourceType);

    // Apply filters
    if (filters['roomId'] != null) {
      stream = stream.where((packet) => packet.metadata?['roomId'] == filters['roomId']);
    }

    if (filters['deviceId'] != null) {
      stream = stream.where((packet) => packet.source == filters['deviceId']);
    }

    if (filters['metric'] != null) {
      stream = stream.where((packet) => packet.metadata?['metric'] == filters['metric']);
    }

    if (filters['minValue'] != null) {
      stream = stream.where((packet) {
        if (packet.data is num) {
          return (packet.data as num) >= (filters['minValue'] as num);
        }
        return true;
      });
    }

    if (filters['maxValue'] != null) {
      stream = stream.where((packet) {
        if (packet.data is num) {
          return (packet.data as num) <= (filters['maxValue'] as num);
        }
        return true;
      });
    }

    return stream;
  }

  /// Create a combined stream from multiple sources
  Stream<RealTimeDataPacket> createCombinedStream(List<StreamDataType> sourceTypes, {String? streamId}) {
    final streams = sourceTypes.map((type) => streamManager.getStream(type)).toList();
    return Rx.merge(streams);
  }

  /// Create an aggregated stream (calculates statistics over time windows)
  Stream<Map<String, dynamic>> createAggregatedStream({
    required StreamDataType sourceType,
    required Duration windowDuration,
    required String metric,
    String? streamId,
  }) {
    final id = streamId ?? 'aggregated_${sourceType.toString()}_${metric}_${windowDuration.inMinutes}min';

    return streamManager.getStream(sourceType)
        .where((packet) => packet.metadata?['metric'] == metric)
        .map((packet) => packet.data as num)
        .bufferTime(windowDuration)
        .where((buffer) => buffer.isNotEmpty)
        .map((values) {
          return {
            'timestamp': DateTime.now().toIso8601String(),
            'metric': metric,
            'count': values.length,
            'sum': values.fold<double>(0, (sum, val) => sum + val.toDouble()),
            'average': values.fold<double>(0, (sum, val) => sum + val.toDouble()) / values.length,
            'min': values.fold<double>(double.infinity, (min, val) => math.min(min, val.toDouble())),
            'max': values.fold<double>(double.negativeInfinity, (max, val) => math.max(max, val.toDouble())),
          };
        });
  }

  /// Create a trend analysis stream
  Stream<Map<String, dynamic>> createTrendStream({
    required StreamDataType sourceType,
    required String metric,
    required Duration analysisPeriod,
    String? streamId,
  }) {
    final id = streamId ?? 'trend_${sourceType.toString()}_${metric}_${analysisPeriod.inHours}h';

    return streamManager.getStream(sourceType)
        .where((packet) => packet.metadata?['metric'] == metric)
        .map((packet) => packet.data as num)
        .bufferTime(analysisPeriod)
        .where((buffer) => buffer.length >= 10) // Need at least 10 data points
        .map((values) {
          // Simple linear regression for trend
          final n = values.length.toDouble();
          final sumX = values.fold<double>(0, (sum, _) => sum + values.indexOf(_).toDouble());
          final sumY = values.fold<double>(0, (sum, val) => sum + val.toDouble());
          final sumXY = values.asMap().entries.fold<double>(0, (sum, entry) {
            return sum + entry.key.toDouble() * entry.value.toDouble();
          });
          final sumX2 = values.asMap().keys.fold<double>(0, (sum, x) {
            return sum + x * x;
          });

          final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
          final intercept = (sumY - slope * sumX) / n;

          return {
            'timestamp': DateTime.now().toIso8601String(),
            'metric': metric,
            'period': analysisPeriod.inMinutes,
            'dataPoints': values.length,
            'trend': slope > 0.01 ? 'increasing' : slope < -0.01 ? 'decreasing' : 'stable',
            'slope': slope,
            'intercept': intercept,
            'currentValue': values.last.toDouble(),
            'predictedNext': slope * n + intercept,
          };
        });
  }

  /// Create a real-time alert stream with threshold monitoring
  Stream<RealTimeDataPacket<Map<String, dynamic>>> createAlertStream({
    required StreamDataType sourceType,
    required String metric,
    required double threshold,
    required String alertType,
    String? streamId,
  }) {
    final id = streamId ?? 'alert_${sourceType.toString()}_${metric}';

    return streamManager.getStream(sourceType)
        .where((packet) => packet.metadata?['metric'] == metric)
        .map((packet) => packet.data as num)
        .distinct()
        .where((value) => value >= threshold)
        .map((value) => RealTimeDataPacket<Map<String, dynamic>>(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: StreamDataType.sensorAlerts,
          data: {
            'alertType': alertType,
            'metric': metric,
            'value': value,
            'threshold': threshold,
            'severity': _calculateSeverity(value, threshold),
            'timestamp': DateTime.now().toIso8601String(),
          },
          timestamp: DateTime.now(),
          source: 'alert_system',
        ));
  }

  /// Subscribe to stream events
  void subscribeToStream(String streamId, Function(RealTimeDataPacket) callback) {
    _streamSubscribers.putIfAbsent(streamId, () => []).add(callback);
  }

  /// Unsubscribe from stream events
  void unsubscribeFromStream(String streamId, Function(RealTimeDataPacket) callback) {
    _streamSubscribers[streamId]?.remove(callback);
    if (_streamSubscribers[streamId]?.isEmpty == true) {
      _streamSubscribers.remove(streamId);
    }
  }

  /// Get pipeline performance metrics
  Map<String, dynamic> getPipelineMetrics() {
    final metrics = <String, dynamic>{};

    for (final entry in _analytics.entries) {
      final pipelineId = entry.key;
      final analytics = entry.value;

      metrics[pipelineId] = {
        'totalEvents': analytics.totalEvents,
        'eventsPerSecond': analytics.eventsPerSecond,
        'averageLatency': analytics.averageLatency,
        'errorCount': analytics.errorCount,
        'lastEventTime': analytics.lastEventTime.toIso8601String(),
        'customMetrics': analytics.customMetrics,
      };
    }

    return metrics;
  }

  /// Export stream data to local storage
  Future<void> exportStreamData(String streamId, Duration period) async {
    try {
      final endTime = DateTime.now();
      final startTime = endTime.subtract(period);

      // Get data from database or memory
      final data = await _getStreamDataFromDatabase(streamId, startTime, endTime);

      // Save to local file
      await _saveStreamDataToFile(streamId, data);

      _logger.d('Exported ${data.length} records for stream $streamId');
    } catch (e) {
      _logger.e('Failed to export stream data for $streamId: $e');
    }
  }

  Future<void> _startPipeline(DataStreamPipeline pipeline) async {
    try {
      Stream<RealTimeDataPacket> processedStream = pipeline.inputStream;

      // Apply processing stages
      for (final stage in pipeline.stages) {
        processedStream = _applyStreamOperator(processedStream, stage);
      }

      // Subscribe to processed stream
      final subscription = processedStream.listen(
        (packet) {
          _handlePipelineOutput(pipeline.id, packet);
        },
        onError: (error) {
          _handlePipelineError(pipeline.id, error);
        },
        onDone: () {
          _handlePipelineDone(pipeline.id);
        },
      );

      // Update pipeline
      _pipelines[pipeline.id] = pipeline.copyWith(
        subscription: subscription,
        isActive: true,
      );

      _logger.d('Started pipeline: ${pipeline.name}');
    } catch (e) {
      _logger.e('Failed to start pipeline ${pipeline.id}: $e');
    }
  }

  Future<void> _stopPipeline(DataStreamPipeline pipeline) async {
    try {
      await pipeline.subscription?.cancel();

      _pipelines[pipeline.id] = pipeline.copyWith(
        subscription: null,
        isActive: false,
      );

      _logger.d('Stopped pipeline: ${pipeline.name}');
    } catch (e) {
      _logger.e('Failed to stop pipeline ${pipeline.id}: $e');
    }
  }

  Stream<RealTimeDataPacket> _applyStreamOperator(
    Stream<RealTimeDataPacket> stream,
    StreamProcessingStage stage,
  ) {
    switch (stage.operator) {
      case StreamOperator.filter:
        final filterFn = stage.parameters['filter'] as bool Function(RealTimeDataPacket)?;
        return stream.where(filterFn ?? (_) => true);

      case StreamOperator.map:
        final mapFn = stage.parameters['mapper'] as RealTimeDataPacket Function(RealTimeDataPacket)?;
        return stream.map(mapFn ?? (packet) => packet);

      case StreamOperator.buffer:
        final duration = Duration(milliseconds: stage.parameters['duration'] ?? 1000);
        final count = stage.parameters['count'] as int?;
        return stream.bufferTime(duration, count: count ?? 100);

      case StreamOperator.debounce:
        final duration = Duration(milliseconds: stage.parameters['duration'] ?? 500);
        return stream.debounceTime(duration);

      case StreamOperator.throttle:
        final duration = Duration(milliseconds: stage.parameters['duration'] ?? 500);
        return stream.throttleTime(duration);

      case StreamOperator.distinct:
        return stream.distinct();

      case StreamOperator.take:
        final count = stage.parameters['count'] as int? ?? 10;
        return stream.take(count);

      case StreamOperator.skip:
        final count = stage.parameters['count'] as int? ?? 0;
        return stream.skip(count);

      default:
        return stream;
    }
  }

  void _handlePipelineOutput(String pipelineId, RealTimeDataPacket packet) {
    try {
      // Update analytics
      _updatePipelineAnalytics(pipelineId, packet);

      // Notify subscribers
      final subscribers = _streamSubscribers[pipelineId];
      if (subscribers != null) {
        for (final callback in subscribers) {
          try {
            callback(packet);
          } catch (e) {
            _logger.e('Error in stream subscriber callback: $e');
          }
        }
      }

      // Emit to stream manager if needed
      streamManager.emitData(packet.type, packet.data, source: pipelineId);
    } catch (e) {
      _logger.e('Error handling pipeline output for $pipelineId: $e');
    }
  }

  void _handlePipelineError(String pipelineId, dynamic error) {
    _logger.e('Pipeline error in $pipelineId: $error');

    final analytics = _analytics[pipelineId];
    if (analytics != null) {
      _analytics[pipelineId] = StreamAnalytics(
        streamId: analytics.streamId,
        totalEvents: analytics.totalEvents,
        eventsPerSecond: analytics.eventsPerSecond,
        averageLatency: analytics.averageLatency,
        errorCount: analytics.errorCount + 1,
        lastEventTime: analytics.lastEventTime,
        customMetrics: analytics.customMetrics,
      );
    }
  }

  void _handlePipelineDone(String pipelineId) {
    _logger.d('Pipeline $pipelineId completed');
  }

  void _updatePipelineAnalytics(String pipelineId, RealTimeDataPacket packet) {
    final analytics = _analytics[pipelineId];
    if (analytics != null) {
      final now = DateTime.now();
      final timeDiff = now.difference(analytics.lastEventTime).inMilliseconds.toDouble();
      final latency = packet.timestamp.difference(now).inMilliseconds.abs().toDouble();

      _analytics[pipelineId] = StreamAnalytics(
        streamId: analytics.streamId,
        totalEvents: analytics.totalEvents + 1,
        eventsPerSecond: 1000.0 / timeDiff, // Approximate
        averageLatency: (analytics.averageLatency + latency) / 2,
        errorCount: analytics.errorCount,
        lastEventTime: now,
        customMetrics: analytics.customMetrics,
      );
    }
  }

  void _startAnalyticsCollection() {
    // Update analytics every 10 seconds
    _analyticsTimers['analytics_update'] = Timer.periodic(Duration(seconds: 10), (_) {
      if (!_isRunning) return;
      _updateAllAnalytics();
    });
  }

  void _updateAllAnalytics() {
    for (final pipelineId in _analytics.keys) {
      final analytics = _analytics[pipelineId]!;
      final now = DateTime.now();
      final timeSinceLastEvent = now.difference(analytics.lastEventTime);

      // Update events per second
      if (timeSinceLastEvent.inSeconds > 0) {
        final newEps = analytics.totalEvents / timeSinceLastEvent.inSeconds;
        _analytics[pipelineId] = StreamAnalytics(
          streamId: analytics.streamId,
          totalEvents: analytics.totalEvents,
          eventsPerSecond: newEps,
          averageLatency: analytics.averageLatency * 0.9, // Decay
          errorCount: analytics.errorCount,
          lastEventTime: analytics.lastEventTime,
          customMetrics: analytics.customMetrics,
        );
      }
    }
  }

  String _calculateSeverity(num value, double threshold) {
    final ratio = value / threshold;
    if (ratio >= 2.0) return 'critical';
    if (ratio >= 1.5) return 'high';
    if (ratio >= 1.2) return 'medium';
    return 'low';
  }

  Future<List<Map<String, dynamic>>> _getStreamDataFromDatabase(
    String streamId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      // This would integrate with your database service
      // For now, return simulated data
      final data = <Map<String, dynamic>>[];
      final random = Random();

      for (int i = 0; i < 100; i++) {
        data.add({
          'timestamp': startTime.add(Duration(seconds: i * 60)).toIso8601String(),
          'value': 20.0 + random.nextDouble() * 10.0,
          'metadata': {'streamId': streamId},
        });
      }

      return data;
    } catch (e) {
      _logger.e('Failed to get stream data from database: $e');
      return [];
    }
  }

  Future<void> _saveStreamDataToFile(String streamId, List<Map<String, dynamic>> data) async {
    try {
      final jsonData = json.encode({
        'streamId': streamId,
        'exportTime': DateTime.now().toIso8601String(),
        'recordCount': data.length,
        'data': data,
      });

      // This would save to a local file
      // For now, just log the size
      _logger.d('Exported ${jsonData.length} characters for stream $streamId');
    } catch (e) {
      _logger.e('Failed to save stream data to file: $e');
    }
  }

  Future<void> _createDefaultPipelines() async {
    // Temperature alert pipeline
    await createPipeline(DataStreamConfig(
      streamId: 'temperature_alert_pipeline',
      sourceType: StreamDataType.sensorMetrics,
      filters: {'metric': 'temperature'},
      operators: [StreamOperator.filter, StreamOperator.distinct],
    ));

    // Humidity monitoring pipeline
    await createPipeline(DataStreamConfig(
      streamId: 'humidity_monitor_pipeline',
      sourceType: StreamDataType.sensorMetrics,
      filters: {'metric': 'humidity'},
      operators: [StreamOperator.buffer, StreamOperator.map],
    ));

    // System status aggregation pipeline
    await createPipeline(DataStreamConfig(
      streamId: 'system_status_pipeline',
      sourceType: StreamDataType.systemStatus,
      operators: [StreamOperator.debounce, StreamOperator.distinct],
    ));

    _logger.d('Created ${_pipelines.length} default pipelines');
  }

  void dispose() {
    stop();

    // Dispose custom streams
    for (final controller in _customStreams.values) {
      controller.close();
    }
    _customStreams.clear();

    _pipelines.clear();
    _analytics.clear();
    _streamSubscribers.clear();

    _logger.d('Data streaming architecture disposed');
  }
}

/// Global streaming architecture instance
final streamingArchitecture = DataStreamingArchitecture();