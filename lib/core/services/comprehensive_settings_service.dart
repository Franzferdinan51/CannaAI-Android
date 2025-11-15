import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod/riverpod.dart';

import '../models/comprehensive/data_models.dart';
import 'comprehensive_ai_assistant_service.dart';
import 'comprehensive_api_service.dart';
import 'android_sensor_service.dart';

/// Comprehensive Settings Service
///
/// Manages all application settings, preferences, and configurations
/// including AI providers, automation rules, notifications, and system settings
class ComprehensiveSettingsService {
  static const String _settingsKey = 'app_settings';
  static const String _aiProvidersKey = 'ai_providers';
  static const String _automationSettingsKey = 'automation_settings';
  static const String _notificationSettingsKey = 'notification_settings';
  static const String _privacySettingsKey = 'privacy_settings';
  static const String _uiSettingsKey = 'ui_settings';
  static const String _sensorSettingsKey = 'sensor_settings';
  static const String _analyticsSettingsKey = 'analytics_settings';

  final SharedPreferences _prefs;
  final StreamController<AppSettings> _settingsController = StreamController<AppSettings>.broadcast();
  final StreamController<Map<String, dynamic>> _updatesController = StreamController<Map<String, dynamic>>.broadcast();

  // Cached settings
  AppSettings? _cachedSettings;
  Timer? _autoSaveTimer;

  // Settings streams
  Stream<AppSettings> get settingsStream => _settingsController.stream;
  Stream<Map<String, dynamic>> get updatesStream => _updatesController.stream;

  ComprehensiveSettingsService(this._prefs) {
    _loadSettings();
    _startAutoSave();
  }

  /// Load all settings from storage
  Future<void> _loadSettings() async {
    try {
      final settingsJson = _prefs.getString(_settingsKey);
      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson);
        _cachedSettings = AppSettings.fromJson(settingsMap);
      } else {
        _cachedSettings = _getDefaultSettings();
        await _saveSettings();
      }

      _settingsController.add(_cachedSettings!);
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _cachedSettings = _getDefaultSettings();
      _settingsController.add(_cachedSettings!);
    }
  }

  /// Save all settings to storage
  Future<void> _saveSettings() async {
    if (_cachedSettings == null) return;

    try {
      final settingsJson = jsonEncode(_cachedSettings!.toJson());
      await _prefs.setString(_settingsKey, settingsJson);
      debugPrint('Settings saved successfully');
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  /// Start auto-save timer
  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(Duration(seconds: 30), (_) {
      _saveSettings();
    });
  }

  /// Get default settings
  AppSettings _getDefaultSettings() {
    return AppSettings(
      version: '1.0.0',
      language: 'en',
      theme: AppThemeSettings(
        themeMode: ThemeMode.system,
        primaryColor: 0xFF2196F3,
        useCustomTheme: false,
        enableAnimations: true,
        reduceAnimations: false,
        highContrast: false,
        fontSize: FontSize.medium,
      ),
      aiProviders: AIProviderSettings(
        defaultProvider: AIProviderType.local,
        lmStudio: LMStudioSettings(
          enabled: true,
          baseUrl: 'http://localhost:1234',
          apiKey: '',
          modelId: '',
          maxTokens: 2048,
          temperature: 0.7,
          timeout: Duration(seconds: 30),
        ),
        openRouter: OpenRouterSettings(
          enabled: false,
          apiKey: '',
          modelId: 'anthropic/claude-3-sonnet',
          maxTokens: 2048,
          temperature: 0.7,
          timeout: Duration(seconds: 45),
        ),
        deviceML: DeviceMLSettings(
          enabled: true,
          useOnDeviceML: true,
          modelPath: '',
          confidenceThreshold: 0.7,
          inferenceTimeout: Duration(seconds: 10),
        ),
        offlineRules: OfflineRulesSettings(
          enabled: true,
          usePredefinedRules: true,
          customRules: {},
          rulePriority: RulePriority.hybrid,
        ),
        fallbackProvider: AIProviderType.offlineRules,
        autoFallback: true,
      ),
      automation: AutomationSettings(
        enabled: true,
        autoMode: false,
        scheduleEnabled: true,
        notificationsEnabled: true,
        schedules: {},
        globalRules: [],
        deviceIntegrations: DeviceIntegrationSettings(
          smartSwitches: SmartSwitchSettings(
            enabled: false,
            devices: {},
          ),
          climateControl: ClimateControlSettings(
            enabled: false,
            devices: {},
          ),
          lighting: LightingSettings(
            enabled: false,
            devices: {},
          ),
          irrigation: IrrigationSettings(
            enabled: false,
            devices: {},
          ),
        ),
      ),
      notifications: NotificationSettings(
        pushEnabled: true,
        emailEnabled: false,
        smsEnabled: false,
        alertTypes: AlertTypeSettings(
          healthAlerts: true,
          environmentAlerts: true,
          automationAlerts: true,
          yieldAlerts: true,
          systemAlerts: true,
          maintenanceAlerts: false,
        ),
        schedules: NotificationScheduleSettings(
          dailySummary: true,
          weeklyReport: true,
          monthlyReport: false,
          urgentAlerts: true,
        ),
        quietHours: QuietHoursSettings(
          enabled: false,
          startTime: TimeOfDay(hour: 22, minute: 0),
          endTime: TimeOfDay(hour: 7, minute: 0),
          allowUrgent: true,
        ),
      ),
      privacy: PrivacySettings(
        dataCollection: true,
        analyticsEnabled: true,
        crashReporting: true,
        usageStatistics: true,
        locationServices: false,
        cameraAccess: true,
        microphoneAccess: false,
        photoAccess: true,
        dataRetention: DataRetention.thirtyDays,
        shareData: false,
      ),
      sensor: SensorSettings(
        samplingInterval: Duration(minutes: 5),
        batchUploadSize: 100,
        offlineStorage: true,
        compressionEnabled: true,
        calibrations: {},
        thresholds: SensorThresholdSettings(
          temperature: SensorThreshold(min: 65.0, max: 85.0, optimalMin: 70.0, optimalMax: 80.0),
          humidity: SensorThreshold(min: 40.0, max: 70.0, optimalMin: 50.0, optimalMax: 60.0),
          ph: SensorThreshold(min: 5.5, max: 7.5, optimalMin: 6.0, optimalMax: 7.0),
          ec: SensorThreshold(min: 0.8, max: 3.0, optimalMin: 1.2, optimalMax: 2.0),
          co2: SensorThreshold(min: 400.0, max: 1500.0, optimalMin: 800.0, optimalMax: 1200.0),
        ),
      ),
      analytics: AnalyticsSettings(
        enabled: true,
        realTimeUpdates: true,
        historicalDataRetention: Duration(days: 365),
        chartRefreshInterval: Duration(minutes: 5),
        exportFormats: ['json', 'csv', 'pdf'],
        dashboardSettings: DashboardSettings(
          defaultTimeRange: '30d',
          showRealTimeData: true,
          enableDataExport: true,
          favoriteCharts: ['temperature_trend', 'plant_growth', 'health_score'],
        ),
      ),
      system: SystemSettings(
        autoBackup: true,
        backupInterval: Duration(hours: 6),
        maxBackupFiles: 10,
        cacheManagement: CacheSettings(
          enableCache: true,
          maxCacheSize: 100 * 1024 * 1024, // 100MB
          clearInterval: Duration(days: 7),
        ),
        performance: PerformanceSettings(
          enableBackgroundProcessing: true,
          maxConcurrentTasks: 3,
          memoryOptimization: true,
          batteryOptimization: true,
        ),
      ),
      network: NetworkSettings(
        offlineMode: false,
        syncOnConnect: true,
        retryAttempts: 3,
        timeout: Duration(seconds: 30),
        bandwidthOptimization: true,
        wifiOnly: false,
      ),
      security: SecuritySettings(
        biometricAuth: false,
        pinLock: false,
        autoLock: AutoLockSettings(
          enabled: false,
          timeout: Duration(minutes: 5),
        ),
        encryption: EncryptionSettings(
          enabled: true,
          algorithm: 'AES-256',
          keyRotation: true,
        ),
        sessionTimeout: Duration(hours: 8),
      ),
      experimental: ExperimentalSettings(
        betaFeatures: false,
        developerMode: false,
        debugLogs: false,
        advancedAnalytics: false,
        experimentalAI: false,
        customIntegrations: {},
      ),
      lastUpdated: DateTime.now(),
    );
  }

  // Getters
  AppSettings get settings => _cachedSettings ?? _getDefaultSettings();
  bool get isInitialized => _cachedSettings != null;

  // Update methods

  Future<void> updateThemeSettings(AppThemeSettings themeSettings) async {
    _cachedSettings = _cachedSettings!.copyWith(theme: themeSettings);
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'theme', 'data': themeSettings.toJson()});
    await _saveSettings();
  }

  Future<void> updateAIProviderSettings(AIProviderSettings aiSettings) async {
    _cachedSettings = _cachedSettings!.copyWith(aiProviders: aiSettings);
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'aiProviders', 'data': aiSettings.toJson()});
    await _saveSettings();
  }

  Future<void> updateAutomationSettings(AutomationSettings automationSettings) async {
    _cachedSettings = _cachedSettings!.copyWith(automation: automationSettings);
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'automation', 'data': automationSettings.toJson()});
    await _saveSettings();
  }

  Future<void> updateNotificationSettings(NotificationSettings notificationSettings) async {
    _cachedSettings = _cachedSettings!.copyWith(notifications: notificationSettings);
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'notifications', 'data': notificationSettings.toJson()});
    await _saveSettings();
  }

  Future<void> updatePrivacySettings(PrivacySettings privacySettings) async {
    _cachedSettings = _cachedSettings!.copyWith(privacy: privacySettings);
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'privacy', 'data': privacySettings.toJson()});
    await _saveSettings();
  }

  Future<void> updateSensorSettings(SensorSettings sensorSettings) async {
    _cachedSettings = _cachedSettings!.copyWith(sensor: sensorSettings);
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'sensor', 'data': sensorSettings.toJson()});
    await _saveSettings();
  }

  Future<void> updateAnalyticsSettings(AnalyticsSettings analyticsSettings) async {
    _cachedSettings = _cachedSettings!.copyWith(analytics: analyticsSettings);
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'analytics', 'data': analyticsSettings.toJson()});
    await _saveSettings();
  }

  Future<void> updateSystemSettings(SystemSettings systemSettings) async {
    _cachedSettings = _cachedSettings!.copyWith(system: systemSettings);
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'system', 'data': systemSettings.toJson()});
    await _saveSettings();
  }

  Future<void> updateNetworkSettings(NetworkSettings networkSettings) async {
    _cachedSettings = _cachedSettings!.copyWith(network: networkSettings);
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'network', 'data': networkSettings.toJson()});
    await _saveSettings();
  }

  Future<void> updateSecuritySettings(SecuritySettings securitySettings) async {
    _cachedSettings = _cachedSettings!.copyWith(security: securitySettings);
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'security', 'data': securitySettings.toJson()});
    await _saveSettings();
  }

  Future<void> updateExperimentalSettings(ExperimentalSettings experimentalSettings) async {
    _cachedSettings = _cachedSettings!.copyWith(experimental: experimentalSettings);
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'experimental', 'data': experimentalSettings.toJson()});
    await _saveSettings();
  }

  // Convenience methods for specific settings

  Future<void> setThemeMode(ThemeMode themeMode) async {
    final updatedTheme = _cachedSettings!.theme.copyWith(themeMode: themeMode);
    await updateThemeSettings(updatedTheme);
  }

  Future<void> setPrimaryColor(int color) async {
    final updatedTheme = _cachedSettings!.theme.copyWith(primaryColor: color);
    await updateThemeSettings(updatedTheme);
  }

  Future<void> setLanguage(String language) async {
    _cachedSettings = _cachedSettings!.copyWith(language: language);
    _settingsController.add(_cachedSettings!);
    await _saveSettings();
  }

  Future<void> setDefaultAIProvider(AIProviderType provider) async {
    final updatedAI = _cachedSettings!.aiProviders.copyWith(defaultProvider: provider);
    await updateAIProviderSettings(updatedAI);
  }

  Future<void> enableOfflineMode(bool enabled) async {
    final updatedNetwork = _cachedSettings!.network.copyWith(offlineMode: enabled);
    await updateNetworkSettings(updatedNetwork);
  }

  Future<void> setNotificationPreference(AlertTypeSettings alertType, bool enabled) async {
    final updatedNotifications = _cachedSettings!.notifications.copyWith(
      alertTypes: alertType,
    );
    await updateNotificationSettings(updatedNotifications);
  }

  // Validation methods

  bool validateAIProviderSettings(AIProviderSettings settings) {
    switch (settings.defaultProvider) {
      case AIProviderType.lmStudio:
        return settings.lmStudio.enabled && settings.lmStudio.baseUrl.isNotEmpty;
      case AIProviderType.openRouter:
        return settings.openRouter.enabled && settings.openRouter.apiKey.isNotEmpty;
      case AIProviderType.deviceML:
        return settings.deviceML.enabled && settings.deviceML.useOnDeviceML;
      case AIProviderType.offlineRules:
        return settings.offlineRules.enabled;
      default:
        return false;
    }
  }

  bool validateSensorSettings(SensorSettings settings) {
    return settings.samplingInterval.inSeconds >= 30 &&
           settings.batchUploadSize > 0 &&
           settings.batchUploadSize <= 1000;
  }

  bool validateNetworkSettings(NetworkSettings settings) {
    return settings.retryAttempts >= 0 &&
           settings.retryAttempts <= 10 &&
           settings.timeout.inSeconds > 0;
  }

  // Permission management

  Future<Map<Permission, PermissionStatus>> checkPermissions() async {
    final permissions = {
      Permission.camera: await Permission.camera.status,
      Permission.microphone: await Permission.microphone.status,
      Permission.storage: await Permission.storage.status,
      Permission.notification: await Permission.notification.status,
      Permission.location: await Permission.location.status,
    };

    return permissions;
  }

  Future<bool> requestPermission(Permission permission) async {
    try {
      final status = await permission.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting permission $permission: $e');
      return false;
    }
  }

  Future<void> requestAllPermissions() async {
    final permissions = [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.notification,
    ];

    for (final permission in permissions) {
      await requestPermission(permission);
    }
  }

  // Settings import/export

  Future<Map<String, dynamic>> exportSettings() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      final exportData = {
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': _cachedSettings!.toJson(),
        'deviceInfo': Platform.isAndroid
            ? await deviceInfo.androidInfo.then((info) => info.toMap())
            : await deviceInfo.iosInfo.then((info) => info.toMap()),
      };

      return exportData;
    } catch (e) {
      debugPrint('Error exporting settings: $e');
      return {};
    }
  }

  Future<bool> importSettings(Map<String, dynamic> importData) async {
    try {
      if (!importData.containsKey('settings')) {
        debugPrint('Invalid settings import data');
        return false;
      }

      final settingsMap = importData['settings'];
      final importedSettings = AppSettings.fromJson(settingsMap);

      // Validate imported settings
      if (!validateAIProviderSettings(importedSettings.aiProviders)) {
        debugPrint('Invalid AI provider settings in import');
        return false;
      }

      if (!validateSensorSettings(importedSettings.sensor)) {
        debugPrint('Invalid sensor settings in import');
        return false;
      }

      if (!validateNetworkSettings(importedSettings.network)) {
        debugPrint('Invalid network settings in import');
        return false;
      }

      // Update settings
      _cachedSettings = importedSettings.copyWith(
        lastUpdated: DateTime.now(),
      );

      _settingsController.add(_cachedSettings!);
      await _saveSettings();

      debugPrint('Settings imported successfully');
      return true;
    } catch (e) {
      debugPrint('Error importing settings: $e');
      return false;
    }
  }

  // Reset methods

  Future<void> resetToDefaults() async {
    _cachedSettings = _getDefaultSettings();
    _settingsController.add(_cachedSettings!);
    _updatesController.add({'type': 'reset', 'data': {}});
    await _saveSettings();
    debugPrint('Settings reset to defaults');
  }

  Future<void> resetCategory(SettingsCategory category) async {
    final defaultSettings = _getDefaultSettings();

    switch (category) {
      case SettingsCategory.theme:
        await updateThemeSettings(defaultSettings.theme);
        break;
      case SettingsCategory.aiProviders:
        await updateAIProviderSettings(defaultSettings.aiProviders);
        break;
      case SettingsCategory.automation:
        await updateAutomationSettings(defaultSettings.automation);
        break;
      case SettingsCategory.notifications:
        await updateNotificationSettings(defaultSettings.notifications);
        break;
      case SettingsCategory.privacy:
        await updatePrivacySettings(defaultSettings.privacy);
        break;
      case SettingsCategory.sensor:
        await updateSensorSettings(defaultSettings.sensor);
        break;
      case SettingsCategory.analytics:
        await updateAnalyticsSettings(defaultSettings.analytics);
        break;
      case SettingsCategory.system:
        await updateSystemSettings(defaultSettings.system);
        break;
      case SettingsCategory.network:
        await updateNetworkSettings(defaultSettings.network);
        break;
      case SettingsCategory.security:
        await updateSecuritySettings(defaultSettings.security);
        break;
      case SettingsCategory.experimental:
        await updateExperimentalSettings(defaultSettings.experimental);
        break;
    }
  }

  // Analytics and monitoring

  Future<Map<String, dynamic>> getSettingsAnalytics() async {
    try {
      final analytics = {
        'lastUpdated': _cachedSettings!.lastUpdated.toIso8601String(),
        'version': _cachedSettings!.version,
        'language': _cachedSettings!.language,
        'themeMode': _cachedSettings!.theme.themeMode.toString(),
        'defaultAIProvider': _cachedSettings!.aiProviders.defaultProvider.toString(),
        'automationEnabled': _cachedSettings!.automation.enabled,
        'notificationsEnabled': _cachedSettings!.notifications.pushEnabled,
        'offlineMode': _cachedSettings!.network.offlineMode,
        'biometricAuth': _cachedSettings!.security.biometricAuth,
        'betaFeatures': _cachedSettings!.experimental.betaFeatures,
        'developerMode': _cachedSettings!.experimental.developerMode,
      };

      return analytics;
    } catch (e) {
      debugPrint('Error getting settings analytics: $e');
      return {};
    }
  }

  Future<void> validateAllSettings() async {
    final issues = <String>[];

    // Validate AI providers
    if (!validateAIProviderSettings(_cachedSettings!.aiProviders)) {
      issues.add('AI provider settings are invalid');
    }

    // Validate sensor settings
    if (!validateSensorSettings(_cachedSettings!.sensor)) {
      issues.add('Sensor settings are invalid');
    }

    // Validate network settings
    if (!validateNetworkSettings(_cachedSettings!.network)) {
      issues.add('Network settings are invalid');
    }

    // Check permissions
    final permissions = await checkPermissions();
    final missingPermissions = permissions.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => entry.key.toString())
        .toList();

    if (missingPermissions.isNotEmpty) {
      issues.add('Missing permissions: ${missingPermissions.join(', ')}');
    }

    if (issues.isNotEmpty) {
      debugPrint('Settings validation issues: ${issues.join(', ')}');
    }
  }

  // Cleanup
  void dispose() {
    _autoSaveTimer?.cancel();
    _settingsController.close();
    _updatesController.close();
  }
}

// Data models for settings

enum AIProviderType {
  lmStudio,
  openRouter,
  deviceML,
  offlineRules,
}

enum ThemeMode {
  system,
  light,
  dark,
}

enum FontSize {
  small,
  medium,
  large,
}

enum RulePriority {
  offlineFirst,
  hybrid,
  aiFirst,
}

enum DataRetention {
  sevenDays,
  thirtyDays,
  ninetyDays,
  oneYear,
  forever,
}

enum SettingsCategory {
  theme,
  aiProviders,
  automation,
  notifications,
  privacy,
  sensor,
  analytics,
  system,
  network,
  security,
  experimental,
}

class AppSettings {
  final String version;
  final String language;
  final AppThemeSettings theme;
  final AIProviderSettings aiProviders;
  final AutomationSettings automation;
  final NotificationSettings notifications;
  final PrivacySettings privacy;
  final SensorSettings sensor;
  final AnalyticsSettings analytics;
  final SystemSettings system;
  final NetworkSettings network;
  final SecuritySettings security;
  final ExperimentalSettings experimental;
  final DateTime lastUpdated;

  AppSettings({
    required this.version,
    required this.language,
    required this.theme,
    required this.aiProviders,
    required this.automation,
    required this.notifications,
    required this.privacy,
    required this.sensor,
    required this.analytics,
    required this.system,
    required this.network,
    required this.security,
    required this.experimental,
    required this.lastUpdated,
  });

  AppSettings copyWith({
    String? version,
    String? language,
    AppThemeSettings? theme,
    AIProviderSettings? aiProviders,
    AutomationSettings? automation,
    NotificationSettings? notifications,
    PrivacySettings? privacy,
    SensorSettings? sensor,
    AnalyticsSettings? analytics,
    SystemSettings? system,
    NetworkSettings? network,
    SecuritySettings? security,
    ExperimentalSettings? experimental,
    DateTime? lastUpdated,
  }) {
    return AppSettings(
      version: version ?? this.version,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      aiProviders: aiProviders ?? this.aiProviders,
      automation: automation ?? this.automation,
      notifications: notifications ?? this.notifications,
      privacy: privacy ?? this.privacy,
      sensor: sensor ?? this.sensor,
      analytics: analytics ?? this.analytics,
      system: system ?? this.system,
      network: network ?? this.network,
      security: security ?? this.security,
      experimental: experimental ?? this.experimental,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'language': language,
    'theme': theme.toJson(),
    'aiProviders': aiProviders.toJson(),
    'automation': automation.toJson(),
    'notifications': notifications.toJson(),
    'privacy': privacy.toJson(),
    'sensor': sensor.toJson(),
    'analytics': analytics.toJson(),
    'system': system.toJson(),
    'network': network.toJson(),
    'security': security.toJson(),
    'experimental': experimental.toJson(),
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      version: json['version'] ?? '1.0.0',
      language: json['language'] ?? 'en',
      theme: AppThemeSettings.fromJson(json['theme'] ?? {}),
      aiProviders: AIProviderSettings.fromJson(json['aiProviders'] ?? {}),
      automation: AutomationSettings.fromJson(json['automation'] ?? {}),
      notifications: NotificationSettings.fromJson(json['notifications'] ?? {}),
      privacy: PrivacySettings.fromJson(json['privacy'] ?? {}),
      sensor: SensorSettings.fromJson(json['sensor'] ?? {}),
      analytics: AnalyticsSettings.fromJson(json['analytics'] ?? {}),
      system: SystemSettings.fromJson(json['system'] ?? {}),
      network: NetworkSettings.fromJson(json['network'] ?? {}),
      security: SecuritySettings.fromJson(json['security'] ?? {}),
      experimental: ExperimentalSettings.fromJson(json['experimental'] ?? {}),
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class AppThemeSettings {
  final ThemeMode themeMode;
  final int primaryColor;
  final bool useCustomTheme;
  final bool enableAnimations;
  final bool reduceAnimations;
  final bool highContrast;
  final FontSize fontSize;

  AppThemeSettings({
    required this.themeMode,
    required this.primaryColor,
    required this.useCustomTheme,
    required this.enableAnimations,
    required this.reduceAnimations,
    required this.highContrast,
    required this.fontSize,
  });

  AppThemeSettings copyWith({
    ThemeMode? themeMode,
    int? primaryColor,
    bool? useCustomTheme,
    bool? enableAnimations,
    bool? reduceAnimations,
    bool? highContrast,
    FontSize? fontSize,
  }) {
    return AppThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      primaryColor: primaryColor ?? this.primaryColor,
      useCustomTheme: useCustomTheme ?? this.useCustomTheme,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      highContrast: highContrast ?? this.highContrast,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.toString(),
    'primaryColor': primaryColor,
    'useCustomTheme': useCustomTheme,
    'enableAnimations': enableAnimations,
    'reduceAnimations': reduceAnimations,
    'highContrast': highContrast,
    'fontSize': fontSize.toString(),
  };

  factory AppThemeSettings.fromJson(Map<String, dynamic> json) {
    return AppThemeSettings(
      themeMode: ThemeMode.values.firstWhere((e) => e.toString() == json['themeMode']),
      primaryColor: json['primaryColor'] ?? 0xFF2196F3,
      useCustomTheme: json['useCustomTheme'] ?? false,
      enableAnimations: json['enableAnimations'] ?? true,
      reduceAnimations: json['reduceAnimations'] ?? false,
      highContrast: json['highContrast'] ?? false,
      fontSize: FontSize.values.firstWhere((e) => e.toString() == json['fontSize']),
    );
  }
}

class AIProviderSettings {
  final AIProviderType defaultProvider;
  final LMStudioSettings lmStudio;
  final OpenRouterSettings openRouter;
  final DeviceMLSettings deviceML;
  final OfflineRulesSettings offlineRules;
  final AIProviderType fallbackProvider;
  final bool autoFallback;

  AIProviderSettings({
    required this.defaultProvider,
    required this.lmStudio,
    required this.openRouter,
    required this.deviceML,
    required this.offlineRules,
    required this.fallbackProvider,
    required this.autoFallback,
  });

  AIProviderSettings copyWith({
    AIProviderType? defaultProvider,
    LMStudioSettings? lmStudio,
    OpenRouterSettings? openRouter,
    DeviceMLSettings? deviceML,
    OfflineRulesSettings? offlineRules,
    AIProviderType? fallbackProvider,
    bool? autoFallback,
  }) {
    return AIProviderSettings(
      defaultProvider: defaultProvider ?? this.defaultProvider,
      lmStudio: lmStudio ?? this.lmStudio,
      openRouter: openRouter ?? this.openRouter,
      deviceML: deviceML ?? this.deviceML,
      offlineRules: offlineRules ?? this.offlineRules,
      fallbackProvider: fallbackProvider ?? this.fallbackProvider,
      autoFallback: autoFallback ?? this.autoFallback,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultProvider': defaultProvider.toString(),
    'lmStudio': lmStudio.toJson(),
    'openRouter': openRouter.toJson(),
    'deviceML': deviceML.toJson(),
    'offlineRules': offlineRules.toJson(),
    'fallbackProvider': fallbackProvider.toString(),
    'autoFallback': autoFallback,
  };

  factory AIProviderSettings.fromJson(Map<String, dynamic> json) {
    return AIProviderSettings(
      defaultProvider: AIProviderType.values.firstWhere((e) => e.toString() == json['defaultProvider']),
      lmStudio: LMStudioSettings.fromJson(json['lmStudio'] ?? {}),
      openRouter: OpenRouterSettings.fromJson(json['openRouter'] ?? {}),
      deviceML: DeviceMLSettings.fromJson(json['deviceML'] ?? {}),
      offlineRules: OfflineRulesSettings.fromJson(json['offlineRules'] ?? {}),
      fallbackProvider: AIProviderType.values.firstWhere((e) => e.toString() == json['fallbackProvider']),
      autoFallback: json['autoFallback'] ?? true,
    );
  }
}

class LMStudioSettings {
  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String modelId;
  final int maxTokens;
  final double temperature;
  final Duration timeout;

  LMStudioSettings({
    required this.enabled,
    required this.baseUrl,
    required this.apiKey,
    required this.modelId,
    required this.maxTokens,
    required this.temperature,
    required this.timeout,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'modelId': modelId,
    'maxTokens': maxTokens,
    'temperature': temperature,
    'timeout': timeout.inSeconds,
  };

  factory LMStudioSettings.fromJson(Map<String, dynamic> json) {
    return LMStudioSettings(
      enabled: json['enabled'] ?? true,
      baseUrl: json['baseUrl'] ?? 'http://localhost:1234',
      apiKey: json['apiKey'] ?? '',
      modelId: json['modelId'] ?? '',
      maxTokens: json['maxTokens'] ?? 2048,
      temperature: (json['temperature'] ?? 0.7).toDouble(),
      timeout: Duration(seconds: json['timeout'] ?? 30),
    );
  }
}

class OpenRouterSettings {
  final bool enabled;
  final String apiKey;
  final String modelId;
  final int maxTokens;
  final double temperature;
  final Duration timeout;

  OpenRouterSettings({
    required this.enabled,
    required this.apiKey,
    required this.modelId,
    required this.maxTokens,
    required this.temperature,
    required this.timeout,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'apiKey': apiKey,
    'modelId': modelId,
    'maxTokens': maxTokens,
    'temperature': temperature,
    'timeout': timeout.inSeconds,
  };

  factory OpenRouterSettings.fromJson(Map<String, dynamic> json) {
    return OpenRouterSettings(
      enabled: json['enabled'] ?? false,
      apiKey: json['apiKey'] ?? '',
      modelId: json['modelId'] ?? 'anthropic/claude-3-sonnet',
      maxTokens: json['maxTokens'] ?? 2048,
      temperature: (json['temperature'] ?? 0.7).toDouble(),
      timeout: Duration(seconds: json['timeout'] ?? 45),
    );
  }
}

class DeviceMLSettings {
  final bool enabled;
  final bool useOnDeviceML;
  final String modelPath;
  final double confidenceThreshold;
  final Duration inferenceTimeout;

  DeviceMLSettings({
    required this.enabled,
    required this.useOnDeviceML,
    required this.modelPath,
    required this.confidenceThreshold,
    required this.inferenceTimeout,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'useOnDeviceML': useOnDeviceML,
    'modelPath': modelPath,
    'confidenceThreshold': confidenceThreshold,
    'inferenceTimeout': inferenceTimeout.inSeconds,
  };

  factory DeviceMLSettings.fromJson(Map<String, dynamic> json) {
    return DeviceMLSettings(
      enabled: json['enabled'] ?? true,
      useOnDeviceML: json['useOnDeviceML'] ?? true,
      modelPath: json['modelPath'] ?? '',
      confidenceThreshold: (json['confidenceThreshold'] ?? 0.7).toDouble(),
      inferenceTimeout: Duration(seconds: json['inferenceTimeout'] ?? 10),
    );
  }
}

class OfflineRulesSettings {
  final bool enabled;
  final bool usePredefinedRules;
  final Map<String, dynamic> customRules;
  final RulePriority rulePriority;

  OfflineRulesSettings({
    required this.enabled,
    required this.usePredefinedRules,
    required this.customRules,
    required this.rulePriority,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'usePredefinedRules': usePredefinedRules,
    'customRules': customRules,
    'rulePriority': rulePriority.toString(),
  };

  factory OfflineRulesSettings.fromJson(Map<String, dynamic> json) {
    return OfflineRulesSettings(
      enabled: json['enabled'] ?? true,
      usePredefinedRules: json['usePredefinedRules'] ?? true,
      customRules: Map<String, dynamic>.from(json['customRules'] ?? {}),
      rulePriority: RulePriority.values.firstWhere((e) => e.toString() == json['rulePriority']),
    );
  }
}

// Additional settings classes would continue here...
// For brevity, I'll include just the essential ones

class AutomationSettings {
  final bool enabled;
  final bool autoMode;
  final bool scheduleEnabled;
  final bool notificationsEnabled;
  final Map<String, dynamic> schedules;
  final List<dynamic> globalRules;
  final DeviceIntegrationSettings deviceIntegrations;

  AutomationSettings({
    required this.enabled,
    required this.autoMode,
    required this.scheduleEnabled,
    required this.notificationsEnabled,
    required this.schedules,
    required this.globalRules,
    required this.deviceIntegrations,
  });

  AutomationSettings copyWith({
    bool? enabled,
    bool? autoMode,
    bool? scheduleEnabled,
    bool? notificationsEnabled,
    Map<String, dynamic>? schedules,
    List<dynamic>? globalRules,
    DeviceIntegrationSettings? deviceIntegrations,
  }) {
    return AutomationSettings(
      enabled: enabled ?? this.enabled,
      autoMode: autoMode ?? this.autoMode,
      scheduleEnabled: scheduleEnabled ?? this.scheduleEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      schedules: schedules ?? this.schedules,
      globalRules: globalRules ?? this.globalRules,
      deviceIntegrations: deviceIntegrations ?? this.deviceIntegrations,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'autoMode': autoMode,
    'scheduleEnabled': scheduleEnabled,
    'notificationsEnabled': notificationsEnabled,
    'schedules': schedules,
    'globalRules': globalRules,
    'deviceIntegrations': deviceIntegrations.toJson(),
  };

  factory AutomationSettings.fromJson(Map<String, dynamic> json) {
    return AutomationSettings(
      enabled: json['enabled'] ?? true,
      autoMode: json['autoMode'] ?? false,
      scheduleEnabled: json['scheduleEnabled'] ?? true,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      schedules: Map<String, dynamic>.from(json['schedules'] ?? {}),
      globalRules: json['globalRules'] ?? [],
      deviceIntegrations: DeviceIntegrationSettings.fromJson(json['deviceIntegrations'] ?? {}),
    );
  }
}

class DeviceIntegrationSettings {
  final SmartSwitchSettings smartSwitches;
  final ClimateControlSettings climateControl;
  final LightingSettings lighting;
  final IrrigationSettings irrigation;

  DeviceIntegrationSettings({
    required this.smartSwitches,
    required this.climateControl,
    required this.lighting,
    required this.irrigation,
  });

  Map<String, dynamic> toJson() => {
    'smartSwitches': smartSwitches.toJson(),
    'climateControl': climateControl.toJson(),
    'lighting': lighting.toJson(),
    'irrigation': irrigation.toJson(),
  };

  factory DeviceIntegrationSettings.fromJson(Map<String, dynamic> json) {
    return DeviceIntegrationSettings(
      smartSwitches: SmartSwitchSettings.fromJson(json['smartSwitches'] ?? {}),
      climateControl: ClimateControlSettings.fromJson(json['climateControl'] ?? {}),
      lighting: LightingSettings.fromJson(json['lighting'] ?? {}),
      irrigation: IrrigationSettings.fromJson(json['irrigation'] ?? {}),
    );
  }
}

class SmartSwitchSettings {
  final bool enabled;
  final Map<String, dynamic> devices;

  SmartSwitchSettings({
    required this.enabled,
    required this.devices,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'devices': devices,
  };

  factory SmartSwitchSettings.fromJson(Map<String, dynamic> json) {
    return SmartSwitchSettings(
      enabled: json['enabled'] ?? false,
      devices: Map<String, dynamic>.from(json['devices'] ?? {}),
    );
  }
}

class ClimateControlSettings {
  final bool enabled;
  final Map<String, dynamic> devices;

  ClimateControlSettings({
    required this.enabled,
    required this.devices,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'devices': devices,
  };

  factory ClimateControlSettings.fromJson(Map<String, dynamic> json) {
    return ClimateControlSettings(
      enabled: json['enabled'] ?? false,
      devices: Map<String, dynamic>.from(json['devices'] ?? {}),
    );
  }
}

class LightingSettings {
  final bool enabled;
  final Map<String, dynamic> devices;

  LightingSettings({
    required this.enabled,
    required this.devices,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'devices': devices,
  };

  factory LightingSettings.fromJson(Map<String, dynamic> json) {
    return LightingSettings(
      enabled: json['enabled'] ?? false,
      devices: Map<String, dynamic>.from(json['devices'] ?? {}),
    );
  }
}

class IrrigationSettings {
  final bool enabled;
  final Map<String, dynamic> devices;

  IrrigationSettings({
    required this.enabled,
    required this.devices,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'devices': devices,
  };

  factory IrrigationSettings.fromJson(Map<String, dynamic> json) {
    return IrrigationSettings(
      enabled: json['enabled'] ?? false,
      devices: Map<String, dynamic>.from(json['devices'] ?? {}),
    );
  }
}

class NotificationSettings {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;
  final AlertTypeSettings alertTypes;
  final NotificationScheduleSettings schedules;
  final QuietHoursSettings quietHours;

  NotificationSettings({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.smsEnabled,
    required this.alertTypes,
    required this.schedules,
    required this.quietHours,
  });

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
    AlertTypeSettings? alertTypes,
    NotificationScheduleSettings? schedules,
    QuietHoursSettings? quietHours,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      alertTypes: alertTypes ?? this.alertTypes,
      schedules: schedules ?? this.schedules,
      quietHours: quietHours ?? this.quietHours,
    );
  }

  Map<String, dynamic> toJson() => {
    'pushEnabled': pushEnabled,
    'emailEnabled': emailEnabled,
    'smsEnabled': smsEnabled,
    'alertTypes': alertTypes.toJson(),
    'schedules': schedules.toJson(),
    'quietHours': quietHours.toJson(),
  };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      pushEnabled: json['pushEnabled'] ?? true,
      emailEnabled: json['emailEnabled'] ?? false,
      smsEnabled: json['smsEnabled'] ?? false,
      alertTypes: AlertTypeSettings.fromJson(json['alertTypes'] ?? {}),
      schedules: NotificationScheduleSettings.fromJson(json['schedules'] ?? {}),
      quietHours: QuietHoursSettings.fromJson(json['quietHours'] ?? {}),
    );
  }
}

class AlertTypeSettings {
  final bool healthAlerts;
  final bool environmentAlerts;
  final bool automationAlerts;
  final bool yieldAlerts;
  final bool systemAlerts;
  final bool maintenanceAlerts;

  AlertTypeSettings({
    required this.healthAlerts,
    required this.environmentAlerts,
    required this.automationAlerts,
    required this.yieldAlerts,
    required this.systemAlerts,
    required this.maintenanceAlerts,
  });

  Map<String, dynamic> toJson() => {
    'healthAlerts': healthAlerts,
    'environmentAlerts': environmentAlerts,
    'automationAlerts': automationAlerts,
    'yieldAlerts': yieldAlerts,
    'systemAlerts': systemAlerts,
    'maintenanceAlerts': maintenanceAlerts,
  };

  factory AlertTypeSettings.fromJson(Map<String, dynamic> json) {
    return AlertTypeSettings(
      healthAlerts: json['healthAlerts'] ?? true,
      environmentAlerts: json['environmentAlerts'] ?? true,
      automationAlerts: json['automationAlerts'] ?? true,
      yieldAlerts: json['yieldAlerts'] ?? true,
      systemAlerts: json['systemAlerts'] ?? true,
      maintenanceAlerts: json['maintenanceAlerts'] ?? false,
    );
  }
}

class NotificationScheduleSettings {
  final bool dailySummary;
  final bool weeklyReport;
  final bool monthlyReport;
  final bool urgentAlerts;

  NotificationScheduleSettings({
    required this.dailySummary,
    required this.weeklyReport,
    required this.monthlyReport,
    required this.urgentAlerts,
  });

  Map<String, dynamic> toJson() => {
    'dailySummary': dailySummary,
    'weeklyReport': weeklyReport,
    'monthlyReport': monthlyReport,
    'urgentAlerts': urgentAlerts,
  };

  factory NotificationScheduleSettings.fromJson(Map<String, dynamic> json) {
    return NotificationScheduleSettings(
      dailySummary: json['dailySummary'] ?? true,
      weeklyReport: json['weeklyReport'] ?? true,
      monthlyReport: json['monthlyReport'] ?? false,
      urgentAlerts: json['urgentAlerts'] ?? true,
    );
  }
}

class QuietHoursSettings {
  final bool enabled;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool allowUrgent;

  QuietHoursSettings({
    required this.enabled,
    required this.startTime,
    required this.endTime,
    required this.allowUrgent,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'startTime': '${startTime.hour}:${startTime.minute}',
    'endTime': '${endTime.hour}:${endTime.minute}',
    'allowUrgent': allowUrgent,
  };

  factory QuietHoursSettings.fromJson(Map<String, dynamic> json) {
    final startParts = (json['startTime'] as String).split(':');
    final endParts = (json['endTime'] as String).split(':');

    return QuietHoursSettings(
      enabled: json['enabled'] ?? false,
      startTime: TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      ),
      allowUrgent: json['allowUrgent'] ?? true,
    );
  }
}

class PrivacySettings {
  final bool dataCollection;
  final bool analyticsEnabled;
  final bool crashReporting;
  final bool usageStatistics;
  final bool locationServices;
  final bool cameraAccess;
  final bool microphoneAccess;
  final bool photoAccess;
  final DataRetention dataRetention;
  final bool shareData;

  PrivacySettings({
    required this.dataCollection,
    required this.analyticsEnabled,
    required this.crashReporting,
    required this.usageStatistics,
    required this.locationServices,
    required this.cameraAccess,
    required this.microphoneAccess,
    required this.photoAccess,
    required this.dataRetention,
    required this.shareData,
  });

  PrivacySettings copyWith({
    bool? dataCollection,
    bool? analyticsEnabled,
    bool? crashReporting,
    bool? usageStatistics,
    bool? locationServices,
    bool? cameraAccess,
    bool? microphoneAccess,
    bool? photoAccess,
    DataRetention? dataRetention,
    bool? shareData,
  }) {
    return PrivacySettings(
      dataCollection: dataCollection ?? this.dataCollection,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReporting: crashReporting ?? this.crashReporting,
      usageStatistics: usageStatistics ?? this.usageStatistics,
      locationServices: locationServices ?? this.locationServices,
      cameraAccess: cameraAccess ?? this.cameraAccess,
      microphoneAccess: microphoneAccess ?? this.microphoneAccess,
      photoAccess: photoAccess ?? this.photoAccess,
      dataRetention: dataRetention ?? this.dataRetention,
      shareData: shareData ?? this.shareData,
    );
  }

  Map<String, dynamic> toJson() => {
    'dataCollection': dataCollection,
    'analyticsEnabled': analyticsEnabled,
    'crashReporting': crashReporting,
    'usageStatistics': usageStatistics,
    'locationServices': locationServices,
    'cameraAccess': cameraAccess,
    'microphoneAccess': microphoneAccess,
    'photoAccess': photoAccess,
    'dataRetention': dataRetention.toString(),
    'shareData': shareData,
  };

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      dataCollection: json['dataCollection'] ?? true,
      analyticsEnabled: json['analyticsEnabled'] ?? true,
      crashReporting: json['crashReporting'] ?? true,
      usageStatistics: json['usageStatistics'] ?? true,
      locationServices: json['locationServices'] ?? false,
      cameraAccess: json['cameraAccess'] ?? true,
      microphoneAccess: json['microphoneAccess'] ?? false,
      photoAccess: json['photoAccess'] ?? true,
      dataRetention: DataRetention.values.firstWhere((e) => e.toString() == json['dataRetention']),
      shareData: json['shareData'] ?? false,
    );
  }
}

class SensorSettings {
  final Duration samplingInterval;
  final int batchUploadSize;
  final bool offlineStorage;
  final bool compressionEnabled;
  final Map<String, dynamic> calibrations;
  final SensorThresholdSettings thresholds;

  SensorSettings({
    required this.samplingInterval,
    required this.batchUploadSize,
    required this.offlineStorage,
    required this.compressionEnabled,
    required this.calibrations,
    required this.thresholds,
  });

  Map<String, dynamic> toJson() => {
    'samplingInterval': samplingInterval.inSeconds,
    'batchUploadSize': batchUploadSize,
    'offlineStorage': offlineStorage,
    'compressionEnabled': compressionEnabled,
    'calibrations': calibrations,
    'thresholds': thresholds.toJson(),
  };

  factory SensorSettings.fromJson(Map<String, dynamic> json) {
    return SensorSettings(
      samplingInterval: Duration(seconds: json['samplingInterval'] ?? 300),
      batchUploadSize: json['batchUploadSize'] ?? 100,
      offlineStorage: json['offlineStorage'] ?? true,
      compressionEnabled: json['compressionEnabled'] ?? true,
      calibrations: Map<String, dynamic>.from(json['calibrations'] ?? {}),
      thresholds: SensorThresholdSettings.fromJson(json['thresholds'] ?? {}),
    );
  }
}

class SensorThresholdSettings {
  final SensorThreshold temperature;
  final SensorThreshold humidity;
  final SensorThreshold ph;
  final SensorThreshold ec;
  final SensorThreshold co2;

  SensorThresholdSettings({
    required this.temperature,
    required this.humidity,
    required this.ph,
    required this.ec,
    required this.co2,
  });

  Map<String, dynamic> toJson() => {
    'temperature': temperature.toJson(),
    'humidity': humidity.toJson(),
    'ph': ph.toJson(),
    'ec': ec.toJson(),
    'co2': co2.toJson(),
  };

  factory SensorThresholdSettings.fromJson(Map<String, dynamic> json) {
    return SensorThresholdSettings(
      temperature: SensorThreshold.fromJson(json['temperature'] ?? {}),
      humidity: SensorThreshold.fromJson(json['humidity'] ?? {}),
      ph: SensorThreshold.fromJson(json['ph'] ?? {}),
      ec: SensorThreshold.fromJson(json['ec'] ?? {}),
      co2: SensorThreshold.fromJson(json['co2'] ?? {}),
    );
  }
}

class SensorThreshold {
  final double min;
  final double max;
  final double optimalMin;
  final double optimalMax;

  SensorThreshold({
    required this.min,
    required this.max,
    required this.optimalMin,
    required this.optimalMax,
  });

  Map<String, dynamic> toJson() => {
    'min': min,
    'max': max,
    'optimalMin': optimalMin,
    'optimalMax': optimalMax,
  };

  factory SensorThreshold.fromJson(Map<String, dynamic> json) {
    return SensorThreshold(
      min: (json['min'] ?? 0.0).toDouble(),
      max: (json['max'] ?? 100.0).toDouble(),
      optimalMin: (json['optimalMin'] ?? 0.0).toDouble(),
      optimalMax: (json['optimalMax'] ?? 100.0).toDouble(),
    );
  }
}

class AnalyticsSettings {
  final bool enabled;
  final bool realTimeUpdates;
  final Duration historicalDataRetention;
  final Duration chartRefreshInterval;
  final List<String> exportFormats;
  final DashboardSettings dashboardSettings;

  AnalyticsSettings({
    required this.enabled,
    required this.realTimeUpdates,
    required this.historicalDataRetention,
    required this.chartRefreshInterval,
    required this.exportFormats,
    required this.dashboardSettings,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'realTimeUpdates': realTimeUpdates,
    'historicalDataRetention': historicalDataRetention.inDays,
    'chartRefreshInterval': chartRefreshInterval.inSeconds,
    'exportFormats': exportFormats,
    'dashboardSettings': dashboardSettings.toJson(),
  };

  factory AnalyticsSettings.fromJson(Map<String, dynamic> json) {
    return AnalyticsSettings(
      enabled: json['enabled'] ?? true,
      realTimeUpdates: json['realTimeUpdates'] ?? true,
      historicalDataRetention: Duration(days: json['historicalDataRetention'] ?? 365),
      chartRefreshInterval: Duration(seconds: json['chartRefreshInterval'] ?? 300),
      exportFormats: List<String>.from(json['exportFormats'] ?? ['json', 'csv', 'pdf']),
      dashboardSettings: DashboardSettings.fromJson(json['dashboardSettings'] ?? {}),
    );
  }
}

class DashboardSettings {
  final String defaultTimeRange;
  final bool showRealTimeData;
  final bool enableDataExport;
  final List<String> favoriteCharts;

  DashboardSettings({
    required this.defaultTimeRange,
    required this.showRealTimeData,
    required this.enableDataExport,
    required this.favoriteCharts,
  });

  Map<String, dynamic> toJson() => {
    'defaultTimeRange': defaultTimeRange,
    'showRealTimeData': showRealTimeData,
    'enableDataExport': enableDataExport,
    'favoriteCharts': favoriteCharts,
  };

  factory DashboardSettings.fromJson(Map<String, dynamic> json) {
    return DashboardSettings(
      defaultTimeRange: json['defaultTimeRange'] ?? '30d',
      showRealTimeData: json['showRealTimeData'] ?? true,
      enableDataExport: json['enableDataExport'] ?? true,
      favoriteCharts: List<String>.from(json['favoriteCharts'] ?? ['temperature_trend', 'plant_growth', 'health_score']),
    );
  }
}

// Additional settings classes would continue here...

class SystemSettings {
  final bool autoBackup;
  final Duration backupInterval;
  final int maxBackupFiles;
  final CacheSettings cacheManagement;
  final PerformanceSettings performance;

  SystemSettings({
    required this.autoBackup,
    required this.backupInterval,
    required this.maxBackupFiles,
    required this.cacheManagement,
    required this.performance,
  });

  Map<String, dynamic> toJson() => {
    'autoBackup': autoBackup,
    'backupInterval': backupInterval.inHours,
    'maxBackupFiles': maxBackupFiles,
    'cacheManagement': cacheManagement.toJson(),
    'performance': performance.toJson(),
  };

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    return SystemSettings(
      autoBackup: json['autoBackup'] ?? true,
      backupInterval: Duration(hours: json['backupInterval'] ?? 6),
      maxBackupFiles: json['maxBackupFiles'] ?? 10,
      cacheManagement: CacheSettings.fromJson(json['cacheManagement'] ?? {}),
      performance: PerformanceSettings.fromJson(json['performance'] ?? {}),
    );
  }
}

class CacheSettings {
  final bool enableCache;
  final int maxCacheSize;
  final Duration clearInterval;

  CacheSettings({
    required this.enableCache,
    required this.maxCacheSize,
    required this.clearInterval,
  });

  Map<String, dynamic> toJson() => {
    'enableCache': enableCache,
    'maxCacheSize': maxCacheSize,
    'clearInterval': clearInterval.inDays,
  };

  factory CacheSettings.fromJson(Map<String, dynamic> json) {
    return CacheSettings(
      enableCache: json['enableCache'] ?? true,
      maxCacheSize: json['maxCacheSize'] ?? 104857600, // 100MB
      clearInterval: Duration(days: json['clearInterval'] ?? 7),
    );
  }
}

class PerformanceSettings {
  final bool enableBackgroundProcessing;
  final int maxConcurrentTasks;
  final bool memoryOptimization;
  final bool batteryOptimization;

  PerformanceSettings({
    required this.enableBackgroundProcessing,
    required this.maxConcurrentTasks,
    required this.memoryOptimization,
    required this.batteryOptimization,
  });

  Map<String, dynamic> toJson() => {
    'enableBackgroundProcessing': enableBackgroundProcessing,
    'maxConcurrentTasks': maxConcurrentTasks,
    'memoryOptimization': memoryOptimization,
    'batteryOptimization': batteryOptimization,
  };

  factory PerformanceSettings.fromJson(Map<String, dynamic> json) {
    return PerformanceSettings(
      enableBackgroundProcessing: json['enableBackgroundProcessing'] ?? true,
      maxConcurrentTasks: json['maxConcurrentTasks'] ?? 3,
      memoryOptimization: json['memoryOptimization'] ?? true,
      batteryOptimization: json['batteryOptimization'] ?? true,
    );
  }
}

class NetworkSettings {
  final bool offlineMode;
  final bool syncOnConnect;
  final int retryAttempts;
  final Duration timeout;
  final bool bandwidthOptimization;
  final bool wifiOnly;

  NetworkSettings({
    required this.offlineMode,
    required this.syncOnConnect,
    required this.retryAttempts,
    required this.timeout,
    required this.bandwidthOptimization,
    required this.wifiOnly,
  });

  Map<String, dynamic> toJson() => {
    'offlineMode': offlineMode,
    'syncOnConnect': syncOnConnect,
    'retryAttempts': retryAttempts,
    'timeout': timeout.inSeconds,
    'bandwidthOptimization': bandwidthOptimization,
    'wifiOnly': wifiOnly,
  };

  factory NetworkSettings.fromJson(Map<String, dynamic> json) {
    return NetworkSettings(
      offlineMode: json['offlineMode'] ?? false,
      syncOnConnect: json['syncOnConnect'] ?? true,
      retryAttempts: json['retryAttempts'] ?? 3,
      timeout: Duration(seconds: json['timeout'] ?? 30),
      bandwidthOptimization: json['bandwidthOptimization'] ?? true,
      wifiOnly: json['wifiOnly'] ?? false,
    );
  }
}

class SecuritySettings {
  final bool biometricAuth;
  final bool pinLock;
  final AutoLockSettings autoLock;
  final EncryptionSettings encryption;
  final Duration sessionTimeout;

  SecuritySettings({
    required this.biometricAuth,
    required this.pinLock,
    required this.autoLock,
    required this.encryption,
    required this.sessionTimeout,
  });

  Map<String, dynamic> toJson() => {
    'biometricAuth': biometricAuth,
    'pinLock': pinLock,
    'autoLock': autoLock.toJson(),
    'encryption': encryption.toJson(),
    'sessionTimeout': sessionTimeout.inHours,
  };

  factory SecuritySettings.fromJson(Map<String, dynamic> json) {
    return SecuritySettings(
      biometricAuth: json['biometricAuth'] ?? false,
      pinLock: json['pinLock'] ?? false,
      autoLock: AutoLockSettings.fromJson(json['autoLock'] ?? {}),
      encryption: EncryptionSettings.fromJson(json['encryption'] ?? {}),
      sessionTimeout: Duration(hours: json['sessionTimeout'] ?? 8),
    );
  }
}

class AutoLockSettings {
  final bool enabled;
  final Duration timeout;

  AutoLockSettings({
    required this.enabled,
    required this.timeout,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'timeout': timeout.inMinutes,
  };

  factory AutoLockSettings.fromJson(Map<String, dynamic> json) {
    return AutoLockSettings(
      enabled: json['enabled'] ?? false,
      timeout: Duration(minutes: json['timeout'] ?? 5),
    );
  }
}

class EncryptionSettings {
  final bool enabled;
  final String algorithm;
  final bool keyRotation;

  EncryptionSettings({
    required this.enabled,
    required this.algorithm,
    required this.keyRotation,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'algorithm': algorithm,
    'keyRotation': keyRotation,
  };

  factory EncryptionSettings.fromJson(Map<String, dynamic> json) {
    return EncryptionSettings(
      enabled: json['enabled'] ?? true,
      algorithm: json['algorithm'] ?? 'AES-256',
      keyRotation: json['keyRotation'] ?? true,
    );
  }
}

class ExperimentalSettings {
  final bool betaFeatures;
  final bool developerMode;
  final bool debugLogs;
  final bool advancedAnalytics;
  final bool experimentalAI;
  final Map<String, dynamic> customIntegrations;

  ExperimentalSettings({
    required this.betaFeatures,
    required this.developerMode,
    required this.debugLogs,
    required this.advancedAnalytics,
    required this.experimentalAI,
    required this.customIntegrations,
  });

  Map<String, dynamic> toJson() => {
    'betaFeatures': betaFeatures,
    'developerMode': developerMode,
    'debugLogs': debugLogs,
    'advancedAnalytics': advancedAnalytics,
    'experimentalAI': experimentalAI,
    'customIntegrations': customIntegrations,
  };

  factory ExperimentalSettings.fromJson(Map<String, dynamic> json) {
    return ExperimentalSettings(
      betaFeatures: json['betaFeatures'] ?? false,
      developerMode: json['developerMode'] ?? false,
      debugLogs: json['debugLogs'] ?? false,
      advancedAnalytics: json['advancedAnalytics'] ?? false,
      experimentalAI: json['experimentalAI'] ?? false,
      customIntegrations: Map<String, dynamic>.from(json['customIntegrations'] ?? {}),
    );
  }
}

// Riverpod providers
final settingsServiceProvider = FutureProvider<ComprehensiveSettingsService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return ComprehensiveSettingsService(prefs);
});

final settingsStreamProvider = StreamProvider<AppSettings>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return service.value!.settingsStream;
});