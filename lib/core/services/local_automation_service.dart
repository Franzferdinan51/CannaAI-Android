import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:workmanager/workmanager.dart';
import '../constants/app_constants.dart';
import 'local_data_service.dart';
import 'local_sensor_service.dart';

/// Local automation service for plant management
/// Handles automated controls without requiring external servers
class LocalAutomationService {
  static final LocalAutomationService _instance = LocalAutomationService._internal();
  factory LocalAutomationService() => _instance;
  LocalAutomationService._internal();

  final Logger _logger = Logger();
  final Random _random = Random();
  final LocalDataService _dataService = LocalDataService();
  final LocalSensorService _sensorService = LocalSensorService();

  // Automation state
  bool _isRunning = false;
  Timer? _automationTimer;
  final Map<String, AutomationController> _controllers = {};

  // Stream controllers
  final StreamController<Map<String, dynamic>> _automationEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream getters
  Stream<Map<String, dynamic>> get automationEventStream => _automationEventController.stream;

  // WorkManager task callback
  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      try {
        // Initialize services for background execution
        final automationService = LocalAutomationService();
        await automationService.initialize();

        switch (task) {
          case 'sensor_automation':
            await automationService.processAutomationRules();
            break;
          case 'sensor_simulation':
            await automationService.simulateSensorData();
            break;
        }

        return Future.value(true);
      } catch (e) {
        return Future.value(false);
      }
    });
  }

  /// Initialize automation service
  Future<void> initialize() async {
    try {
      await _dataService.initialize();
      await _initializeControllers();
      await _setupBackgroundTasks();
      _startAutomationLoop();
      _isRunning = true;
      _logger.i('Local automation service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize automation service: $e');
      rethrow;
    }
  }

  /// Initialize automation controllers for different room types
  Future<void> _initializeControllers() async {
    final rooms = _sensorService.getAllRooms();

    for (final room in rooms) {
      final roomId = room['id'] as String;
      final isActive = room['is_active'] as bool;

      if (isActive) {
        _controllers[roomId] = AutomationController(
          roomId: roomId,
          roomName: room['name'] as String,
          settings: room,
        );

        // Load existing automation schedules
        await _loadAutomationSchedules(roomId);
      }
    }

    _logger.i('Initialized ${_controllers.length} automation controllers');
  }

  /// Load automation schedules for a room
  Future<void> _loadAutomationSchedules(String roomId) async {
    try {
      final schedules = await _dataService.getAutomationSchedules(
        roomId: roomId,
        enabledOnly: true,
      );

      final controller = _controllers[roomId];
      if (controller == null) return;

      for (final schedule in schedules) {
        controller.addSchedule(AutomationSchedule.fromDatabase(schedule));
      }

      _logger.i('Loaded ${schedules.length} automation schedules for room: $roomId');
    } catch (e) {
      _logger.e('Failed to load automation schedules for $roomId: $e');
    }
  }

  /// Setup background tasks using WorkManager
  Future<void> _setupBackgroundTasks() async {
    try {
      // Register background tasks
      await Workmanager().registerTask(
        'sensor_automation',
        callbackDispatcher,
        frequency: Duration(minutes: 15), // Check automation rules every 15 minutes
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresCharging: false,
          requiresDeviceIdle: false,
        ),
      );

      await Workmanager().registerTask(
        'sensor_simulation',
        callbackDispatcher,
        frequency: Duration(minutes: 5), // Simulate sensor data every 5 minutes
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresCharging: false,
          requiresDeviceIdle: false,
        ),
      );

      _logger.i('Background tasks registered successfully');
    } catch (e) {
      _logger.e('Failed to setup background tasks: $e');
    }
  }

  /// Start main automation loop
  void _startAutomationLoop() {
    _automationTimer?.cancel();
    _automationTimer = Timer.periodic(Duration(minutes: 5), (_) {
      processAutomationRules();
    });
    _logger.i('Automation loop started');
  }

  /// Process automation rules for all active rooms
  Future<void> processAutomationRules() async {
    if (!_isRunning) return;

    try {
      for (final controller in _controllers.values) {
        await _processRoomAutomation(controller);
      }
    } catch (e) {
      _logger.e('Error processing automation rules: $e');
    }
  }

  /// Process automation for a specific room
  Future<void> _processRoomAutomation(AutomationController controller) async {
    try {
      final roomState = _sensorService.getRoomState(controller.roomId);
      if (roomState == null || !roomState.isActive) return;

      final currentData = await _sensorService.getCurrentSensorData();
      final roomData = currentData[controller.roomId];

      if (roomData == null) return;

      // Process scheduled automation
      await _processScheduledAutomation(controller);

      // Process threshold-based automation
      await _processThresholdAutomation(controller, roomData);

      // Process time-based automation
      await _processTimeBasedAutomation(controller);

    } catch (e) {
      _logger.e('Error processing automation for room ${controller.roomId}: $e');
    }
  }

  /// Process scheduled automation (predefined schedules)
  Future<void> _processScheduledAutomation(AutomationController controller) async {
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final schedule in controller.schedules) {
      if (schedule.isActive && schedule.scheduleTime == currentTime) {
        await _executeAutomationAction(controller, schedule);
      }
    }
  }

  /// Process threshold-based automation (reactive)
  Future<void> _processThresholdAutomation(AutomationController controller, Map<String, dynamic> roomData) async {
    final roomState = _sensorService.getRoomState(controller.roomId);
    if (roomState == null) return;

    // Temperature control
    final tempData = roomData['temperature'];
    if (tempData != null) {
      final currentTemp = tempData['value'] as double;

      if (currentTemp > roomState.targetTemp + 2.0) {
        await _executeEmergencyAction(controller, 'cooling_system', 'turn_on');
      } else if (currentTemp < roomState.targetTemp - 2.0) {
        await _executeEmergencyAction(controller, 'heating_system', 'turn_on');
      }
    }

    // Humidity control
    final humidityData = roomData['humidity'];
    if (humidityData != null) {
      final currentHumidity = humidityData['value'] as double;

      if (currentHumidity > roomState.targetHumidity + 10.0) {
        await _executeEmergencyAction(controller, 'dehumidifier', 'turn_on');
        await _executeEmergencyAction(controller, 'exhaust_fan', 'turn_on');
      } else if (currentHumidity < roomState.targetHumidity - 10.0) {
        await _executeEmergencyAction(controller, 'humidifier', 'turn_on');
      }
    }

    // pH control
    final phData = roomData['ph'];
    if (phData != null) {
      final currentPh = phData['value'] as double;

      if (currentPh < roomState.targetPh - 0.3) {
        await _executeEmergencyAction(controller, 'ph_up', 'dose');
      } else if (currentPh > roomState.targetPh + 0.3) {
        await _executeEmergencyAction(controller, 'ph_down', 'dose');
      }
    }

    // CO2 control
    final co2Data = roomData['co2'];
    if (co2Data != null) {
      final currentCo2 = co2Data['value'] as double;

      if (currentCo2 < roomState.targetCo2 - 100.0) {
        await _executeEmergencyAction(controller, 'co2_generator', 'turn_on');
      } else if (currentCo2 > roomState.targetCo2 + 200.0) {
        await _executeEmergencyAction(controller, 'co2_generator', 'turn_off');
        await _executeEmergencyAction(controller, 'exhaust_fan', 'turn_on');
      }
    }

    // Light control (time-based)
    final hourOfDay = DateTime.now().hour;
    final isLightsOnTime = hourOfDay >= 6 && hourOfDay <= 18;

    if (isLightsOnTime) {
      await _executeEmergencyAction(controller, 'grow_lights', 'turn_on');
    } else {
      await _executeEmergencyAction(controller, 'grow_lights', 'turn_off');
    }
  }

  /// Process time-based automation
  Future<void> _processTimeBasedAutomation(AutomationController controller) async {
    final now = DateTime.now();
    final hourOfDay = now.hour;

    // Morning routine (6 AM)
    if (hourOfDay == 6 && now.minute == 0) {
      await _executeMorningRoutine(controller);
    }

    // Evening routine (6 PM)
    if (hourOfDay == 18 && now.minute == 0) {
      await _executeEveningRoutine(controller);
    }

    // Midnight routine (12 AM)
    if (hourOfDay == 0 && now.minute == 0) {
      await _executeMidnightRoutine(controller);
    }
  }

  /// Execute morning automation routine
  Future<void> _executeMorningRoutine(AutomationController controller) async {
    await _executeEmergencyAction(controller, 'grow_lights', 'turn_on');
    await _executeEmergencyAction(controller, 'circulation_fans', 'turn_on');

    // Check if watering is needed
    final moistureData = await _getLatestSensorReading(controller.roomId, 'soil_moisture');
    if (moistureData != null && moistureData['value'] < 50.0) {
      await _executeEmergencyAction(controller, 'watering_system', 'water');
    }

    _broadcastAutomationEvent(controller, 'morning_routine_completed', {
      'timestamp': DateTime.now().toIso8601String(),
      'actions': ['lights_on', 'fans_on', 'watering_if_needed'],
    });
  }

  /// Execute evening automation routine
  Future<void> _executeEveningRoutine(AutomationController controller) async {
    await _executeEmergencyAction(controller, 'grow_lights', 'turn_off');

    _broadcastAutomationEvent(controller, 'evening_routine_completed', {
      'timestamp': DateTime.now().toIso8601String(),
      'actions': ['lights_off'],
    });
  }

  /// Execute midnight automation routine
  Future<void> _executeMidnightRoutine(AutomationController controller) async {
    // Lower temperature during night
    await _executeEmergencyAction(controller, 'cooling_system', 'adjust_night_mode');

    _broadcastAutomationEvent(controller, 'midnight_routine_completed', {
      'timestamp': DateTime.now().toIso8601String(),
      'actions': ['night_mode_adjustments'],
    });
  }

  /// Execute automation action
  Future<void> _executeAutomationAction(AutomationController controller, AutomationSchedule schedule) async {
    try {
      final action = _simulateDeviceAction(schedule.deviceType, schedule.action);

      _broadcastAutomationEvent(controller, 'automation_executed', {
        'schedule_id': schedule.id,
        'device_type': schedule.deviceType,
        'action': schedule.action,
        'result': action,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _logger.i('Executed automation: ${schedule.deviceType} - ${schedule.action} in ${controller.roomId}');
    } catch (e) {
      _logger.e('Failed to execute automation action: $e');

      _broadcastAutomationEvent(controller, 'automation_failed', {
        'schedule_id': schedule.id,
        'device_type': schedule.deviceType,
        'action': schedule.action,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Execute emergency automation action
  Future<void> _executeEmergencyAction(AutomationController controller, String deviceType, String action) async {
    try {
      final result = _simulateDeviceAction(deviceType, action);

      _broadcastAutomationEvent(controller, 'emergency_action', {
        'device_type': deviceType,
        'action': action,
        'result': result,
        'timestamp': DateTime.now().toIso8601String(),
        'trigger': 'threshold_based',
      });

      _logger.i('Executed emergency action: $deviceType - $action in ${controller.roomId}');
    } catch (e) {
      _logger.e('Failed to execute emergency action: $e');
    }
  }

  /// Simulate device action (offline implementation)
  Map<String, dynamic> _simulateDeviceAction(String deviceType, String action) {
    // Simulate realistic device responses
    final successProbability = _random.nextDouble();

    if (successProbability > 0.05) { // 95% success rate
      return {
        'success': true,
        'message': '$deviceType $action executed successfully',
        'execution_time': _random.nextInt(5) + 1, // 1-5 seconds
        'power_consumption': _getPowerConsumption(deviceType, action),
        'status': _getDeviceStatus(deviceType, action),
      };
    } else {
      return {
        'success': false,
        'message': 'Device temporarily unavailable',
        'error_code': 'DEVICE_OFFLINE',
        'retry_suggested': true,
      };
    }
  }

  /// Get power consumption for device action
  double _getPowerConsumption(String deviceType, String action) {
    switch (deviceType) {
      case 'grow_lights':
        return action == 'turn_on' ? _random.nextDouble() * 200 + 300 : 0; // 300-500W
      case 'watering_system':
        return action == 'water' ? _random.nextDouble() * 50 + 100 : 0; // 100-150W
      case 'cooling_system':
      case 'heating_system':
        return _random.nextDouble() * 1000 + 1500; // 1500-2500W
      case 'circulation_fans':
      case 'exhaust_fan':
        return _random.nextDouble() * 50 + 50; // 50-100W
      case 'dehumidifier':
        return _random.nextDouble() * 300 + 500; // 500-800W
      case 'humidifier':
        return _random.nextDouble() * 100 + 100; // 100-200W
      case 'co2_generator':
        return action == 'turn_on' ? _random.nextDouble() * 50 + 100 : 0; // 100-150W
      default:
        return _random.nextDouble() * 100; // Generic device
    }
  }

  /// Get device status after action
  String _getDeviceStatus(String deviceType, String action) {
    switch (action) {
      case 'turn_on':
        return 'active';
      case 'turn_off':
        return 'inactive';
      case 'water':
        return 'watering_completed';
      case 'dose':
        return 'dosing_completed';
      case 'adjust_night_mode':
        return 'night_mode';
      default:
        return action;
    }
  }

  /// Get latest sensor reading for a specific type
  Future<Map<String, dynamic>?> _getLatestSensorReading(String roomId, String sensorType) async {
    try {
      final readings = await _dataService.getSensorData(
        roomId: roomId,
        sensorType: sensorType,
        limit: 1,
      );
      return readings.isNotEmpty ? readings.first : null;
    } catch (e) {
      _logger.e('Failed to get sensor reading: $e');
      return null;
    }
  }

  /// Simulate sensor data (background task)
  Future<void> simulateSensorData() async {
    try {
      // This would be handled by the LocalSensorService
      // Just a placeholder for background task
      _logger.d('Background sensor simulation executed');
    } catch (e) {
      _logger.e('Background sensor simulation failed: $e');
    }
  }

  /// Broadcast automation event
  void _broadcastAutomationEvent(AutomationController controller, String eventType, Map<String, dynamic> data) {
    _automationEventController.add({
      'event_type': eventType,
      'room_id': controller.roomId,
      'room_name': controller.roomName,
      'timestamp': DateTime.now().toIso8601String(),
      ...data,
    });
  }

  // Public API methods

  /// Add automation schedule
  Future<void> addAutomationSchedule({
    required String roomId,
    required String deviceType,
    required String action,
    required String scheduleTime,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final scheduleData = await _dataService.saveAutomationSchedule(
        roomId: roomId,
        deviceType: deviceType,
        action: action,
        scheduleTime: scheduleTime,
        parameters: parameters,
      );

      final controller = _controllers[roomId];
      if (controller != null) {
        controller.addSchedule(AutomationSchedule.fromDatabase(scheduleData));
      }

      _logger.i('Added automation schedule: $deviceType - $action at $scheduleTime for room $roomId');
    } catch (e) {
      _logger.e('Failed to add automation schedule: $e');
      rethrow;
    }
  }

  /// Remove automation schedule
  Future<void> removeAutomationSchedule(int scheduleId) async {
    try {
      // Find and remove from controllers
      for (final controller in _controllers.values) {
        controller.removeSchedule(scheduleId);
      }

      // Remove from database
      await _dataService.database.delete(
        'automation_schedules',
        where: 'id = ?',
        whereArgs: [scheduleId],
      );

      _logger.i('Removed automation schedule: $scheduleId');
    } catch (e) {
      _logger.e('Failed to remove automation schedule: $e');
      rethrow;
    }
  }

  /// Get automation schedules for a room
  Future<List<Map<String, dynamic>>> getAutomationSchedules(String roomId) async {
    return await _dataService.getAutomationSchedules(roomId: roomId);
  }

  /// Manually trigger automation action
  Future<Map<String, dynamic>> triggerManualAction({
    required String roomId,
    required String deviceType,
    required String action,
    Map<String, dynamic>? parameters,
  }) async {
    final controller = _controllers[roomId];
    if (controller == null) {
      throw Exception('Room not found: $roomId');
    }

    final tempSchedule = AutomationSchedule(
      id: DateTime.now().millisecondsSinceEpoch,
      roomId: roomId,
      deviceType: deviceType,
      action: action,
      scheduleTime: 'manual',
      isActive: true,
      parameters: parameters ?? {},
    );

    await _executeAutomationAction(controller, tempSchedule);
    return tempSchedule.toMap();
  }

  /// Get automation history
  Future<List<Map<String, dynamic>>> getAutomationHistory({
    String? roomId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    // This would be stored in a separate automation history table
    // For now, return empty list as placeholder
    return [];
  }

  /// Get automation statistics
  Future<Map<String, dynamic>> getAutomationStatistics() async {
    final totalSchedules = _controllers.values
        .fold(0, (sum, controller) => sum + controller.schedules.length);

    final activeSchedules = _controllers.values
        .fold(0, (sum, controller) => sum + controller.schedules.where((s) => s.isActive).length);

    return {
      'total_rooms': _controllers.length,
      'total_schedules': totalSchedules,
      'active_schedules': activeSchedules,
      'automation_running': _isRunning,
      'background_tasks_registered': true,
      'last_execution': DateTime.now().toIso8601String(),
    };
  }

  /// Toggle automation service
  Future<void> toggleAutomation() async {
    if (_isRunning) {
      stopAutomation();
    } else {
      await initialize();
    }
  }

  /// Stop automation service
  void stopAutomation() {
    _automationTimer?.cancel();
    _isRunning = false;
    _logger.i('Automation service stopped');
  }

  /// Dispose of all resources
  void dispose() {
    stopAutomation();
    _automationEventController.close();
    _logger.i('Local automation service disposed');
  }
}

/// Automation controller for managing a single room
class AutomationController {
  final String roomId;
  final String roomName;
  final Map<String, dynamic> settings;
  final List<AutomationSchedule> schedules = [];

  AutomationController({
    required this.roomId,
    required this.roomName,
    required this.settings,
  });

  void addSchedule(AutomationSchedule schedule) {
    schedules.add(schedule);
  }

  void removeSchedule(int scheduleId) {
    schedules.removeWhere((schedule) => schedule.id == scheduleId);
  }

  void removeScheduleById(String scheduleId) {
    schedules.removeWhere((schedule) => schedule.id.toString() == scheduleId);
  }
}

/// Automation schedule model
class AutomationSchedule {
  final int id;
  final String roomId;
  final String deviceType;
  final String action;
  final String scheduleTime;
  bool isActive;
  final Map<String, dynamic> parameters;
  final DateTime createdAt;

  AutomationSchedule({
    required this.id,
    required this.roomId,
    required this.deviceType,
    required this.action,
    required this.scheduleTime,
    required this.isActive,
    required this.parameters,
    required this.createdAt,
  });

  factory AutomationSchedule.fromDatabase(Map<String, dynamic> data) {
    return AutomationSchedule(
      id: data['id'] as int,
      roomId: data['room_id'] as String,
      deviceType: data['device_type'] as String,
      action: data['action'] as String,
      scheduleTime: data['schedule_time'] as String,
      isActive: (data['enabled'] as int) == 1,
      parameters: Map<String, dynamic>.from(
        data['parameters'] != null
            ? (data['parameters'] is String
                ? Map<String, dynamic>.from(data['parameters'])
                : data['parameters'])
            : {},
      ),
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'device_type': deviceType,
      'action': action,
      'schedule_time': scheduleTime,
      'enabled': isActive ? 1 : 0,
      'parameters': parameters,
      'created_at': createdAt.toIso8601String(),
    };
  }
}