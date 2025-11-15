import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'local_data_service.dart';
import 'local_ai_service.dart';
import 'local_sensor_service.dart';
import 'local_automation_service.dart';

/// Stub API service that redirects to local implementations
/// This maintains API compatibility while using only local services
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final Logger _logger = Logger();
  final LocalDataService _dataService = LocalDataService();
  final LocalAIService _aiService = LocalAIService();
  final LocalSensorService _sensorService = LocalSensorService();
  final LocalAutomationService _automationService = LocalAutomationService();

  bool _initialized = false;

  /// Initialize all local services
  Future<void> initialize({String? baseUrl}) async {
    if (_initialized) return;

    try {
      _logger.i('Initializing local services (offline mode)...');
      await _dataService.initialize();
      await _sensorService.initialize();
      await _automationService.initialize();
      _initialized = true;

      _logger.i('Local API service initialized successfully (offline-only)');
    } catch (e) {
      _logger.e('Failed to initialize local API service: $e');
      rethrow;
    }
  }

  // ==================== PLANT ANALYSIS ====================

  /// Analyze plant image (now uses local AI)
  Future<Map<String, dynamic>> analyzePlant({
    required String imagePath,
    required String strain,
    Map<String, dynamic>? environmentalData,
  }) async {
    try {
      _logger.i('Starting local plant analysis...');

      // Read image file
      final file = await File(imagePath).readAsBytes();

      // Perform local AI analysis
      final analysis = await _aiService.analyzePlantHealth(
        imageData: file,
        strain: strain,
        environmentalData: environmentalData,
      );

      // Save analysis results locally
      final savedAnalysis = await _dataService.savePlantAnalysis(
        imagePath: imagePath,
        strain: strain,
        symptoms: List<String>.from(analysis['symptoms']),
        confidenceScore: analysis['confidence_score'],
        recommendations: List<String>.from(analysis['recommendations']),
      );

      _logger.i('Plant analysis completed locally');
      return {
        'success': true,
        'data': savedAnalysis,
        'ai_analysis': analysis,
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Local plant analysis failed: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  /// Get plant analysis history
  Future<Map<String, dynamic>> getAnalysisHistory({String? roomId, int? limit}) async {
    try {
      final analyses = await _dataService.getPlantAnalysisHistory(roomId: roomId, limit: limit);

      return {
        'success': true,
        'data': analyses,
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to get analysis history: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  // ==================== SENSOR DATA ====================

  /// Get current sensor data for all rooms
  Future<Map<String, dynamic>> getSensorData() async {
    try {
      final sensorData = await _sensorService.getCurrentSensorData();

      return {
        'success': true,
        'data': sensorData,
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to get sensor data: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  /// Get sensor data history
  Future<Map<String, dynamic>> getSensorHistory({
    required String roomId,
    required String sensorType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final history = await _sensorService.getSensorHistory(
        roomId: roomId,
        sensorType: sensorType,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );

      return {
        'success': true,
        'data': history,
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to get sensor history: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  // ==================== STRAIN PROFILES ====================

  /// Get all strain profiles
  Future<Map<String, dynamic>> getStrainProfiles() async {
    try {
      final strains = await _dataService.getStrainProfiles();

      return {
        'success': true,
        'data': strains,
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to get strain profiles: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  /// Save strain profile
  Future<Map<String, dynamic>> saveStrainProfile(Map<String, dynamic> strainData) async {
    try {
      final savedStrain = await _dataService.saveStrainProfile(strainData);

      return {
        'success': true,
        'data': savedStrain,
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to save strain profile: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  // ==================== CHAT/AI ASSISTANT ====================

  /// Send chat message to AI assistant
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    String? sessionId,
    String? currentStrain,
    Map<String, dynamic>? environmentalContext,
  }) async {
    try {
      _logger.i('Processing chat message locally...');

      // Generate AI response using local service
      final aiResponse = await _aiService.generateCultivationAdvice(
        userMessage: message,
        currentStrain: currentStrain,
        environmentalContext: environmentalContext,
      );

      // Save chat history locally
      await _dataService.saveChatMessage(
        userMessage: message,
        aiResponse: aiResponse,
        sessionId: sessionId,
      );

      return {
        'success': true,
        'data': {
          'user_message': message,
          'ai_response': aiResponse,
          'session_id': sessionId,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to process chat message: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  /// Get chat history
  Future<Map<String, dynamic>> getChatHistory({String? sessionId, int? limit}) async {
    try {
      final history = await _dataService.getChatHistory(sessionId: sessionId, limit: limit);

      return {
        'success': true,
        'data': history,
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to get chat history: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  // ==================== AUTOMATION ====================

  /// Get automation schedules
  Future<Map<String, dynamic>> getAutomationSchedules(String roomId) async {
    try {
      final schedules = await _automationService.getAutomationSchedules(roomId);

      return {
        'success': true,
        'data': schedules,
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to get automation schedules: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  /// Add automation schedule
  Future<Map<String, dynamic>> addAutomationSchedule({
    required String roomId,
    required String deviceType,
    required String action,
    required String scheduleTime,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _automationService.addAutomationSchedule(
        roomId: roomId,
        deviceType: deviceType,
        action: action,
        scheduleTime: scheduleTime,
        parameters: parameters,
      );

      return {
        'success': true,
        'message': 'Automation schedule added locally',
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to add automation schedule: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  /// Trigger manual automation action
  Future<Map<String, dynamic>> triggerAutomation({
    required String roomId,
    required String deviceType,
    required String action,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final result = await _automationService.triggerManualAction(
        roomId: roomId,
        deviceType: deviceType,
        action: action,
        parameters: parameters,
      );

      return {
        'success': true,
        'data': result,
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to trigger automation: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  // ==================== ROOM MANAGEMENT ====================

  /// Get all rooms
  Future<Map<String, dynamic>> getRooms() async {
    try {
      final rooms = _sensorService.getAllRooms();

      return {
        'success': true,
        'data': rooms,
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to get rooms: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  /// Add new room
  Future<Map<String, dynamic>> addRoom({
    required String roomId,
    required String name,
    Map<String, dynamic>? settings,
  }) async {
    try {
      await _sensorService.addRoom(
        roomId: roomId,
        name: name,
        settings: settings,
      );

      return {
        'success': true,
        'message': 'Room added locally',
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to add room: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  /// Update room settings
  Future<Map<String, dynamic>> updateRoomSettings({
    required String roomId,
    Map<String, dynamic>? settings,
  }) async {
    try {
      await _sensorService.updateRoomSettings(
        roomId: roomId,
        settings: settings,
      );

      return {
        'success': true,
        'message': 'Room settings updated locally',
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to update room settings: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  /// Toggle room status
  Future<Map<String, dynamic>> toggleRoomStatus(String roomId) async {
    try {
      await _sensorService.toggleRoomStatus(roomId);

      return {
        'success': true,
        'message': 'Room status toggled locally',
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to toggle room status: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Check if app is in offline mode (always true)
  Future<bool> checkConnectivity() async {
    return false; // Always offline
  }

  /// Get app status and statistics
  Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      final dbStats = await _dataService.getDatabaseStats();
      final automationStats = await _automationService.getAutomationStatistics();

      return {
        'success': true,
        'data': {
          'app_mode': 'offline',
          'database_stats': dbStats,
          'automation_stats': automationStats,
          'services_initialized': _initialized,
          'version': AppConstants.appVersion,
          'offline_features': {
            'plant_analysis': true,
            'ai_chat': true,
            'sensor_simulation': true,
            'automation': true,
            'data_persistence': true,
          },
        },
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to get system status: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  /// Export all data
  Future<Map<String, dynamic>> exportData() async {
    try {
      final exportData = await _dataService.exportAllData();

      return {
        'success': true,
        'data': exportData,
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to export data: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  /// Clear old data
  Future<Map<String, dynamic>> clearOldData({int daysToKeep = 30}) async {
    try {
      await _dataService.clearOldData(daysToKeep: daysToKeep);

      return {
        'success': true,
        'message': 'Old data cleared successfully',
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Failed to clear old data: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  // ==================== LEGACY COMPATIBILITY ====================
  // These methods maintain compatibility with existing code
  // but return offline-appropriate responses

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _handleLegacyRequest('GET', path, queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return _handleLegacyRequest('POST', path, data: data, queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return _handleLegacyRequest('PUT', path, data: data, queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return _handleLegacyRequest('DELETE', path, data: data, queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return _handleLegacyRequest('PATCH', path, data: data, queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> uploadFile(String path, String filePath, {Map<String, dynamic>? data}) async {
    // Handle file upload as plant analysis
    if (path.contains('analyze')) {
      final strain = data?['strain'] ?? 'Unknown';
      return await analyzePlant(imagePath: filePath, strain: strain);
    }

    return {
      'success': false,
      'error': AppConstants.networkErrorMessage,
      'offline_mode': true,
    };
  }

  /// Handle legacy API requests and redirect to local implementations
  Future<Map<String, dynamic>> _handleLegacyRequest(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      _logger.d('Legacy API request: $method $path');

      // Route to appropriate local service based on path
      if (path.contains('analyze')) {
        if (method == 'POST') {
          final strain = data?['strain'] ?? queryParameters?['strain'] ?? 'Unknown';
          final imagePath = data?['image_path'] ?? '';
          return await analyzePlant(imagePath: imagePath, strain: strain);
        }
      } else if (path.contains('chat')) {
        if (method == 'POST') {
          final message = data?['message'] ?? '';
          final sessionId = data?['session_id'];
          return await sendChatMessage(message: message, sessionId: sessionId);
        }
      } else if (path.contains('sensors')) {
        if (method == 'GET') {
          final roomId = queryParameters?['room_id'];
          final sensorType = queryParameters?['sensor_type'];

          if (roomId != null && sensorType != null) {
            return await getSensorHistory(
              roomId: roomId,
              sensorType: sensorType,
              limit: queryParameters?['limit'],
            );
          } else {
            return await getSensorData();
          }
        }
      } else if (path.contains('strains')) {
        if (method == 'GET') {
          return await getStrainProfiles();
        } else if (method == 'POST') {
          return await saveStrainProfile(data ?? {});
        }
      } else if (path.contains('history')) {
        if (method == 'GET') {
          return await getAnalysisHistory(roomId: queryParameters?['room_id']);
        }
      } else if (path.contains('automation')) {
        if (method == 'GET') {
          final roomId = queryParameters?['room_id'] ?? '';
          return await getAutomationSchedules(roomId);
        } else if (method == 'POST') {
          return await addAutomationSchedule(
            roomId: data?['room_id'] ?? '',
            deviceType: data?['device_type'] ?? '',
            action: data?['action'] ?? '',
            scheduleTime: data?['schedule_time'] ?? '',
            parameters: data?['parameters'],
          );
        }
      }

      // Default response for unhandled paths
      return {
        'success': false,
        'error': AppConstants.networkErrorMessage,
        'message': 'Feature not available in offline mode',
        'offline_mode': true,
      };
    } catch (e) {
      _logger.e('Legacy request failed: $e');
      return {
        'success': false,
        'error': AppConstants.serverErrorMessage,
        'offline_mode': true,
      };
    }
  }

  // Placeholder methods for compatibility
  void setAuthToken(String token) {
    _logger.i('Auth token ignored (offline mode)');
  }

  void clearAuthToken() {
    _logger.i('Auth token cleared (offline mode)');
  }

  String get baseUrl => 'offline://local';

  void updateBaseUrl(String newBaseUrl) {
    _logger.i('Base URL update ignored (offline mode)');
  }

  void setHeaders(Map<String, dynamic> headers) {
    _logger.i('Headers set ignored (offline mode)');
  }

  void clearHeaders() {
    _logger.i('Headers cleared (offline mode)');
  }

  /// Dispose of all services
  Future<void> dispose() async {
    _sensorService.dispose();
    _automationService.dispose();
    await _dataService.close();
    _initialized = false;
    _logger.i('Local API service disposed');
  }
}