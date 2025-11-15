// Comprehensive automation service for CannaAI Android
// Matches the automation features from the web application

import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/comprehensive/data_models.dart';
import '../database/comprehensive_database.dart';
import 'comprehensive_api_service.dart';

class AutomationService {
  static final AutomationService _instance = AutomationService._internal();
  factory AutomationService() => _instance;
  AutomationService._internal();

  final Logger _logger = Logger();
  final APIService _apiService = APIService();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  final Map<String, StreamController<AutomationEvent>> _eventControllers = {};
  final Map<String, Timer> _automationTimers = {};
  final Map<String, bool> _automationStates = {};

  bool _isInitialized = false;

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize WorkManager for background tasks
      await WorkManager().initialize(
        callbackDispatcher: _workManagerCallbackDispatcher,
      );

      // Initialize notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notifications.initialize(initializationSettings);

      // Schedule periodic background tasks
      await _scheduleBackgroundTasks();

      _isInitialized = true;
      _logger.i('Automation Service initialized');
    } catch (e) {
      _logger.e('Failed to initialize Automation Service: $e');
    }
  }

  // ==================== AUTOMATION RULE MANAGEMENT ====================

  Future<List<AutomationRule>> getAutomationRules(String roomId) async {
    try {
      // Try to get from server first
      final serverRules = await _apiService.getAutomationRules(roomId);

      // Merge with local rules
      final localRules = await DatabaseService.instance
          .getAutomationRules(roomId);

      // TODO: Implement merging logic
      return serverRules;
    } catch (e) {
      _logger.e('Failed to get automation rules: $e');
      // Fallback to local only
      final localRules = await DatabaseService.instance
          .getAutomationRules(roomId);
      return localRules.map((ruleData) => _ruleDataToRule(ruleData)).toList();
    }
  }

  Future<AutomationRule?> createAutomationRule(AutomationRule rule) async {
    try {
      // Create on server
      final serverRule = await _apiService.createAutomationRule(rule);

      // Create locally for offline operation
      await _saveRuleLocally(rule);

      // Start the automation if enabled
      if (rule.isEnabled) {
        await _startAutomationRule(rule);
      }

      return serverRule;
    } catch (e) {
      _logger.e('Failed to create automation rule: $e');
      // Create locally only
      await _saveRuleLocally(rule);
      if (rule.isEnabled) {
        await _startAutomationRule(rule);
      }
      return rule;
    }
  }

  Future<AutomationRule?> updateAutomationRule(AutomationRule rule) async {
    try {
      // Update on server
      final serverRule = await _apiService.updateAutomationRule(rule);

      // Update locally
      await _saveRuleLocally(rule);

      // Restart automation if needed
      await _restartAutomationRule(rule);

      return serverRule;
    } catch (e) {
      _logger.e('Failed to update automation rule: $e');
      await _saveRuleLocally(rule);
      await _restartAutomationRule(rule);
      return rule;
    }
  }

  Future<void> deleteAutomationRule(String ruleId) async {
    try {
      // Delete from server
      await _apiService.deleteAutomationRule(ruleId);
    } catch (e) {
      _logger.e('Failed to delete automation rule from server: $e');
    } finally {
      // Always delete locally
      await DatabaseService.instance.deleteAutomationRule(ruleId);
      await _stopAutomationRule(ruleId);
    }
  }

  Future<void> _saveRuleLocally(AutomationRule rule) async {
    final ruleData = _ruleToRuleData(rule);
    await DatabaseService.instance.saveAutomationRule(ruleData);
  }

  // ==================== AUTOMATION EXECUTION ====================

  Future<void> executeAutomationRule(String ruleId) async {
    try {
      await _apiService.executeAutomationRule(ruleId);
    } catch (e) {
      _logger.e('Failed to execute automation rule via API: $e');
      // Execute locally
      await _executeRuleLocally(ruleId);
    }
  }

  Future<AutomationExecutionResult> _executeRuleLocally(String ruleId) async {
    try {
      final ruleData = await DatabaseService.instance.getRuleById(ruleId);
      if (ruleData == null) {
        return AutomationExecutionResult.success('Rule not found');
      }

      final rule = _ruleDataToRule(ruleData);

      if (!rule.isEnabled) {
        return AutomationExecutionResult.success('Rule is disabled');
      }

      // Check conditions
      final conditionsMet = await _checkConditions(rule.conditions);

      if (!conditionsMet) {
        return AutomationExecutionResult.success('Conditions not met');
      }

      // Execute actions
      final executionResults = <String, dynamic>{};

      for (final action in rule.actions.entries) {
        final result = await _executeAction(action.key, action.value);
        executionResults[action.key] = result;
      }

      // Record history
      await _recordAutomationHistory(rule);

      return AutomationExecutionResult.success('Actions executed successfully', data: executionResults);
    } catch (e) {
      _logger.e('Failed to execute rule locally: $e');
      return AutomationExecutionResult.failure(e.toString());
    }
  }

  Future<bool> _checkConditions(Map<String, dynamic> conditions) async {
    try {
      for (final condition in conditions.entries) {
        final result = await _evaluateCondition(condition.key, condition.value);
        if (!result) {
          return false;
        }
      }
      return true;
    } catch (e) {
      _logger.e('Failed to check conditions: $e');
      return false;
    }
  }

  Future<bool> _evaluateCondition(String conditionType, dynamic conditionValue) async {
    switch (conditionType) {
      case 'time':
        return _evaluateTimeCondition(conditionValue);
      case 'sensor':
        return await _evaluateSensorCondition(conditionValue);
      case 'plant_health':
        return await _evaluatePlantHealthCondition(conditionValue);
      case 'schedule':
        return _evaluateScheduleCondition(conditionValue);
      default:
        _logger.w('Unknown condition type: $conditionType');
        return false;
    }
  }

  bool _evaluateTimeCondition(Map<String, dynamic> timeCondition) {
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (timeCondition['startTime'] != null && timeCondition['endTime'] != null) {
      final startTime = timeCondition['startTime'];
      final endTime = timeCondition['endTime'];
      return currentTime >= startTime && currentTime <= endTime;
    }

    if (timeCondition['exactTime'] != null) {
      return currentTime == timeCondition['exactTime'];
    }

    return false;
  }

  Future<bool> _evaluateSensorCondition(Map<String, dynamic> sensorCondition) async {
    final roomId = sensorCondition['roomId'] as String?;
    if (roomId == null) return false;

    final currentData = await _apiService.getCurrentSensorData(roomId);
    if (currentData == null) return false;

    final metric = sensorCondition['metric'] as String?;
    final operator = sensorCondition['operator'] as String?;
    final value = sensorCondition['value'] as double?;

    if (metric == null || operator == null || value == null) return false;

    final currentValue = _getSensorMetricValue(currentData, metric);
    return _compareValues(currentValue, operator, value);
  }

  double _getSensorMetricValue(SensorData data, String metric) {
    switch (metric) {
      case 'temperature':
        return data.temperature;
      case 'humidity':
        return data.humidity;
      case 'soilMoisture':
        return data.soilMoisture;
      case 'lightIntensity':
        return data.lightIntensity;
      case 'ph':
        return data.ph;
      case 'ec':
        return data.ec;
      case 'co2':
        return data.co2;
      case 'vpd':
        return data.vpd;
      default:
        return 0.0;
    }
  }

  bool _compareValues(double currentValue, String operator, double targetValue) {
    switch (operator) {
      case 'greater_than':
        return currentValue > targetValue;
      case 'less_than':
        return currentValue < targetValue;
      case 'equals':
        return currentValue == targetValue;
      case 'greater_equal':
        return currentValue >= targetValue;
      case 'less_equal':
        return currentValue <= targetValue;
      default:
        return false;
    }
  }

  Future<bool> _evaluatePlantHealthCondition(Map<String, dynamic> healthCondition) async {
    final plantId = healthCondition['plantId'] as String?;
    if (plantId == null) return false;

    final analysisResults = await _apiService.getAnalysisHistory(plantId);
    if (analysisResults.isEmpty) return false;

    final latestAnalysis = analysisResults.first;
    final minHealthScore = healthCondition['minHealthScore'] as double? ?? 0.5;

    return latestAnalysis.healthScore >= minHealthScore;
  }

  bool _evaluateScheduleCondition(Map<String, dynamic> scheduleCondition) {
    final cronExpression = scheduleCondition['cron'] as String?;
    if (cronExpression == null) return false;

    // Simple cron evaluation - in production, use a proper cron library
    final now = DateTime.now();
    final timeParts = cronExpression.split(' ');

    if (timeParts.length >= 2) {
      final minute = timeParts[0];
      final hour = timeParts[1];

      if (minute == '*' && hour == '*') {
        return true; // Every minute
      }

      if (minute != '*' && hour == '*') {
        return now.minute == int.tryParse(minute);
      }

      if (minute == '*' && hour != '*') {
        return now.hour == int.tryParse(hour);
      }

      if (minute != '*' && hour != '*') {
        return now.minute == int.tryParse(minute) &&
               now.hour == int.tryParse(hour);
      }
    }

    return false;
  }

  Future<Map<String, dynamic>> _executeAction(String actionType, dynamic actionData) async {
    switch (actionType) {
      case 'water':
        return await _executeWateringAction(actionData);
      case 'lighting':
        return await _executeLightingAction(actionData);
      case 'climate':
        return await _executeClimateAction(actionData);
      case 'ventilation':
        return await _executeVentilationAction(actionData);
      case 'co2':
        return await _executeCo2Action(actionData);
      case 'notification':
        return await _executeNotificationAction(actionData);
      case 'data_logging':
        return await _executeDataLoggingAction(actionData);
      default:
        return {'success': false, 'error': 'Unknown action type: $actionType'};
    }
  }

  Future<Map<String, dynamic>> _executeWateringAction(Map<String, dynamic> data) async {
    try {
      final roomId = data['roomId'] as String?;
      final duration = data['duration'] as int? ?? 5; // minutes
      final amount = data['amount'] as double? ?? 1.0; // liters

      if (roomId == null) {
        return {'success': false, 'error': 'Room ID required'};
      }

      // TODO: Implement actual watering hardware control
      _logger.i('Executing watering action: Room $roomId, Duration: ${duration}min, Amount: ${amount}L');

      // Simulate watering for demo
      await Future.delayed(Duration(minutes: duration));

      // Log the action
      await _logAutomationAction('watering', roomId, {
        'duration': duration,
        'amount': amount,
        'executedAt': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'roomId': roomId,
        'duration': duration,
        'amount': amount,
      };
    } catch (e) {
      _logger.e('Failed to execute watering action: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _executeLightingAction(Map<String, dynamic> data) async {
    try {
      final roomId = data['roomId'] as String?;
      final action = data['action'] as String?; // on, off, toggle, dim
      final intensity = data['intensity'] as int?; // 0-100%
      final spectrum = data['spectrum'] as String?;

      if (roomId == null || action == null) {
        return {'success': false, 'error': 'Room ID and action required'};
      }

      // TODO: Implement actual lighting hardware control
      _logger.i('Executing lighting action: Room $roomId, Action: $action, Intensity: ${intensity}%');

      await _logAutomationAction('lighting', roomId, {
        'action': action,
        'intensity': intensity,
        'spectrum': spectrum,
        'executedAt': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'roomId': roomId,
        'action': action,
        'intensity': intensity,
      };
    } catch (e) {
      _logger.e('Failed to execute lighting action: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _executeClimateAction(Map<String, dynamic> data) async {
    try {
      final roomId = data['roomId'] as String?;
      final targetTemp = data['targetTemperature'] as double?;
      final targetHumidity = data['targetHumidity'] as double?;
      final action = data['action'] as String?;

      if (roomId == null) {
        return {'success': false, 'error': 'Room ID required'};
      }

      _logger.i('Executing climate action: Room $roomId, Temp: ${targetTemp}°C, Humidity: ${targetHumidity}%');

      await _logAutomationAction('climate', roomId, {
        'targetTemperature': targetTemp,
        'targetHumidity': targetHumidity,
        'action': action,
        'executedAt': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'roomId': roomId,
        'targetTemperature': targetTemp,
        'targetHumidity': targetHumidity,
      };
    } catch (e) {
      _logger.e('Failed to execute climate action: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _executeVentilationAction(Map<String, dynamic> data) async {
    try {
      final roomId = data['roomId'] as String?;
      final fanSpeed = data['fanSpeed'] as int?; // 0-100%
      final duration = data['duration'] as int?; // minutes
      final action = data['action'] as String?;

      if (roomId == null) {
        return {'success': false, 'error': 'Room ID required'};
      }

      _logger.i('Executing ventilation action: Room $roomId, Fan Speed: ${fanSpeed}%, Duration: ${duration}min');

      await _logAutomationAction('ventilation', roomId, {
        'fanSpeed': fanSpeed,
        'duration': duration,
        'action': action,
        'executedAt': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'roomId': roomId,
        'fanSpeed': fanSpeed,
        'duration': duration,
      };
    } catch (e) {
      _logger.e('Failed to execute ventilation action: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _executeCo2Action(Map<String, dynamic> data) async {
    try {
      final roomId = data['roomId'] as String?;
      final targetLevel = data['targetLevel'] as double?;
      final duration = data['duration'] as int?; // seconds
      final action = data['action'] as String?;

      if (roomId == null) {
        return {'success': false, 'error': 'Room ID required'};
      }

      _logger.i('Executing CO2 action: Room $roomId, Target Level: ${targetLevel}ppm, Duration: ${duration}s');

      await _logAutomationAction('co2', roomId, {
        'targetLevel': targetLevel,
        'duration': duration,
        'action': action,
        'executedAt': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'roomId': roomId,
        'targetLevel': targetLevel,
        'duration': duration,
      };
    } catch (e) {
      _logger.e('Failed to execute CO2 action: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _executeNotificationAction(Map<String, dynamic> data) async {
    try {
      final title = data['title'] as String?;
      final body = data['body'] as String?;
      final priority = data['priority'] as String? ?? 'normal';

      if (title == null || body == null) {
        return {'success': false, 'error': 'Title and body required'};
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'automation_channel',
        'Automation Alerts',
        channelDescription: 'Notifications from automation system',
        importance: _getImportance(priority),
        priority: _getAndroidPriority(priority),
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
      );

      return {
        'success': true,
        'title': title,
        'body': body,
      };
    } catch (e) {
      _logger.e('Failed to execute notification action: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _executeDataLoggingAction(Map<String, dynamic> data) async {
    try {
      final logType = data['logType'] as String?;
      final message = data['message'] as String?;
      final metadata = data['metadata'] as Map<String, dynamic>?;

      _logger.i('Data logging: $logType - $message');

      if (metadata != null) {
        _logger.i('Metadata: ${jsonEncode(metadata)}');
      }

      return {
        'success': true,
        'logType': logType,
        'message': message,
      };
    } catch (e) {
      _logger.e('Failed to execute data logging action: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== AUTOMATION SCHEDULING ====================

  Future<void> _startAutomationRule(AutomationRule rule) async {
    try {
      // Cancel existing timer for this rule
      await _stopAutomationRule(rule.id);

      if (rule.schedule.isNotEmpty) {
        // Schedule based on cron expression
        await _scheduleCronJob(rule);
      } else {
        // Check conditions continuously (every minute)
        _automationTimers[rule.id] = Timer.periodic(
          const Duration(minutes: 1),
          (_) => _executeRuleLocally(rule.id),
        );
      }

      _automationStates[rule.id] = true;
      _logger.i('Started automation rule: ${rule.name}');
    } catch (e) {
      _logger.e('Failed to start automation rule: $e');
    }
  }

  Future<void> _stopAutomationRule(String ruleId) async {
    try {
      final timer = _automationTimers.remove(ruleId);
      timer?.cancel();

      _automationStates[ruleId] = false;
      _logger.i('Stopped automation rule: $ruleId');
    } catch (e) {
      _logger.e('Failed to stop automation rule: $e');
    }
  }

  Future<void> _restartAutomationRule(AutomationRule rule) async {
    await _stopAutomationRule(rule.id);
    if (rule.isEnabled) {
      await _startAutomationRule(rule);
    }
  }

  Future<void> _scheduleCronJob(AutomationRule rule) async {
    try {
      // Schedule with WorkManager
      await WorkManager().registerOneOffTask(
        'automation_${rule.id}',
        'automationTask',
        initialDelay: _calculateNextExecution(rule.schedule),
        inputData: {
          'ruleId': rule.id,
          'roomId': rule.roomId,
        },
        constraints: Constraints(
          networkType: NetworkType.not_required,
        ),
      );

      // Schedule recurring task
      await WorkManager().registerPeriodicTask(
        'automation_recurring_${rule.id}',
        'automationTask',
        frequency: const Duration(hours: 1), // Check hourly
        inputData: {
          'ruleId': rule.id,
          'roomId': rule.roomId,
        },
        constraints: Constraints(
          networkType: NetworkType.not_required,
        ),
      );
    } catch (e) {
      _logger.e('Failed to schedule cron job: $e');
    }
  }

  Duration _calculateNextExecution(String cronExpression) {
    // Simple cron parsing - in production, use a proper cron library
    final now = DateTime.now();
    final timeParts = cronExpression.split(' ');

    if (timeParts.length >= 2) {
      final minute = timeParts[0];
      final hour = timeParts[1];

      int targetMinute = now.minute;
      int targetHour = now.hour;

      if (minute != '*') {
        targetMinute = int.tryParse(minute) ?? now.minute;
      }

      if (hour != '*') {
        targetHour = int.tryParse(hour) ?? now.hour;
      }

      var nextExecution = DateTime(now.year, now.month, now.day, targetHour, targetMinute);

      if (nextExecution.isBefore(now)) {
        nextExecution = nextExecution.add(const Duration(days: 1));
      }

      return nextExecution.difference(now);
    }

    return const Duration(hours: 1);
  }

  // ==================== BACKGROUND TASKS ====================

  Future<void> _scheduleBackgroundTasks() async {
    // Periodic sensor data sync
    await WorkManager().registerPeriodicTask(
      'sensor_sync',
      'sensorSyncTask',
      frequency: const Duration(minutes: 5),
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );

    // Periodic health checks
    await WorkManager().registerPeriodicTask(
      'health_check',
      'healthCheckTask',
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );
  }

  static Future<void> _workManagerCallbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      switch (task) {
        case 'automationTask':
          return await _executeAutomationTask(inputData);
        case 'sensorSyncTask':
          return await _executeSensorSyncTask();
        case 'healthCheckTask':
          return await _executeHealthCheckTask();
        default:
          return Future.value(false);
      }
    });
  }

  static Future<bool> _executeAutomationTask(Map<String, dynamic> inputData) async {
    try {
      final ruleId = inputData['ruleId'] as String?;
      final roomId = inputData['roomId'] as String?;

      if (ruleId == null || roomId == null) return false;

      final automationService = AutomationService();
      await automationService.initialize();

      final result = await automationService._executeRuleLocally(ruleId);
      return result.success;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _executeSensorSyncTask() async {
    try {
      final automationService = AutomationService();
      await automationService.initialize();

      final rooms = await automationService.getRooms();
      for (final room in rooms) {
        await automationService._syncRoomSensorData(room.id);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _executeHealthCheckTask() async {
    try {
      final automationService = AutomationService();
      await automationService.initialize();

      final systemHealth = await automationService.getSystemHealth();
      _logger.i('System health check: $systemHealth');

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _syncRoomSensorData(String roomId) async {
    try {
      final currentData = await _apiService.getCurrentSensorData(roomId);
      if (currentData != null) {
        // Save to local database
        final sensorDataPoint = SensorDataPoint(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          roomId: roomId,
          temperature: currentData.temperature,
          humidity: currentData.humidity,
          soilMoisture: currentData.soilMoisture,
          lightIntensity: currentData.lightIntensity,
          ph: currentData.ph,
          ec: currentData.ec,
          co2: currentData.co2,
          vpd: currentData.vpd,
          timestamp: DateTime.now(),
        );

        await DatabaseService.instance.saveSensorData(sensorDataPoint);
      }
    } catch (e) {
      _logger.e('Failed to sync sensor data for room $roomId: $e');
    }
  }

  // ==================== EVENTS & STREAMS ====================

  Stream<AutomationEvent> getAutomationEvents(String ruleId) {
    _eventControllers[ruleId] ??= StreamController<AutomationEvent>.broadcast();
    return _eventControllers[ruleId]!.stream;
  }

  void _emitAutomationEvent(String ruleId, AutomationEvent event) {
    final controller = _eventControllers[ruleId];
    if (controller != null && !controller.isClosed) {
      controller.add(event);
    }
  }

  // ==================== LOGGING & HISTORY ====================

  Future<void> _recordAutomationHistory(AutomationRule rule) async {
    try {
      final history = AutomationHistoryData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ruleId: rule.id,
        roomId: rule.roomId,
        type: rule.type.name,
        success: true,
        inputData: rule.conditions,
        outputData: rule.actions,
        executedAt: DateTime.now(),
        executionTimeMs: Duration.zero.inMilliseconds,
      );

      await DatabaseService.instance.saveAutomationHistory(history);
    } catch (e) {
      _logger.e('Failed to record automation history: $e');
    }
  }

  Future<void> _logAutomationAction(String actionType, String roomId, Map<String, dynamic> data) async {
    try {
      // TODO: Implement detailed action logging
      _logger.i('Automation action logged: $actionType in room $roomId');
    } catch (e) {
      _logger.e('Failed to log automation action: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  Importance _getImportance(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return Importance.max;
      case 'medium':
      case 'normal':
        return Importance.defaultImportance;
      case 'low':
        return Importance.low;
      default:
        return Importance.defaultImportance;
    }
  }

  Priority _getAndroidPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return Priority.high;
      case 'medium':
      case 'normal':
        return Priority.defaultPriority;
      case 'low':
        return Priority.low;
      default:
        return Priority.defaultPriority;
    }
  }

  Future<List<Room>> getRooms() async {
    return await _apiService.getRooms();
  }

  Future<Map<String, dynamic>> getSystemHealth() async {
    return await _apiService.getSystemHealth();
  }

  // ==================== DATA CONVERSION ====================

  AutomationRule _ruleDataToRule(AutomationRuleData data) {
    return AutomationRule(
      id: data.id,
      roomId: data.roomId,
      name: data.name,
      type: AutomationType.values.firstWhere(
        (type) => type.name == data.type,
        orElse: () => AutomationType.watering,
      ),
      isEnabled: data.isEnabled,
      conditions: Map<String, dynamic>.from(jsonDecode(data.conditionsJson)),
      actions: Map<String, dynamic>.from(jsonDecode(data.actionsJson)),
      schedule: data.schedule,
      notificationRecipients: List<String>.from(jsonDecode(data.notificationRecipientsJson)),
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      lastExecuted: data.lastExecuted,
      isCurrentlyActive: data.isCurrentlyActive,
    );
  }

  AutomationRuleData _ruleToRuleData(AutomationRule rule) {
    return AutomationRuleData(
      id: rule.id,
      roomId: rule.roomId,
      name: rule.name,
      type: rule.type.name,
      isEnabled: rule.isEnabled,
      conditionsJson: jsonEncode(rule.conditions),
      actionsJson: jsonEncode(rule.actions),
      schedule: rule.schedule,
      notificationRecipientsJson: jsonEncode(rule.notificationRecipients),
      createdAt: rule.createdAt,
      updatedAt: rule.updatedAt,
      lastExecuted: rule.lastExecuted,
      isCurrentlyActive: rule.isCurrentlyActive,
    );
  }

  // ==================== CLEANUP ====================

  void dispose() {
    for (final timer in _automationTimers.values) {
      timer.cancel();
    }
    _automationTimers.clear();

    for (final controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();

    _automationStates.clear();
  }
}

// ==================== SUPPORTING CLASSES ====================

class AutomationExecutionResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  AutomationExecutionResult(this.success, this.message, {this.data});

  factory AutomationExecutionResult.success(String message, {Map<String, dynamic>? data}) {
    return AutomationExecutionResult(true, message, data: data);
  }

  factory AutomationExecutionResult.failure(String message) {
    return AutomationExecutionResult(false, message);
  }
}

class AutomationEvent {
  final String ruleId;
  final AutomationEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  AutomationEvent({
    required this.ruleId,
    required this.type,
    required this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum AutomationEventType {
  started,
  stopped,
  executed,
  failed,
  conditionMet,
  conditionNotMet,
}

// ==================== WORKMANAGER TASK DEFINITIONS ====================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    return AutomationService._workManagerCallbackDispatcher();
  });
}