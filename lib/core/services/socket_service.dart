import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'local_sensor_service.dart';
import 'local_automation_service.dart';
import 'local_notification_service.dart';

// Local event service provider (replaces socket service)
final socketServiceProvider = Provider<LocalEventService>((ref) {
  return LocalEventService();
});

/// Local event service that replaces WebSocket functionality
/// Provides real-time event handling using local services
class LocalEventService {
  final Logger _logger = Logger();
  final LocalSensorService _sensorService = LocalSensorService();
  final LocalAutomationService _automationService = LocalAutomationService();
  final LocalNotificationService _notificationService = LocalNotificationService();

  bool _isConnected = true; // Always "connected" in offline mode
  final StreamController<Map<String, dynamic>> _sensorDataStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _automationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream subscriptions
  StreamSubscription? _sensorDataSubscription;
  StreamSubscription? _automationEventSubscription;

  // Connection ID for compatibility
  String? _connectionId;

  // Stream getters (maintain API compatibility)
  Stream<Map<String, dynamic>> get sensorDataStream =>
      _sensorDataStreamController.stream;
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;
  Stream<Map<String, dynamic>> get automationStream =>
      _automationStreamController.stream;

  bool get isConnected => _isConnected;

  /// Initialize local event service
  Future<void> connect({String? url}) async {
    try {
      if (_isConnected) {
        _logger.i('Local event service already "connected"');
        return;
      }

      _logger.i('Initializing local event service (offline mode)...');

      // Generate connection ID for compatibility
      _connectionId = 'local_${DateTime.now().millisecondsSinceEpoch}';

      // Subscribe to local service streams
      _subscribeToLocalServices();

      _isConnected = true;

      // Simulate connection event
      _notificationStreamController.add({
        'type': 'connection_established',
        'data': {
          'connection_id': _connectionId,
          'mode': 'offline',
          'message': 'Local event service initialized successfully',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });

      _logger.i('Local event service connected successfully');
    } catch (e) {
      _logger.e('Failed to initialize local event service: $e');
      rethrow;
    }
  }

  /// Subscribe to local service streams
  void _subscribeToLocalServices() {
    // Subscribe to sensor data updates
    _sensorDataSubscription = _sensorService.sensorDataStream.listen((data) {
      _logger.d('Received local sensor data: $data');

      // Forward to sensor data stream with format compatibility
      _sensorDataStreamController.add({
        'room_id': data['room_id'],
        'timestamp': data['timestamp'],
        'readings': data['readings'],
        'source': 'local_simulation',
        'connection_id': _connectionId,
      });
    });

    // Subscribe to automation events
    _automationEventSubscription = _automationService.automationEventStream.listen((data) {
      _logger.d('Received local automation event: $data');

      // Forward to automation stream
      _automationStreamController.add({
        ...data,
        'source': 'local_automation',
        'connection_id': _connectionId,
      });

      // Also forward as notification for important events
      if (data['event_type'] == 'emergency_action' ||
          data['event_type'] == 'automation_failed') {
        _notificationStreamController.add({
          'type': data['event_type'],
          'data': data,
          'source': 'local_automation',
          'connection_id': _connectionId,
        });
      }
    });
  }

  /// Disconnect from local event service
  void disconnect() {
    if (!_isConnected) return;

    _logger.i('Disconnecting local event service...');

    _sensorDataSubscription?.cancel();
    _automationEventSubscription?.cancel();

    _isConnected = false;
    _connectionId = null;

    // Simulate disconnection event
    _notificationStreamController.add({
      'type': 'connection_lost',
      'data': {
        'mode': 'offline',
        'message': 'Local event service disconnected',
        'timestamp': DateTime.now().toIso8601String(),
      },
    });

    _logger.i('Local event service disconnected');
  }

  // ==================== EVENT EMITTING ====================
  // These methods maintain API compatibility but work locally

  /// Emit event (local implementation)
  void emit(String event, dynamic data) {
    _logger.d('Emitting local event: $event with data: $data');

    // Route to appropriate local handler
    switch (event) {
      case 'join_room':
        _handleJoinRoom(data);
        break;
      case 'leave_room':
        _handleLeaveRoom(data);
        break;
      case 'subscribe_sensor':
        _handleSubscribeSensor(data);
        break;
      case 'get_room_status':
        _handleGetRoomStatus(data);
        break;
      case 'automation_command':
        _handleAutomationCommand(data);
        break;
      case 'sensor_data_update':
        _handleSensorDataUpdate(data);
        break;
      case 'ping':
        _handlePing(data);
        break;
      case 'heartbeat':
        _handleHeartbeat(data);
        break;
      default:
        _logger.w('Unhandled local event: $event');
    }
  }

  /// Handle join room event
  void _handleJoinRoom(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    if (roomId != null) {
      _logger.i('Joined local room: $roomId');

      _notificationStreamController.add({
        'type': 'room_joined',
        'data': {
          'room_id': roomId,
          'connection_id': _connectionId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    }
  }

  /// Handle leave room event
  void _handleLeaveRoom(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    if (roomId != null) {
      _logger.i('Left local room: $roomId');

      _notificationStreamController.add({
        'type': 'room_left',
        'data': {
          'room_id': roomId,
          'connection_id': _connectionId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    }
  }

  /// Handle subscribe to sensor data
  void _handleSubscribeSensor(Map<String, dynamic> data) {
    final deviceId = data['device_id'] as String?;
    if (deviceId != null) {
      _logger.i('Subscribed to local sensor: $deviceId');

      // In local mode, we're already subscribed to all sensor data
      _notificationStreamController.add({
        'type': 'sensor_subscribed',
        'data': {
          'device_id': deviceId,
          'connection_id': _connectionId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    }
  }

  /// Handle get room status
  void _handleGetRoomStatus(Map<String, dynamic> data) async {
    final roomId = data['room_id'] as String?;
    if (roomId != null) {
      try {
        final roomState = _sensorService.getRoomState(roomId);
        if (roomState != null) {
          final statusData = {
            'room_id': roomId,
            'is_active': roomState.isActive,
            'target_temperature': roomState.targetTemp,
            'target_humidity': roomState.targetHumidity,
            'target_ph': roomState.targetPh,
            'target_ec': roomState.targetEc,
            'target_co2': roomState.targetCo2,
            'current_temperature': roomState.currentTemp,
            'current_humidity': roomState.currentHumidity,
            'current_ph': roomState.currentPh,
            'current_ec': roomState.currentEc,
            'current_co2': roomState.currentCo2,
            'timestamp': DateTime.now().toIso8601String(),
          };

          _sensorDataStreamController.add({
            'type': 'room_status',
            'data': statusData,
            'source': 'local_query',
            'connection_id': _connectionId,
          });
        }
      } catch (e) {
        _logger.e('Failed to get room status: $e');
      }
    }
  }

  /// Handle automation command
  void _handleAutomationCommand(Map<String, dynamic> data) async {
    final deviceId = data['device_id'] as String?;
    final action = data['action'] as String?;
    final parameters = data['parameters'] as Map<String, dynamic>?;

    if (deviceId != null && action != null) {
      try {
        // Extract room ID from device ID (format: "room_deviceType")
        final roomId = deviceId.split('_')[0];

        await _automationService.triggerManualAction(
          roomId: roomId,
          deviceType: deviceId,
          action: action,
          parameters: parameters,
        );

        _logger.i('Executed local automation command: $action on $deviceId');
      } catch (e) {
        _logger.e('Failed to execute automation command: $e');
      }
    }
  }

  /// Handle sensor data update (manual input)
  void _handleSensorDataUpdate(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    final sensorData = data['data'] as Map<String, dynamic>?;

    if (roomId != null && sensorData != null) {
      _logger.i('Received manual sensor data update for room: $roomId');

      // Forward the manual sensor data
      _sensorDataStreamController.add({
        'type': 'manual_sensor_update',
        'room_id': roomId,
        'data': sensorData,
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'manual_input',
        'connection_id': _connectionId,
      });
    }
  }

  /// Handle ping event
  void _handlePing(Map<String, dynamic> data) {
    // Simulate pong response
    _notificationStreamController.add({
      'type': 'pong',
      'data': {
        'timestamp': DateTime.now().toIso8601String(),
        'connection_id': _connectionId,
      },
    });
  }

  /// Handle heartbeat event
  void _handleHeartbeat(Map<String, dynamic> data) {
    _logger.d('Received heartbeat');

    _notificationStreamController.add({
      'type': 'heartbeat_response',
      'data': {
        'timestamp': DateTime.now().toIso8601String(),
        'connection_id': _connectionId,
        'mode': 'offline',
      },
    });
  }

  // ==================== LEGACY COMPATIBILITY METHODS ====================
  // These methods maintain API compatibility

  void joinRoom(String roomId) {
    emit('join_room', {'room_id': roomId});
  }

  void leaveRoom(String roomId) {
    emit('leave_room', {'room_id': roomId});
  }

  void subscribeToSensorData(String deviceId) {
    emit('subscribe_sensor', {'device_id': deviceId});
  }

  void unsubscribeFromSensorData(String deviceId) {
    _logger.i('Unsubscribed from sensor: $deviceId (local mode - no action needed)');
  }

  void requestRoomStatus(String roomId) {
    emit('get_room_status', {'room_id': roomId});
  }

  void sendAutomationCommand({
    required String deviceId,
    required String action,
    Map<String, dynamic>? parameters,
  }) {
    emit('automation_command', {
      'device_id': deviceId,
      'action': action,
      'parameters': parameters ?? {},
    });
  }

  void requestSensorHistory({
    required String deviceId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    _logger.i('Sensor history request for $deviceId (use API service in local mode)');
  }

  void sendSensorData({
    required String roomId,
    required Map<String, dynamic> sensorData,
  }) {
    emit('sensor_data_update', {
      'room_id': roomId,
      'data': sensorData,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void acknowledgeNotification(String notificationId) {
    _logger.i('Notification acknowledged: $notificationId');
  }

  void requestSystemStatus() {
    emit('get_system_status', {});
  }

  void registerDevice({
    required String deviceId,
    required String deviceType,
    Map<String, dynamic>? deviceInfo,
  }) {
    _logger.i('Device registered locally: $deviceId ($deviceType)');
  }

  void unregisterDevice(String deviceId) {
    _logger.i('Device unregistered locally: $deviceId');
  }

  void updateDeviceSettings({
    required String deviceId,
    required Map<String, dynamic> settings,
  }) {
    _logger.i('Device settings updated locally: $deviceId');
  }

  void sendHeartbeat() {
    emit('heartbeat', {
      'timestamp': DateTime.now().toIso8601String(),
      'device_type': 'mobile_app',
    });
  }

  // Heartbeat management
  Timer? _heartbeatTimer;

  void startHeartbeat({Duration interval = const Duration(seconds: 30)}) {
    stopHeartbeat();
    _heartbeatTimer = Timer.periodic(interval, (_) {
      sendHeartbeat();
    });
    _logger.i('Local heartbeat started with ${interval.inSeconds}s interval');
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _logger.i('Local heartbeat stopped');
  }

  // ==================== UTILITY METHODS ====================

  /// Check connection status
  Future<bool> checkConnection() async {
    return _isConnected; // Always "connected" in offline mode
  }

  /// Get connection info
  Map<String, dynamic> getConnectionInfo() {
    return {
      'connected': _isConnected,
      'connection_id': _connectionId,
      'url': 'local://offline',
      'path': 'local_events',
      'mode': 'offline',
      'type': 'local_event_service',
    };
  }

  /// Get service statistics
  Map<String, dynamic> getServiceStats() {
    return {
      'connected': _isConnected,
      'connection_id': _connectionId,
      'mode': 'offline',
      'local_services_active': true,
      'sensor_stream_active': _sensorDataStreamController.hasListener,
      'notification_stream_active': _notificationStreamController.hasListener,
      'automation_stream_active': _automationStreamController.hasListener,
      'heartbeat_active': _heartbeatTimer?.isActive ?? false,
    };
  }

  /// Dispose of all resources
  void dispose() {
    stopHeartbeat();
    disconnect();

    _sensorDataStreamController.close();
    _notificationStreamController.close();
    _automationStreamController.close();

    _logger.i('Local event service disposed');
  }
}