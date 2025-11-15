import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../constants/app_constants.dart';

/// Local notification service for offline functionality
/// Handles all notifications without requiring external services
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final Logger _logger = Logger();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  late final SharedPreferences _prefs;

  // Notification settings
  bool _notificationsEnabled = true;
  bool _alertNotificationsEnabled = true;
  bool _automationNotificationsEnabled = true;
  bool _analysisNotificationsEnabled = true;
  bool _dailyReportsEnabled = true;

  // Notification counters
  int _notificationCount = 0;

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _initializeTimeZones();
      await _initializeNotifications();
      await _loadNotificationSettings();
      await _requestPermissions();
      _scheduleDailyNotifications();
      _logger.i('Local notification service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize notification service: $e');
      rethrow;
    }
  }

  /// Initialize time zones for scheduled notifications
  Future<void> _initializeTimeZones() async {
    tz.initializeTimeZones();
  }

  /// Initialize notification plugin
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  /// Create notification channels for different types of notifications
  Future<void> _createNotificationChannels() async {
    final List<AndroidNotificationChannel> channels = [
      // General notifications
      AndroidNotificationChannel(
        'general_channel',
        'General Notifications',
        description: 'General app notifications and updates',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_general'),
      ),

      // Alert notifications
      AndroidNotificationChannel(
        'alerts_channel',
        'Plant Alerts',
        description: 'Critical alerts about plant health and environmental issues',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_alert'),
        enableVibration: true,
      ),

      // Automation notifications
      AndroidNotificationChannel(
        'automation_channel',
        'Automation Events',
        description: 'Notifications about automated actions and schedules',
        importance: Importance.medium,
        sound: RawResourceAndroidNotificationSound('notification_automation'),
      ),

      // Analysis notifications
      AndroidNotificationChannel(
        'analysis_channel',
        'Plant Analysis',
        description: 'Notifications about plant health analysis results',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_analysis'),
      ),

      // Daily reports
      AndroidNotificationChannel(
        'daily_reports_channel',
        'Daily Reports',
        description: 'Daily cultivation reports and summaries',
        importance: Importance.medium,
        sound: RawResourceAndroidNotificationSound('notification_report'),
      ),

      // System notifications
      AndroidNotificationChannel(
        'system_channel',
        'System Messages',
        description: 'System notifications and maintenance messages',
        importance: Importance.low,
        sound: RawResourceAndroidNotificationSound('notification_system'),
      ),
    ];

    for (final channel in channels) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // Android permissions are requested at runtime
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Load notification settings from preferences
  Future<void> _loadNotificationSettings() async {
    _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
    _alertNotificationsEnabled = _prefs.getBool('alert_notifications_enabled') ?? true;
    _automationNotificationsEnabled = _prefs.getBool('automation_notifications_enabled') ?? true;
    _analysisNotificationsEnabled = _prefs.getBool('analysis_notifications_enabled') ?? true;
    _dailyReportsEnabled = _prefs.getBool('daily_reports_enabled') ?? true;
    _notificationCount = _prefs.getInt('notification_count') ?? 0;

    _logger.i('Notification settings loaded: enabled=$_notificationsEnabled');
  }

  /// Handle notification tap events
  void _onNotificationTapped(NotificationResponse response) {
    _logger.i('Notification tapped: ${response.payload}');
    // Handle navigation based on notification payload
    _handleNotificationNavigation(response.payload);
  }

  /// Handle navigation based on notification type
  void _handleNotificationNavigation(String? payload) {
    if (payload == null) return;

    try {
      final data = Map<String, dynamic>.from(
        // This would typically be JSON decoded
        {},
      );

      final notificationType = data['type'] as String?;
      final roomId = data['room_id'] as String?;

      // Navigate to appropriate screen based on notification type
      switch (notificationType) {
        case 'plant_alert':
          // Navigate to plant details screen
          break;
        case 'automation_event':
          // Navigate to automation screen
          break;
        case 'analysis_complete':
          // Navigate to analysis results screen
          break;
        case 'sensor_alert':
          // Navigate to sensor monitoring screen
          break;
        default:
          // Navigate to main dashboard
          break;
      }
    } catch (e) {
      _logger.e('Failed to handle notification navigation: $e');
    }
  }

  /// Show immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    NotificationType type = NotificationType.general,
    String? channelId,
  }) async {
    if (!_notificationsEnabled) return;

    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId ?? _getChannelForType(type),
        _getChannelNameForType(type),
        channelDescription: _getChannelDescriptionForType(type),
        importance: _getImportanceForType(type),
        priority: _getPriorityForType(type),
        sound: _getSoundForType(type),
        enableVibration: _shouldVibrateForType(type),
        icon: '@mipmap/ic_notification',
        color: _getColorForType(type),
        ledColor: _getLedColorForType(type),
        ledOnMs: 1000,
        ledOffMs: 500,
        category: _getCategoryForType(type),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: _getIOSSoundForType(type),
        badgeNumber: 1,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _generateNotificationId(),
        title,
        body,
        platformDetails,
        payload: payload,
      );

      _notificationCount++;
      await _prefs.setInt('notification_count', _notificationCount);

      _logger.i('Notification shown: $title');
    } catch (e) {
      _logger.e('Failed to show notification: $e');
    }
  }

  /// Show sensor alert notification
  Future<void> showSensorAlert({
    required String roomId,
    required String roomName,
    required String sensorType,
    required String alertMessage,
    required String severity,
  }) async {
    if (!_alertNotificationsEnabled) return;

    final title = '🚨 ${severity.toUpperCase()} Alert - $roomName';
    final body = '$sensorType: $alertMessage';

    final payload = {
      'type': 'sensor_alert',
      'room_id': roomId,
      'room_name': roomName,
      'sensor_type': sensorType,
      'severity': severity,
      'message': alertMessage,
      'timestamp': DateTime.now().toIso8601String(),
    }.toString();

    await showNotification(
      title: title,
      body: body,
      payload: payload,
      type: NotificationType.alert,
    );
  }

  /// Show automation event notification
  Future<void> showAutomationEvent({
    required String roomId,
    required String roomName,
    required String deviceType,
    required String action,
    bool success = true,
  }) async {
    if (!_automationNotificationsEnabled) return;

    final title = success ? '🤖 Automation Executed' : '⚠️ Automation Failed';
    final body = '$roomName: $deviceType - $action';

    final payload = {
      'type': 'automation_event',
      'room_id': roomId,
      'room_name': roomName,
      'device_type': deviceType,
      'action': action,
      'success': success,
      'timestamp': DateTime.now().toIso8601String(),
    }.toString();

    await showNotification(
      title: title,
      body: body,
      payload: payload,
      type: NotificationType.automation,
    );
  }

  /// Show plant analysis completion notification
  Future<void> showAnalysisComplete({
    required String strain,
    required List<String> symptoms,
    required String severity,
    int recommendationsCount = 0,
  }) async {
    if (!_analysisNotificationsEnabled) return;

    final title = '🌿 Plant Analysis Complete';
    final body = '$strain detected - $severity severity';

    if (recommendationsCount > 0) {
      final bodyWithRecommendations = '$body\n$recommendationsCount recommendations available';
      await showNotification(
        title: title,
        body: bodyWithRecommendations,
        payload: {
          'type': 'analysis_complete',
          'strain': strain,
          'symptoms': symptoms,
          'severity': severity,
          'recommendations_count': recommendationsCount,
          'timestamp': DateTime.now().toIso8601String(),
        }.toString(),
        type: NotificationType.analysis,
      );
    } else {
      await showNotification(
        title: title,
        body: body,
        payload: {
          'type': 'analysis_complete',
          'strain': strain,
          'symptoms': symptoms,
          'severity': severity,
          'recommendations_count': 0,
          'timestamp': DateTime.now().toIso8601String(),
        }.toString(),
        type: NotificationType.analysis,
      );
    }
  }

  /// Show daily cultivation report
  Future<void> showDailyReport({
    required Map<String, dynamic> reportData,
  }) async {
    if (!_dailyReportsEnabled) return;

    final title = '📊 Daily Cultivation Report';
    final activeRooms = reportData['active_rooms'] as int? ?? 0;
    final alertsCount = reportData['alerts_count'] as int? ?? 0;
    final automationActions = reportData['automation_actions'] as int? ?? 0;

    String body = '$activeRooms active rooms monitored';
    if (alertsCount > 0) {
      body += '\n⚠️ $alertsCount alerts generated';
    }
    if (automationActions > 0) {
      body += '\n🤖 $automationActions automation actions';
    }

    await showNotification(
      title: title,
      body: body,
      payload: {
        'type': 'daily_report',
        'report_data': reportData,
        'timestamp': DateTime.now().toIso8601String(),
      }.toString(),
      type: NotificationType.dailyReport,
    );
  }

  /// Schedule periodic notification
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    NotificationType type = NotificationType.general,
  }) async {
    if (!_notificationsEnabled) return;

    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _getChannelForType(type),
        _getChannelNameForType(type),
        channelDescription: _getChannelDescriptionForType(type),
        importance: _getImportanceForType(type),
        priority: _getPriorityForType(type),
        sound: _getSoundForType(type),
        enableVibration: _shouldVibrateForType(type),
        icon: '@mipmap/ic_notification',
        color: _getColorForType(type),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: _getIOSSoundForType(type),
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        _generateNotificationId(),
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        platformDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        androidAllowWhileIdle: true,
      );

      _logger.i('Scheduled notification: $title at ${scheduledTime.toIso8601String()}');
    } catch (e) {
      _logger.e('Failed to schedule notification: $e');
    }
  }

  /// Schedule repeating notification
  Future<void> scheduleRepeatingNotification({
    required String title,
    required String body,
    required RepeatInterval repeatInterval,
    String? payload,
    NotificationType type = NotificationType.general,
  }) async {
    if (!_notificationsEnabled) return;

    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _getChannelForType(type),
        _getChannelNameForType(type),
        channelDescription: _getChannelDescriptionForType(type),
        importance: _getImportanceForType(type),
        priority: _getPriorityForType(type),
        sound: _getSoundForType(type),
        enableVibration: false, // Disable vibration for repeating notifications
        icon: '@mipmap/ic_notification',
        color: _getColorForType(type),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false, // Disable sound for repeating notifications
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.periodicallyShow(
        _generateNotificationId(),
        title,
        body,
        _getRepeatInterval(repeatInterval),
        platformDetails,
        payload: payload,
      );

      _logger.i('Scheduled repeating notification: $title');
    } catch (e) {
      _logger.e('Failed to schedule repeating notification: $e');
    }
  }

  /// Schedule daily notifications
  Future<void> _scheduleDailyNotifications() async {
    if (!_dailyReportsEnabled) return;

    // Schedule daily cultivation report at 8 PM
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      20, // 8 PM
      0, // 0 minutes
      0, // 0 seconds
    );

    // If it's already past 8 PM, schedule for tomorrow
    final reportTime = now.isAfter(scheduledTime)
        ? scheduledTime.add(Duration(days: 1))
        : scheduledTime;

    await scheduleNotification(
      title: '📊 Daily Report Ready',
      body: 'Tap to view your daily cultivation summary',
      scheduledTime: reportTime,
      payload: {
        'type': 'daily_report_reminder',
        'scheduled_time': reportTime.toIso8601String(),
      }.toString(),
      type: NotificationType.dailyReport,
    );

    // Schedule reminder notifications (every 6 hours)
    await scheduleRepeatingNotification(
      title: '🌱 Check Your Plants',
      body: 'It\'s time to check on your plants and review sensor data',
      repeatInterval: RepeatInterval.hourly,
      payload: {'type': 'plant_check_reminder'}.toString(),
      type: NotificationType.general,
    );
  }

  /// Cancel notification by ID
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    _logger.i('Cancelled notification: $id');
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    _logger.i('Cancelled all notifications');
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Update notification settings
  Future<void> updateNotificationSettings({
    bool? notificationsEnabled,
    bool? alertNotificationsEnabled,
    bool? automationNotificationsEnabled,
    bool? analysisNotificationsEnabled,
    bool? dailyReportsEnabled,
  }) async {
    if (notificationsEnabled != null) {
      _notificationsEnabled = notificationsEnabled;
      await _prefs.setBool('notifications_enabled', notificationsEnabled);
    }

    if (alertNotificationsEnabled != null) {
      _alertNotificationsEnabled = alertNotificationsEnabled;
      await _prefs.setBool('alert_notifications_enabled', alertNotificationsEnabled);
    }

    if (automationNotificationsEnabled != null) {
      _automationNotificationsEnabled = automationNotificationsEnabled;
      await _prefs.setBool('automation_notifications_enabled', automationNotificationsEnabled);
    }

    if (analysisNotificationsEnabled != null) {
      _analysisNotificationsEnabled = analysisNotificationsEnabled;
      await _prefs.setBool('analysis_notifications_enabled', analysisNotificationsEnabled);
    }

    if (dailyReportsEnabled != null) {
      _dailyReportsEnabled = dailyReportsEnabled;
      await _prefs.setBool('daily_reports_enabled', dailyReportsEnabled);
    }

    _logger.i('Notification settings updated');
  }

  /// Get current notification settings
  Map<String, bool> getNotificationSettings() {
    return {
      'notifications_enabled': _notificationsEnabled,
      'alert_notifications_enabled': _alertNotificationsEnabled,
      'automation_notifications_enabled': _automationNotificationsEnabled,
      'analysis_notifications_enabled': _analysisNotificationsEnabled,
      'daily_reports_enabled': _dailyReportsEnabled,
    };
  }

  /// Get notification statistics
  Map<String, dynamic> getNotificationStatistics() {
    return {
      'total_notifications_sent': _notificationCount,
      'notifications_enabled': _notificationsEnabled,
      'alert_notifications_enabled': _alertNotificationsEnabled,
      'automation_notifications_enabled': _automationNotificationsEnabled,
      'analysis_notifications_enabled': _analysisNotificationsEnabled,
      'daily_reports_enabled': _dailyReportsEnabled,
      'last_notification_time': _prefs.getString('last_notification_time'),
      'app_version': AppConstants.appVersion,
    };
  }

  /// Generate unique notification ID
  int _generateNotificationId() {
    return DateTime.now().millisecondsSinceEpoch % 100000;
  }

  // Helper methods for notification configuration

  String _getChannelForType(NotificationType type) {
    switch (type) {
      case NotificationType.alert:
        return 'alerts_channel';
      case NotificationType.automation:
        return 'automation_channel';
      case NotificationType.analysis:
        return 'analysis_channel';
      case NotificationType.dailyReport:
        return 'daily_reports_channel';
      case NotificationType.system:
        return 'system_channel';
      default:
        return 'general_channel';
    }
  }

  String _getChannelNameForType(NotificationType type) {
    switch (type) {
      case NotificationType.alert:
        return 'Plant Alerts';
      case NotificationType.automation:
        return 'Automation Events';
      case NotificationType.analysis:
        return 'Plant Analysis';
      case NotificationType.dailyReport:
        return 'Daily Reports';
      case NotificationType.system:
        return 'System Messages';
      default:
        return 'General Notifications';
    }
  }

  String _getChannelDescriptionForType(NotificationType type) {
    switch (type) {
      case NotificationType.alert:
        return 'Critical alerts about plant health and environmental issues';
      case NotificationType.automation:
        return 'Notifications about automated actions and schedules';
      case NotificationType.analysis:
        return 'Notifications about plant health analysis results';
      case NotificationType.dailyReport:
        return 'Daily cultivation reports and summaries';
      case NotificationType.system:
        return 'System notifications and maintenance messages';
      default:
        return 'General app notifications and updates';
    }
  }

  Importance _getImportanceForType(NotificationType type) {
    switch (type) {
      case NotificationType.alert:
      case NotificationType.analysis:
        return Importance.high;
      case NotificationType.automation:
      case NotificationType.dailyReport:
        return Importance.medium;
      case NotificationType.system:
        return Importance.low;
      default:
        return Importance.defaultImportance;
    }
  }

  Priority _getPriorityForType(NotificationType type) {
    switch (type) {
      case NotificationType.alert:
      case NotificationType.analysis:
        return Priority.high;
      case NotificationType.automation:
      case NotificationType.dailyReport:
        return Priority.medium;
      case NotificationType.system:
        return Priority.low;
      default:
        return Priority.defaultPriority;
    }
  }

  String? _getSoundForType(NotificationType type) {
    switch (type) {
      case NotificationType.alert:
        return RawResourceAndroidNotificationSound('notification_alert');
      case NotificationType.automation:
        return RawResourceAndroidNotificationSound('notification_automation');
      case NotificationType.analysis:
        return RawResourceAndroidNotificationSound('notification_analysis');
      case NotificationType.dailyReport:
        return RawResourceAndroidNotificationSound('notification_report');
      case NotificationType.system:
        return RawResourceAndroidNotificationSound('notification_system');
      default:
        return RawResourceAndroidNotificationSound('notification_general');
    }
  }

  String _getIOSSoundForType(NotificationType type) {
    switch (type) {
      case NotificationType.alert:
        return 'alert.aiff';
      case NotificationType.analysis:
        return 'complete.aiff';
      default:
        return 'default.aiff';
    }
  }

  bool _shouldVibrateForType(NotificationType type) {
    switch (type) {
      case NotificationType.alert:
      case NotificationType.analysis:
        return true;
      default:
        return false;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.alert:
        return Colors.red;
      case NotificationType.automation:
        return Colors.blue;
      case NotificationType.analysis:
        return Colors.green;
      case NotificationType.dailyReport:
        return Colors.purple;
      case NotificationType.system:
        return Colors.grey;
      default:
        return Colors.teal;
    }
  }

  Color _getLedColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.alert:
        return const Color(0xFFFF0000); // Red
      case NotificationType.automation:
        return const Color(0xFF0000FF); // Blue
      case NotificationType.analysis:
        return const Color(0xFF00FF00); // Green
      default:
        return const Color(0xFFFFFF); // White
    }
  }

  String _getCategoryForType(NotificationType type) {
    switch (type) {
      case NotificationType.alert:
        return 'alarm';
      case NotificationType.automation:
        return 'event';
      case NotificationType.analysis:
        return 'reminder';
      default:
        return 'status';
    }
  }

  RepeatInterval _getRepeatInterval(RepeatInterval interval) {
    switch (interval) {
      case RepeatInterval.everyMinute:
        return RepeatInterval.everyMinute;
      case RepeatInterval.hourly:
        return RepeatInterval.hourly;
      case RepeatInterval.daily:
        return RepeatInterval.daily;
      case RepeatInterval.weekly:
        return RepeatInterval.weekly;
      default:
        return RepeatInterval.daily;
    }
  }
}

/// Enumeration for notification types
enum NotificationType {
  general,
  alert,
  automation,
  analysis,
  dailyReport,
  system,
}

/// Enumeration for repeat intervals
enum RepeatInterval {
  everyMinute,
  hourly,
  daily,
  weekly,
}