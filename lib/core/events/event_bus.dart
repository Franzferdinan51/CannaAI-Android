import 'dart:async';
import 'dart:collection';
import 'package:logger/logger.dart';

/// Local event types for real-time communication
enum EventType {
  // Sensor events
  sensorDataUpdated,
  sensorAlert,
  sensorConnected,
  sensorDisconnected,

  // Automation events
  automationTriggered,
  automationCompleted,
  automationFailed,
  scheduleUpdated,

  // Analysis events
  analysisCompleted,
  analysisFailed,
  plantHealthUpdated,

  // System events
  systemStatusChanged,
  notificationTriggered,
  dataSynced,
  backgroundTaskCompleted,

  // UI events
  navigationRequested,
  refreshRequested,
  settingsChanged,
}

/// Base event class
abstract class AppEvent {
  final String id;
  final EventType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  AppEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson();
}

/// Sensor data update event
class SensorDataEvent extends AppEvent {
  final String deviceId;
  final String roomId;
  final Map<String, dynamic> sensorData;

  SensorDataEvent({
    required this.deviceId,
    required this.roomId,
    required this.sensorData,
    String? id,
    Map<String, dynamic>? metadata,
  }) : super(
    id: id ?? _generateId(),
    type: EventType.sensorDataUpdated,
    timestamp: DateTime.now(),
    metadata: metadata,
  );

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
      'roomId': roomId,
      'sensorData': sensorData,
      'metadata': metadata,
    };
  }
}

/// Sensor alert event
class SensorAlertEvent extends AppEvent {
  final String deviceId;
  final String roomId;
  final String alertType;
  final String severity;
  final String message;
  final String? recommendation;

  SensorAlertEvent({
    required this.deviceId,
    required this.roomId,
    required this.alertType,
    required this.severity,
    required this.message,
    this.recommendation,
    String? id,
    Map<String, dynamic>? metadata,
  }) : super(
    id: id ?? _generateId(),
    type: EventType.sensorAlert,
    timestamp: DateTime.now(),
    metadata: metadata,
  );

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
      'roomId': roomId,
      'alertType': alertType,
      'severity': severity,
      'message': message,
      'recommendation': recommendation,
      'metadata': metadata,
    };
  }
}

/// Automation trigger event
class AutomationEvent extends AppEvent {
  final String automationId;
  final String roomId;
  final String action;
  final bool success;
  final String? errorMessage;

  AutomationEvent({
    required this.automationId,
    required this.roomId,
    required this.action,
    required this.success,
    this.errorMessage,
    String? id,
    Map<String, dynamic>? metadata,
  }) : super(
    id: id ?? _generateId(),
    type: success ? EventType.automationTriggered : EventType.automationFailed,
    timestamp: DateTime.now(),
    metadata: metadata,
  );

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'timestamp': timestamp.toIso8601String(),
      'automationId': automationId,
      'roomId': roomId,
      'action': action,
      'success': success,
      'errorMessage': errorMessage,
      'metadata': metadata,
    };
  }
}

/// Notification event
class NotificationEvent extends AppEvent {
  final String title;
  final String body;
  final String? channelId;
  final Map<String, String>? payload;

  NotificationEvent({
    required this.title,
    required this.body,
    this.channelId,
    this.payload,
    String? id,
    Map<String, dynamic>? metadata,
  }) : super(
    id: id ?? _generateId(),
    type: EventType.notificationTriggered,
    timestamp: DateTime.now(),
    metadata: metadata,
  );

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'body': body,
      'channelId': channelId,
      'payload': payload,
      'metadata': metadata,
    };
  }
}

String _generateId() {
  return DateTime.now().millisecondsSinceEpoch.toString() +
         '_' + (DateTime.now().microsecond % 10000).toString();
}

/// Event subscription wrapper
class EventSubscription {
  final StreamSubscription<AppEvent> subscription;
  final EventType? eventType;
  final String? deviceId;
  final String? roomId;

  EventSubscription({
    required this.subscription,
    this.eventType,
    this.deviceId,
    this.roomId,
  });

  void cancel() {
    subscription.cancel();
  }
}

/// Local event bus for real-time communication
class LocalEventBus {
  static final LocalEventBus _instance = LocalEventBus._internal();
  factory LocalEventBus() => _instance;
  LocalEventBus._internal();

  final Logger _logger = Logger();
  final StreamController<AppEvent> _controller =
      StreamController<AppEvent>.broadcast();
  final Map<EventType, List<Function(AppEvent)>> _listeners = {};
  final Map<String, List<Function(AppEvent)>> _deviceListeners = {};
  final Map<String, List<Function(AppEvent)>> _roomListeners = {};
  final List<AppEvent> _eventHistory = [];
  final int _maxHistorySize = 1000;

  /// Main event stream
  Stream<AppEvent> get eventStream => _controller.stream;

  /// Event history for debugging and replay
  List<AppEvent> get eventHistory => List.unmodifiable(_eventHistory);

  /// Publish an event to the bus
  void emit(AppEvent event) {
    try {
      // Add to history
      _addToHistory(event);

      // Add to main stream
      _controller.add(event);

      // Notify specific listeners
      _notifyListeners(event);

      _logger.d('Event emitted: ${event.type} - ${event.id}');
    } catch (e) {
      _logger.e('Error emitting event: $e');
    }
  }

  /// Subscribe to all events
  EventSubscription subscribe(void Function(AppEvent) onData) {
    final subscription = eventStream.listen(onData);
    return EventSubscription(subscription: subscription);
  }

  /// Subscribe to specific event type
  EventSubscription subscribeToType(
    EventType type,
    void Function(AppEvent) onData,
  ) {
    final subscription = eventStream
        .where((event) => event.type == type)
        .listen(onData);
    return EventSubscription(subscription: subscription, eventType: type);
  }

  /// Subscribe to events from specific device
  EventSubscription subscribeToDevice(
    String deviceId,
    void Function(AppEvent) onData,
  ) {
    final subscription = eventStream
        .where((event) => _getDeviceId(event) == deviceId)
        .listen(onData);
    return EventSubscription(subscription: subscription, deviceId: deviceId);
  }

  /// Subscribe to events from specific room
  EventSubscription subscribeToRoom(
    String roomId,
    void Function(AppEvent) onData,
  ) {
    final subscription = eventStream
        .where((event) => _getRoomId(event) == roomId)
        .listen(onData);
    return EventSubscription(subscription: subscription, roomId: roomId);
  }

  /// Subscribe with multiple filters
  EventSubscription subscribeWithFilters({
    EventType? eventType,
    String? deviceId,
    String? roomId,
    required void Function(AppEvent) onData,
  }) {
    Stream<AppEvent> filteredStream = eventStream;

    if (eventType != null) {
      filteredStream = filteredStream.where((e) => e.type == eventType);
    }
    if (deviceId != null) {
      filteredStream = filteredStream.where((e) => _getDeviceId(e) == deviceId);
    }
    if (roomId != null) {
      filteredStream = filteredStream.where((e) => _getRoomId(e) == roomId);
    }

    final subscription = filteredStream.listen(onData);
    return EventSubscription(
      subscription: subscription,
      eventType: eventType,
      deviceId: deviceId,
      roomId: roomId,
    );
  }

  /// Add typed listener for performance optimization
  void addListener(EventType type, Function(AppEvent) listener) {
    _listeners.putIfAbsent(type, () => []).add(listener);
  }

  /// Remove typed listener
  void removeListener(EventType type, Function(AppEvent) listener) {
    _listeners[type]?.remove(listener);
  }

  /// Get recent events of specific type
  List<AppEvent> getRecentEvents(EventType type, {int limit = 50}) {
    return _eventHistory
        .where((event) => event.type == type)
        .take(limit)
        .toList()
        .reversed
        .toList();
  }

  /// Get recent events for specific device
  List<AppEvent> getRecentDeviceEvents(String deviceId, {int limit = 50}) {
    return _eventHistory
        .where((event) => _getDeviceId(event) == deviceId)
        .take(limit)
        .toList()
        .reversed
        .toList();
  }

  /// Get recent events for specific room
  List<AppEvent> getRecentRoomEvents(String roomId, {int limit = 50}) {
    return _eventHistory
        .where((event) => _getRoomId(event) == roomId)
        .take(limit)
        .toList()
        .reversed
        .toList();
  }

  /// Clear event history
  void clearHistory() {
    _eventHistory.clear();
    _logger.d('Event history cleared');
  }

  /// Dispose the event bus
  void dispose() {
    _controller.close();
    _listeners.clear();
    _deviceListeners.clear();
    _roomListeners.clear();
    _eventHistory.clear();
    _logger.d('LocalEventBus disposed');
  }

  void _addToHistory(AppEvent event) {
    _eventHistory.add(event);
    if (_eventHistory.length > _maxHistorySize) {
      _eventHistory.removeAt(0);
    }
  }

  void _notifyListeners(AppEvent event) {
    // Notify type listeners
    final typeListeners = _listeners[event.type];
    if (typeListeners != null) {
      for (final listener in typeListeners) {
        try {
          listener(event);
        } catch (e) {
          _logger.e('Error in event listener: $e');
        }
      }
    }

    // Notify device listeners
    final deviceId = _getDeviceId(event);
    if (deviceId != null) {
      final deviceListeners = _deviceListeners[deviceId];
      if (deviceListeners != null) {
        for (final listener in deviceListeners) {
          try {
            listener(event);
          } catch (e) {
            _logger.e('Error in device listener: $e');
          }
        }
      }
    }

    // Notify room listeners
    final roomId = _getRoomId(event);
    if (roomId != null) {
      final roomListeners = _roomListeners[roomId];
      if (roomListeners != null) {
        for (final listener in roomListeners) {
          try {
            listener(event);
          } catch (e) {
            _logger.e('Error in room listener: $e');
          }
        }
      }
    }
  }

  String? _getDeviceId(AppEvent event) {
    if (event is SensorDataEvent || event is SensorAlertEvent) {
      return event.deviceId;
    }
    if (event is AutomationEvent) {
      return event.automationId;
    }
    return event.metadata?['deviceId'] as String?;
  }

  String? _getRoomId(AppEvent event) {
    if (event is SensorDataEvent || event is SensorAlertEvent) {
      return event.roomId;
    }
    if (event is AutomationEvent) {
      return event.roomId;
    }
    return event.metadata?['roomId'] as String?;
  }
}

/// Global event bus instance
final eventBus = LocalEventBus();