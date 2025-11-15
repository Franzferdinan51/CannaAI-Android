import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timezone/timezone.dart' as tz;
import '../events/event_bus.dart';
import '../constants/app_constants.dart';

/// Notification importance levels
enum NotificationImportance {
  low,
  default_,
  high,
  critical,
}

/// Notification categories
enum NotificationCategory {
  sensor,
  automation,
  system,
  analysis,
  reminder,
  alert,
}

/// Local notification data
class LocalNotification {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final NotificationImportance importance;
  final Map<String, String>? payload;
  final String? channelId;
  final String? icon;
  final bool ongoing;
  final bool autoCancel;
  final DateTime? scheduledAt;
  final Duration? timeoutAfter;

  LocalNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.importance = NotificationImportance.default_,
    this.payload,
    this.channelId,
    this.icon,
    this.ongoing = false,
    this.autoCancel = true,
    this.scheduledAt,
    this.timeoutAfter,
  });
}

/// Notification configuration
class NotificationChannelConfig {
  final String id;
  final String name;
  final String description;
  final NotificationImportance importance;
  final bool showBadge;
  final bool enableVibration;
  final bool enableLights;
  final Color? lightColor;
  final String? sound;

  NotificationChannelConfig({
    required this.id,
    required this.name,
    required this.description,
    this.importance = NotificationImportance.default_,
    this.showBadge = true,
    this.enableVibration = true,
    this.enableLights = true,
    this.lightColor,
    this.sound,
  });
}

/// Local notification manager
class LocalNotificationManager {
  static final LocalNotificationManager _instance = LocalNotificationManager._internal();
  factory LocalNotificationManager() => _instance;
  LocalNotificationManager._internal();

  final Logger _logger = Logger();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final BehaviorSubject<NotificationResponse?> _notificationResponse = BehaviorSubject();
  final List<LocalNotification> _notificationHistory = [];
  final Map<String, NotificationChannelConfig> _channels = {};
  bool _isInitialized = false;

  /// Stream of notification responses
  Stream<NotificationResponse> get notificationResponseStream =>
      _notificationResponse.stream.where((response) => response != null).cast();

  /// Notification history
  List<LocalNotification> get notificationHistory => List.unmodifiable(_notificationHistory);

  /// Initialization status
  bool get isInitialized => _isInitialized;

  /// Initialize notification system
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // Initialize plugin
      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create default notification channels
      await _createDefaultChannels();

      // Subscribe to event bus for automated notifications
      _subscribeToEvents();

      _isInitialized = true;
      _logger.i('Local notification manager initialized');
    } catch (e) {
      _logger.e('Failed to initialize local notifications: $e');
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final result = await androidPlugin.requestNotificationsPermission();
        _logger.d('Android notification permission granted: $result');
        return result;
      }

      final iOSPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (iOSPlugin != null) {
        final result = await iOSPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _logger.d('iOS notification permission granted: $result');
        return result;
      }

      return true;
    } catch (e) {
      _logger.e('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Create a notification channel
  Future<void> createChannel(NotificationChannelConfig channel) async {
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final androidChannel = AndroidNotificationChannel(
          channel.id,
          channel.name,
          description: channel.description,
          importance: _getAndroidImportance(channel.importance),
          enableVibration: channel.enableVibration,
          enableLights: channel.enableLights,
          showBadge: channel.showBadge,
          ledColor: channel.lightColor,
          sound: channel.sound != null ? RawResourceAndroidNotificationSound(channel.sound!) : null,
        );

        await androidPlugin.createNotificationChannel(androidChannel);
        _channels[channel.id] = channel;
        _logger.d('Created notification channel: ${channel.name}');
      }
    } catch (e) {
      _logger.e('Error creating notification channel ${channel.id}: $e');
    }
  }

  /// Show an immediate notification
  Future<void> showNotification(LocalNotification notification) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final androidDetails = _buildAndroidNotificationDetails(notification);
      final iOSDetails = _buildIOSNotificationDetails(notification);

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _notifications.show(
        int.parse(notification.id),
        notification.title,
        notification.body,
        details,
        payload: _encodePayload(notification.payload),
      );

      // Add to history
      _addToHistory(notification);

      _logger.d('Showed notification: ${notification.title}');
    } catch (e) {
      _logger.e('Error showing notification: $e');
    }
  }

  /// Schedule a notification for later
  Future<void> scheduleNotification(LocalNotification notification) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (notification.scheduledAt == null) {
      _logger.w('Cannot schedule notification: no scheduled time provided');
      return;
    }

    try {
      final androidDetails = _buildAndroidNotificationDetails(notification);
      final iOSDetails = _buildIOSNotificationDetails(notification);

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _notifications.zonedSchedule(
        int.parse(notification.id),
        notification.title,
        notification.body,
        tz.TZDateTime.from(notification.scheduledAt!, tz.local),
        details,
        payload: _encodePayload(notification.payload),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      // Add to history
      _addToHistory(notification);

      _logger.d('Scheduled notification: ${notification.title} at ${notification.scheduledAt}');
    } catch (e) {
      _logger.e('Error scheduling notification: $e');
    }
  }

  /// Show a progress notification
  Future<void> showProgressNotification({
    required String id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
    bool indeterminate = false,
    String? channelId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId ?? 'progress_channel',
        'Progress',
        channelDescription: 'Progress notifications',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        indeterminate: indeterminate,
        ongoing: true,
        autoCancel: false,
      );

      final details = NotificationDetails(android: androidDetails);

      await _notifications.show(
        int.parse(id),
        title,
        body,
        details,
      );

      _logger.d('Showed progress notification: $title ($progress/$maxProgress)');
    } catch (e) {
      _logger.e('Error showing progress notification: $e');
    }
  }

  /// Update a progress notification
  Future<void> updateProgressNotification({
    required String id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
    bool indeterminate = false,
  }) async {
    await showProgressNotification(
      id: id,
      title: title,
      body: body,
      progress: progress,
      maxProgress: maxProgress,
      indeterminate: indeterminate,
    );
  }

  /// Cancel a notification
  Future<void> cancelNotification(String id) async {
    try {
      await _notifications.cancel(int.parse(id));
      _logger.d('Cancelled notification: $id');
    } catch (e) {
      _logger.e('Error cancelling notification $id: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      _logger.d('Cancelled all notifications');
    } catch (e) {
      _logger.e('Error cancelling all notifications: $e');
    }
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      _logger.e('Error getting pending notifications: $e');
      return [];
    }
  }

  /// Show sensor alert notification
  Future<void> showSensorAlert({
    required String deviceId,
    required String roomId,
    required String alertType,
    required String message,
    String? recommendation,
    String severity = 'medium',
  }) async {
    final notification = LocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Sensor Alert - ${severity.toUpperCase()}',
      body: message,
      category: NotificationCategory.sensor,
      importance: _getImportanceFromSeverity(severity),
      channelId: 'sensor_alerts',
      payload: {
        'type': 'sensor_alert',
        'deviceId': deviceId,
        'roomId': roomId,
        'alertType': alertType,
        'recommendation': recommendation ?? '',
        'severity': severity,
      },
    );

    await showNotification(notification);
  }

  /// Show automation notification
  Future<void> showAutomationNotification({
    required String automationId,
    required String roomId,
    required String action,
    required bool success,
    String? errorMessage,
  }) async {
    final notification = LocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: success ? 'Automation Executed' : 'Automation Failed',
      body: success
          ? 'Successfully executed $action in $roomId'
          : 'Failed to execute $action: ${errorMessage ?? "Unknown error"}',
      category: NotificationCategory.automation,
      importance: success ? NotificationImportance.default_ : NotificationImportance.high,
      channelId: 'automation',
      payload: {
        'type': 'automation',
        'automationId': automationId,
        'roomId': roomId,
        'action': action,
        'success': success.toString(),
        'errorMessage': errorMessage ?? '',
      },
    );

    await showNotification(notification);
  }

  /// Show plant care reminder
  Future<void> showPlantCareReminder({
    required String plantId,
    required String plantName,
    required String careType,
    required DateTime dueDate,
  }) async {
    final notification = LocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Plant Care Reminder',
      body: 'Time to $careType for $plantName',
      category: NotificationCategory.reminder,
      importance: NotificationImportance.default_,
      channelId: 'plant_care',
      payload: {
        'type': 'plant_care',
        'plantId': plantId,
        'plantName': plantName,
        'careType': careType,
        'dueDate': dueDate.toIso8601String(),
      },
    );

    await showNotification(notification);
  }

  /// Show analysis completion notification
  Future<void> showAnalysisCompleted({
    required String analysisId,
    required String plantName,
    required bool success,
    String? result,
  }) async {
    final notification = LocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: success ? 'Analysis Completed' : 'Analysis Failed',
      body: success
          ? 'Plant analysis completed for $plantName'
          : 'Analysis failed for $plantName: ${result ?? "Unknown error"}',
      category: NotificationCategory.analysis,
      importance: success ? NotificationImportance.default_ : NotificationImportance.medium,
      channelId: 'analysis',
      payload: {
        'type': 'analysis',
        'analysisId': analysisId,
        'plantName': plantName,
        'success': success.toString(),
        'result': result ?? '',
      },
    );

    await showNotification(notification);
  }

  /// Show system status notification
  Future<void> showSystemNotification({
    required String title,
    required String body,
    NotificationImportance importance = NotificationImportance.default_,
    Map<String, String>? payload,
  }) async {
    final notification = LocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      category: NotificationCategory.system,
      importance: importance,
      channelId: 'system',
      payload: {
        'type': 'system',
        ...?payload,
      },
    );

    await showNotification(notification);
  }

  AndroidNotificationDetails? _buildAndroidNotificationDetails(LocalNotification notification) {
    final channel = _channels[notification.channelId ?? 'default'];

    return AndroidNotificationDetails(
      notification.channelId ?? 'default',
      channel?.name ?? 'Default',
      channelDescription: channel?.description ?? 'Default notifications',
      importance: _getAndroidImportance(notification.importance),
      priority: _getAndroidPriority(notification.importance),
      ongoing: notification.ongoing,
      autoCancel: notification.autoCancel,
      showWhen: true,
      enableVibration: channel?.enableVibration ?? true,
      enableLights: channel?.enableLights ?? true,
      ledColor: channel?.lightColor,
      icon: notification.icon ?? '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(notification.body),
      timeoutAfter: notification.timeoutAfter?.inMilliseconds,
    );
  }

  DarwinNotificationDetails? _buildIOSNotificationDetails(LocalNotification notification) {
    return DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: notification.channelId == 'critical_alerts' ? 'default' : null,
      badgeNumber: 1,
      threadIdentifier: notification.category.toString(),
      categoryIdentifier: notification.category.toString(),
    );
  }

  Importance _getAndroidImportance(NotificationImportance importance) {
    switch (importance) {
      case NotificationImportance.low:
        return Importance.low;
      case NotificationImportance.default_:
        return Importance.default_;
      case NotificationImportance.high:
        return Importance.high;
      case NotificationImportance.critical:
        return Importance.max;
    }
  }

  Priority _getAndroidPriority(NotificationImportance importance) {
    switch (importance) {
      case NotificationImportance.low:
        return Priority.low;
      case NotificationImportance.default_:
        return Priority.default_;
      case NotificationImportance.high:
        return Priority.high;
      case NotificationImportance.critical:
        return Priority.high;
    }
  }

  NotificationImportance _getImportanceFromSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return NotificationImportance.low;
      case 'medium':
        return NotificationImportance.default_;
      case 'high':
        return NotificationImportance.high;
      case 'critical':
        return NotificationImportance.critical;
      default:
        return NotificationImportance.default_;
    }
  }

  String? _encodePayload(Map<String, String>? payload) {
    if (payload == null || payload.isEmpty) return null;

    return payload.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Map<String, String> _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return {};

    return Uri.splitQueryString(payload);
  }

  void _addToHistory(LocalNotification notification) {
    _notificationHistory.add(notification);
    if (_notificationHistory.length > 500) {
      _notificationHistory.removeAt(0);
    }
  }

  void _subscribeToEvents() {
    // Listen to sensor alert events
    eventBus.subscribeToType(EventType.sensorAlert, (event) {
      if (event is SensorAlertEvent) {
        showSensorAlert(
          deviceId: event.deviceId,
          roomId: event.roomId,
          alertType: event.alertType,
          message: event.message,
          recommendation: event.recommendation,
          severity: event.severity,
        );
      }
    });

    // Listen to automation events
    eventBus.subscribeToType(EventType.automationTriggered, (event) {
      if (event is AutomationEvent) {
        showAutomationNotification(
          automationId: event.automationId,
          roomId: event.roomId,
          action: event.action,
          success: event.success,
          errorMessage: event.errorMessage,
        );
      }
    });

    // Listen to notification events
    eventBus.subscribeToType(EventType.notificationTriggered, (event) {
      if (event is NotificationEvent) {
        showNotification(LocalNotification(
          id: event.id,
          title: event.title,
          body: event.body,
          category: NotificationCategory.system,
          importance: NotificationImportance.default_,
          payload: event.payload,
        ));
      }
    });

    // Listen to analysis events
    eventBus.subscribeToType(EventType.analysisCompleted, (event) {
      showAnalysisCompleted(
        analysisId: event.id,
        plantName: event.metadata?['plantName'] ?? 'Unknown Plant',
        success: true,
      );
    });
  }

  void _onNotificationTapped(NotificationResponse response) {
    _logger.d('Notification tapped: ${response.id} - ${response.payload}');
    _notificationResponse.add(response);

    // Handle navigation based on payload
    final payload = _decodePayload(response.payload);
    final type = payload['type'];

    switch (type) {
      case 'sensor_alert':
        _handleSensorAlertTap(payload);
        break;
      case 'automation':
        _handleAutomationTap(payload);
        break;
      case 'plant_care':
        _handlePlantCareTap(payload);
        break;
      case 'analysis':
        _handleAnalysisTap(payload);
        break;
      default:
        _handleDefaultTap(payload);
    }
  }

  void _handleSensorAlertTap(Map<String, String> payload) {
    final roomId = payload['roomId'];
    final deviceId = payload['deviceId'];
    _logger.d('Navigate to sensor details: room=$roomId, device=$deviceId');

    // Emit navigation event
    final event = AppEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: EventType.navigationRequested,
      timestamp: DateTime.now(),
      metadata: {
        'route': '/sensors',
        'roomId': roomId,
        'deviceId': deviceId,
      },
    );
    eventBus.emit(event);
  }

  void _handleAutomationTap(Map<String, String> payload) {
    final roomId = payload['roomId'];
    _logger.d('Navigate to automation: room=$roomId');

    final event = AppEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: EventType.navigationRequested,
      timestamp: DateTime.now(),
      metadata: {
        'route': '/automation',
        'roomId': roomId,
      },
    );
    eventBus.emit(event);
  }

  void _handlePlantCareTap(Map<String, String> payload) {
    final plantId = payload['plantId'];
    _logger.d('Navigate to plant details: plant=$plantId');

    final event = AppEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: EventType.navigationRequested,
      timestamp: DateTime.now(),
      metadata: {
        'route': '/plants',
        'plantId': plantId,
      },
    );
    eventBus.emit(event);
  }

  void _handleAnalysisTap(Map<String, String> payload) {
    final analysisId = payload['analysisId'];
    _logger.d('Navigate to analysis: analysis=$analysisId');

    final event = AppEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: EventType.navigationRequested,
      timestamp: DateTime.now(),
      metadata: {
        'route': '/analysis',
        'analysisId': analysisId,
      },
    );
    eventBus.emit(event);
  }

  void _handleDefaultTap(Map<String, String> payload) {
    _logger.d('Navigate to dashboard');

    final event = AppEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: EventType.navigationRequested,
      timestamp: DateTime.now(),
      metadata: {
        'route': '/dashboard',
      },
    );
    eventBus.emit(event);
  }

  Future<void> _createDefaultChannels() async {
    final channels = [
      NotificationChannelConfig(
        id: 'default',
        name: 'Default',
        description: 'Default notifications',
        importance: NotificationImportance.default_,
      ),
      NotificationChannelConfig(
        id: 'sensor_alerts',
        name: 'Sensor Alerts',
        description: 'Environmental sensor alerts and warnings',
        importance: NotificationImportance.high,
        enableVibration: true,
        enableLights: true,
        lightColor: Colors.orange,
      ),
      NotificationChannelConfig(
        id: 'critical_alerts',
        name: 'Critical Alerts',
        description: 'Critical system alerts requiring immediate attention',
        importance: NotificationImportance.critical,
        enableVibration: true,
        enableLights: true,
        lightColor: Colors.red,
      ),
      NotificationChannelConfig(
        id: 'automation',
        name: 'Automation',
        description: 'Automation system notifications',
        importance: NotificationImportance.default_,
        enableVibration: false,
        enableLights: false,
      ),
      NotificationChannelConfig(
        id: 'plant_care',
        name: 'Plant Care',
        description: 'Plant care reminders and notifications',
        importance: NotificationImportance.default_,
        enableVibration: true,
        enableLights: false,
      ),
      NotificationChannelConfig(
        id: 'analysis',
        name: 'Analysis',
        description: 'Plant analysis notifications and results',
        importance: NotificationImportance.default_,
        enableVibration: false,
        enableLights: false,
      ),
      NotificationChannelConfig(
        id: 'system',
        name: 'System',
        description: 'System status and maintenance notifications',
        importance: NotificationImportance.low,
        enableVibration: false,
        enableLights: false,
      ),
      NotificationChannelConfig(
        id: 'progress',
        name: 'Progress',
        description: 'Background task progress notifications',
        importance: NotificationImportance.low,
        enableVibration: false,
        enableLights: false,
      ),
    ];

    for (final channel in channels) {
      await createChannel(channel);
    }

    _logger.d('Created ${_channels.length} default notification channels');
  }

  void dispose() {
    _notificationResponse.close();
    _notificationHistory.clear();
    _channels.clear();
    _logger.d('Local notification manager disposed');
  }
}

/// Global notification manager instance
final notificationManager = LocalNotificationManager();