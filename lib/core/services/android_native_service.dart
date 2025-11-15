import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Comprehensive Android Native Integration Service
/// Handles all Android-specific features and hardware integrations
class AndroidNativeService {
  static const MethodChannel _channel = MethodChannel('com.cannaai.pro/native');
  static const MethodChannel _sensorChannel = MethodChannel('com.cannaai.pro/sensors');
  static const MethodChannel _cameraChannel = MethodChannel('com.cannaai.pro/camera');
  static const MethodChannel _bluetoothChannel = MethodChannel('com.cannaai.pro/bluetooth');
  static const MethodChannel _storageChannel = MethodChannel('com.cannaai.pro/storage');
  static const MethodChannel _notificationChannel = MethodChannel('com.cannaai.pro/notifications');
  static const MethodChannel _batteryChannel = MethodChannel('com.cannaai.pro/battery');
  static const MethodChannel _systemChannel = MethodChannel('com.cannaai.pro/system');

  static final Logger _logger = Logger();
  static bool _initialized = false;

  /// Initialize the native service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      _logger.i('🤖 Initializing Android Native Service...');

      // Set up method call handlers for bidirectional communication
      _setupMethodHandlers();

      // Check Android permissions
      await _checkPermissions();

      _initialized = true;
      _logger.i('✅ Android Native Service initialized successfully');
    } catch (e) {
      _logger.e('❌ Failed to initialize Android Native Service: $e');
      rethrow;
    }
  }

  /// Device Information
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      return result ?? {};
    } catch (e) {
      _logger.e('❌ Failed to get device info: $e');
      return {};
    }
  }

  /// Android Version Information
  static Future<String> getAndroidVersion() async {
    try {
      return await _channel.invokeMethod<String>('getPlatformVersion') ?? 'Unknown';
    } catch (e) {
      _logger.e('❌ Failed to get Android version: $e');
      return 'Unknown';
    }
  }

  /// Battery Information
  static Future<Map<String, dynamic>> getBatteryInfo() async {
    try {
      final result = await _batteryChannel.invokeMapMethod<String, dynamic>('getBatteryInfo');
      return result ?? {};
    } catch (e) {
      _logger.e('❌ Failed to get battery info: $e');
      return {};
    }
  }

  /// Request battery optimization exemption
  static Future<bool> requestBatteryOptimizationExemption() async {
    try {
      return await _batteryChannel.invokeMethod<bool>('requestBatteryOptimizationExemption') ?? false;
    } catch (e) {
      _logger.e('❌ Failed to request battery optimization exemption: $e');
      return false;
    }
  }

  /// System UI Configuration
  static Future<void> configureSystemUI({
    Color? statusBarColor,
    Color? navigationBarColor,
    bool? lightStatusBar,
    bool? lightNavigationBar,
    bool? immersiveMode,
  }) async {
    try {
      final args = {
        'statusBarColor': statusBarColor?.value,
        'navigationBarColor': navigationBarColor?.value,
        'lightStatusBar': lightStatusBar,
        'lightNavigationBar': lightNavigationBar,
        'immersiveMode': immersiveMode ?? false,
      };

      await _systemChannel.invokeMethod('configureSystemUI', args);
    } catch (e) {
      _logger.e('❌ Failed to configure system UI: $e');
    }
  }

  /// Screen Information
  static Future<Map<String, dynamic>> getScreenInfo() async {
    try {
      final result = await _systemChannel.invokeMapMethod<String, dynamic>('getScreenInfo');
      return result ?? {};
    } catch (e) {
      _logger.e('❌ Failed to get screen info: $e');
      return {};
    }
  }

  /// Enable/disable auto-rotate
  static Future<void> setAutoRotate(bool enabled) async {
    try {
      await _systemChannel.invokeMethod('setAutoRotate', {'enabled': enabled});
    } catch (e) {
      _logger.e('❌ Failed to set auto rotate: $e');
    }
  }

  /// Sensor Integration
  static Future<bool> isSensorAvailable(String sensorType) async {
    try {
      return await _sensorChannel.invokeMethod<bool>('isSensorAvailable', {'type': sensorType}) ?? false;
    } catch (e) {
      _logger.e('❌ Failed to check sensor availability: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getSensorData(String sensorType) async {
    try {
      final result = await _sensorChannel.invokeMapMethod<String, dynamic>('getSensorData', {'type': sensorType});
      return result ?? {};
    } catch (e) {
      _logger.e('❌ Failed to get sensor data: $e');
      return {};
    }
  }

  static Future<void> startSensorListening(String sensorType, {int interval = 1000}) async {
    try {
      await _sensorChannel.invokeMethod('startSensorListening', {
        'type': sensorType,
        'interval': interval,
      });
    } catch (e) {
      _logger.e('❌ Failed to start sensor listening: $e');
    }
  }

  static Future<void> stopSensorListening(String sensorType) async {
    try {
      await _sensorChannel.invokeMethod('stopSensorListening', {'type': sensorType});
    } catch (e) {
      _logger.e('❌ Failed to stop sensor listening: $e');
    }
  }

  /// Camera Integration
  static Future<bool> isCameraAvailable() async {
    try {
      return await _cameraChannel.invokeMethod<bool>('isCameraAvailable') ?? false;
    } catch (e) {
      _logger.e('❌ Failed to check camera availability: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getCameraInfo() async {
    try {
      final result = await _cameraChannel.invokeMapMethod<String, dynamic>('getCameraInfo');
      return result ?? {};
    } catch (e) {
      _logger.e('❌ Failed to get camera info: $e');
      return {};
    }
  }

  static Future<String?> captureImage({String? outputPath, int quality = 90}) async {
    try {
      final result = await _cameraChannel.invokeMethod<String>('captureImage', {
        'outputPath': outputPath,
        'quality': quality,
      });
      return result;
    } catch (e) {
      _logger.e('❌ Failed to capture image: $e');
      return null;
    }
  }

  static Future<String?> pickImageFromGallery() async {
    try {
      return await _cameraChannel.invokeMethod<String>('pickImageFromGallery');
    } catch (e) {
      _logger.e('❌ Failed to pick image from gallery: $e');
      return null;
    }
  }

  /// Bluetooth Integration
  static Future<bool> isBluetoothEnabled() async {
    try {
      return await _bluetoothChannel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (e) {
      _logger.e('❌ Failed to check Bluetooth status: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getBluetoothDevices() async {
    try {
      final result = await _bluetoothChannel.invokeListMethod('getDevices');
      return result?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      _logger.e('❌ Failed to get Bluetooth devices: $e');
      return [];
    }
  }

  static Future<bool> connectToDevice(String deviceId) async {
    try {
      return await _bluetoothChannel.invokeMethod<bool>('connect', {'deviceId': deviceId}) ?? false;
    } catch (e) {
      _logger.e('❌ Failed to connect to Bluetooth device: $e');
      return false;
    }
  }

  static Future<void> disconnectFromDevice(String deviceId) async {
    try {
      await _bluetoothChannel.invokeMethod('disconnect', {'deviceId': deviceId});
    } catch (e) {
      _logger.e('❌ Failed to disconnect from Bluetooth device: $e');
    }
  }

  /// Storage Integration
  static Future<String?> getExternalStoragePath() async {
    try {
      return await _storageChannel.invokeMethod<String>('getExternalStoragePath');
    } catch (e) {
      _logger.e('❌ Failed to get external storage path: $e');
      return null;
    }
  }

  static Future<String?> createAppDirectory() async {
    try {
      return await _storageChannel.invokeMethod<String>('createAppDirectory');
    } catch (e) {
      _logger.e('❌ Failed to create app directory: $e');
      return null;
    }
  }

  static Future<bool> saveFile(String filePath, String content) async {
    try {
      return await _storageChannel.invokeMethod<bool>('saveFile', {
        'filePath': filePath,
        'content': content,
      }) ?? false;
    } catch (e) {
      _logger.e('❌ Failed to save file: $e');
      return false;
    }
  }

  static Future<String?> readFile(String filePath) async {
    try {
      return await _storageChannel.invokeMethod<String>('readFile', {'filePath': filePath});
    } catch (e) {
      _logger.e('❌ Failed to read file: $e');
      return null;
    }
  }

  static Future<bool> deleteFile(String filePath) async {
    try {
      return await _storageChannel.invokeMethod<bool>('deleteFile', {'filePath': filePath}) ?? false;
    } catch (e) {
      _logger.e('❌ Failed to delete file: $e');
      return false;
    }
  }

  /// Share Integration
  static Future<void> shareText(String text, {String? subject}) async {
    try {
      await _channel.invokeMethod('shareText', {
        'text': text,
        'subject': subject,
      });
    } catch (e) {
      _logger.e('❌ Failed to share text: $e');
    }
  }

  static Future<void> shareFile(String filePath, {String? subject}) async {
    try {
      await _channel.invokeMethod('shareFile', {
        'filePath': filePath,
        'subject': subject,
      });
    } catch (e) {
      _logger.e('❌ Failed to share file: $e');
    }
  }

  /// Notification Integration
  static Future<void> createNotificationChannel({
    required String id,
    required String name,
    required String description,
    int importance = 4, // IMPORTANCE_DEFAULT
  }) async {
    try {
      await _notificationChannel.invokeMethod('createNotificationChannel', {
        'id': id,
        'name': name,
        'description': description,
        'importance': importance,
      });
    } catch (e) {
      _logger.e('❌ Failed to create notification channel: $e');
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? channelId,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _notificationChannel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
        'channelId': channelId ?? 'default',
        'data': data,
      });
    } catch (e) {
      _logger.e('❌ Failed to show notification: $e');
    }
  }

  /// Permission Management
  static Future<Map<String, bool>> checkPermissions() async {
    try {
      final result = await _channel.invokeMapMethod<String, bool>('checkPermissions');
      return result ?? {};
    } catch (e) {
      _logger.e('❌ Failed to check permissions: $e');
      return {};
    }
  }

  static Future<bool> requestPermission(String permission) async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission', {'permission': permission}) ?? false;
    } catch (e) {
      _logger.e('❌ Failed to request permission: $e');
      return false;
    }
  }

  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (e) {
      _logger.e('❌ Failed to open app settings: $e');
    }
  }

  /// App Management
  static Future<void> restartApp() async {
    try {
      await _channel.invokeMethod('restartApp');
    } catch (e) {
      _logger.e('❌ Failed to restart app: $e');
    }
  }

  static Future<void> exitApp() async {
    try {
      await _channel.invokeMethod('exitApp');
    } catch (e) {
      _logger.e('❌ Failed to exit app: $e');
    }
  }

  /// Vibration
  static Future<void> vibrate({int duration = 500}) async {
    try {
      await _channel.invokeMethod('vibrate', {'duration': duration});
    } catch (e) {
      _logger.e('❌ Failed to vibrate: $e');
    }
  }

  /// Toast Messages
  static Future<void> showToast(String message, {int duration = 2}) async {
    try {
      await _channel.invokeMethod('showToast', {
        'message': message,
        'duration': duration,
      });
    } catch (e) {
      _logger.e('❌ Failed to show toast: $e');
    }
  }

  /// Private methods
  static void _setupMethodHandlers() {
    // Handle calls from native side to Flutter
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSensorData':
          // Handle sensor data updates from native side
          _logger.d('📊 Received sensor data: ${call.arguments}');
          break;
        case 'onBluetoothConnection':
          // Handle Bluetooth connection updates
          _logger.d('🔵 Bluetooth connection status: ${call.arguments}');
          break;
        case 'onLowBattery':
          // Handle low battery warning
          _logger.w('🔋 Low battery warning: ${call.arguments}');
          break;
        default:
          _logger.w('⚠️ Unknown method call from native: ${call.method}');
      }
    });
  }

  static Future<void> _checkPermissions() async {
    try {
      final permissions = await checkPermissions();
      _logger.i('🔐 Permission status: $permissions');

      // Request critical permissions if not granted
      if (permissions['camera'] != true) {
        await requestPermission('camera');
      }
      if (permissions['storage'] != true) {
        await requestPermission('storage');
      }
      if (permissions['notifications'] != true) {
        await requestPermission('notifications');
      }
    } catch (e) {
      _logger.e('❌ Failed to check permissions: $e');
    }
  }

  /// Dispose method
  static void dispose() {
    _logger.i('🗑️ Disposing Android Native Service...');
    // Clean up any resources
    _initialized = false;
  }
}