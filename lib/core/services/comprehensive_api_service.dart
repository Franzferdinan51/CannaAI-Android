// Comprehensive API service for CannaAI Android
// Matches all endpoints from the web application

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import '../models/comprehensive/data_models.dart';

class APIService {
  static final APIService _instance = APIService._internal();
  factory APIService() => _instance;
  APIService._internal();

  late Dio _dio;
  late IO.Socket _socket;
  late SharedPreferences _prefs;
  final Logger _logger = Logger();

  bool _isConnected = false;
  String _baseUrl = '';
  String _apiKey = '';

  // ==================== INITIALIZATION ====================

  Future<void> initialize({String baseUrl = 'http://192.168.1.100:3000', String? apiKey}) async {
    _baseUrl = baseUrl;
    _apiKey = apiKey ?? '';
    _prefs = await SharedPreferences.getInstance();

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => _logger.d(obj),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        _logger.d('Request: ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.d('Response: ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) {
        _logger.e('Error: ${error.message}');
        return handler.next(error);
      },
    ));

    // Initialize Socket.IO connection
    _initializeSocket();

    _isConnected = true;
    _logger.i('API Service initialized with baseUrl: $_baseUrl');
  }

  void _initializeSocket() {
    try {
      _socket = IO.io(
        _baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setPath('/api/socketio')
            .build(),
      );

      _socket.onConnect((_) {
        _logger.i('Socket connected');
        _socket.emit('authenticate', {'token': _apiKey});
      });

      _socket.onDisconnect((_) {
        _logger.i('Socket disconnected');
      });

      _socket.on('error', (error) {
        _logger.e('Socket error: $error');
      });

      // Real-time sensor data updates
      _socket.on('sensor_data', (data) {
        _handleSensorDataUpdate(data);
      });

      // Automation status updates
      _socket.on('automation_status', (data) {
        _handleAutomationStatusUpdate(data);
      });

    } catch (e) {
      _logger.e('Failed to initialize socket: $e');
    }
  }

  // ==================== AUTHENTICATION ====================

  Future<bool> authenticate(String email, String password) async {
    try {
      final response = await _dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        await _prefs.setString('auth_token', data['token']);
        await _prefs.setString('user_email', email);
        _apiKey = data['token'];

        // Reinitialize with new token
        await initialize(apiKey: _apiKey);

        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Authentication failed: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/auth/logout');
    } catch (e) {
      _logger.e('Logout error: $e');
    } finally {
      await _prefs.clear();
      _apiKey = '';
      _socket.disconnect();
    }
  }

  // ==================== USER MANAGEMENT ====================

  Future<User?> getCurrentUser() async {
    try {
      final response = await _dio.get('/api/user/profile');
      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get user: $e');
      return null;
    }
  }

  Future<User?> updateUserSettings(UserSettings settings) async {
    try {
      final response = await _dio.put('/api/user/settings', data: settings.toJson());
      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to update settings: $e');
      return null;
    }
  }

  // ==================== ROOM MANAGEMENT ====================

  Future<List<Room>> getRooms() async {
    try {
      final response = await _dio.get('/api/rooms');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Room.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get rooms: $e');
      return [];
    }
  }

  Future<Room?> createRoom(Room room) async {
    try {
      final response = await _dio.post('/api/rooms', data: room.toJson());
      if (response.statusCode == 201) {
        return Room.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to create room: $e');
      return null;
    }
  }

  Future<Room?> updateRoom(Room room) async {
    try {
      final response = await _dio.put('/api/rooms/${room.id}', data: room.toJson());
      if (response.statusCode == 200) {
        return Room.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to update room: $e');
      return null;
    }
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      await _dio.delete('/api/rooms/$roomId');
    } catch (e) {
      _logger.e('Failed to delete room: $e');
    }
  }

  // ==================== STRAIN MANAGEMENT ====================

  Future<List<Strain>> getStrains() async {
    try {
      final response = await _dio.get('/api/strains');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Strain.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get strains: $e');
      return [];
    }
  }

  Future<Strain?> createStrain(Strain strain) async {
    try {
      final response = await _dio.post('/api/strains', data: strain.toJson());
      if (response.statusCode == 201) {
        return Strain.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to create strain: $e');
      return null;
    }
  }

  // ==================== PLANT MANAGEMENT ====================

  Future<List<Plant>> getPlants({String? roomId}) async {
    try {
      String url = '/api/plants';
      if (roomId != null) {
        url += '?roomId=$roomId';
      }

      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Plant.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get plants: $e');
      return [];
    }
  }

  Future<Plant?> createPlant(Plant plant) async {
    try {
      final response = await _dio.post('/api/plants', data: plant.toJson());
      if (response.statusCode == 201) {
        return Plant.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to create plant: $e');
      return null;
    }
  }

  Future<Plant?> updatePlant(Plant plant) async {
    try {
      final response = await _dio.put('/api/plants/${plant.id}', data: plant.toJson());
      if (response.statusCode == 200) {
        return Plant.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to update plant: $e');
      return null;
    }
  }

  Future<void> deletePlant(String plantId) async {
    try {
      await _dio.delete('/api/plants/$plantId');
    } catch (e) {
      _logger.e('Failed to delete plant: $e');
    }
  }

  Future<List<PlantMeasurement>> getPlantMeasurements(String plantId) async {
    try {
      final response = await _dio.get('/api/plants/$plantId/measurements');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => PlantMeasurement.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get plant measurements: $e');
      return [];
    }
  }

  Future<PlantMeasurement?> addPlantMeasurement(String plantId, PlantMeasurement measurement) async {
    try {
      final response = await _dio.post('/api/plants/$plantId/measurements', data: measurement.toJson());
      if (response.statusCode == 201) {
        return PlantMeasurement.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to add plant measurement: $e');
      return null;
    }
  }

  // ==================== SENSOR DATA ====================

  Future<SensorData?> getCurrentSensorData(String roomId) async {
    try {
      final response = await _dio.get('/api/sensors/room/$roomId/current');
      if (response.statusCode == 200) {
        return SensorData.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get sensor data: $e');
      return null;
    }
  }

  Future<List<SensorData>> getSensorHistory(String roomId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      String url = '/api/sensors/room/$roomId/history';
      List<String> params = [];

      if (startDate != null) {
        params.add('start=${startDate.toIso8601String()}');
      }
      if (endDate != null) {
        params.add('end=${endDate.toIso8601String()}');
      }

      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => SensorData.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get sensor history: $e');
      return [];
    }
  }

  Future<void> updateSensorData(String roomId, SensorData sensorData) async {
    try {
      await _dio.post('/api/sensors/room/$roomId', data: sensorData.toJson());
    } catch (e) {
      _logger.e('Failed to update sensor data: $e');
    }
  }

  // ==================== ANALYSIS ====================

  Future<AnalysisResult?> analyzePlant(String plantId, {
    File? imageFile,
    Map<String, dynamic>? sensorData,
    AnalysisType type = AnalysisType.health,
  }) async {
    try {
      Map<String, dynamic> data = {
        'type': type.name,
        'sensorData': sensorData,
      };

      FormData formData = FormData.fromMap({
        'data': MultipartFile.fromString(jsonEncode(data), filename: 'data.json'),
      });

      if (imageFile != null) {
        formData.files.add(
          MapEntry(
            'image',
            await MultipartFile.fromFile(imageFile.path),
          ),
        );
      }

      final response = await _dio.post('/api/analyze', data: formData);
      if (response.statusCode == 200) {
        return AnalysisResult.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to analyze plant: $e');
      return null;
    }
  }

  Future<AnalysisResult?> autoAnalyzePlant(String plantId) async {
    try {
      final response = await _dio.post('/api/auto-analyze/$plantId');
      if (response.statusCode == 200) {
        return AnalysisResult.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to auto-analyze plant: $e');
      return null;
    }
  }

  Future<List<AnalysisResult>> getAnalysisHistory(String plantId) async {
    try {
      final response = await _dio.get('/api/analysis/plant/$plantId');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AnalysisResult.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get analysis history: $e');
      return [];
    }
  }

  // ==================== AI ASSISTANT ====================

  Future<List<AIChatSession>> getChatSessions() async {
    try {
      final response = await _dio.get('/api/chat/sessions');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AIChatSession.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get chat sessions: $e');
      return [];
    }
  }

  Future<AIChatSession?> createChatSession(String title, {String? plantId, String? roomId}) async {
    try {
      final response = await _dio.post('/api/chat/sessions', data: {
        'title': title,
        'contextPlantId': plantId,
        'contextRoomId': roomId,
      });
      if (response.statusCode == 201) {
        return AIChatSession.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to create chat session: $e');
      return null;
    }
  }

  Future<AIChatMessage?> sendMessage(String sessionId, String message, {List<File>? images}) async {
    try {
      Map<String, dynamic> data = {'message': message};

      FormData formData = FormData.fromMap({
        'data': MultipartFile.fromString(jsonEncode(data), filename: 'data.json'),
      });

      if (images != null) {
        for (int i = 0; i < images.length; i++) {
          formData.files.add(
            MapEntry(
              'image_$i',
              await MultipartFile.fromFile(images[i].path),
            ),
          );
        }
      }

      final response = await _dio.post('/api/chat/sessions/$sessionId/messages', data: formData);
      if (response.statusCode == 200) {
        return AIChatMessage.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to send message: $e');
      return null;
    }
  }

  // ==================== AUTOMATION ====================

  Future<List<AutomationRule>> getAutomationRules(String roomId) async {
    try {
      final response = await _dio.get('/api/automation/room/$roomId/rules');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AutomationRule.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get automation rules: $e');
      return [];
    }
  }

  Future<AutomationRule?> createAutomationRule(AutomationRule rule) async {
    try {
      final response = await _dio.post('/api/automation/rules', data: rule.toJson());
      if (response.statusCode == 201) {
        return AutomationRule.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to create automation rule: $e');
      return null;
    }
  }

  Future<AutomationRule?> updateAutomationRule(AutomationRule rule) async {
    try {
      final response = await _dio.put('/api/automation/rules/${rule.id}', data: rule.toJson());
      if (response.statusCode == 200) {
        return AutomationRule.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to update automation rule: $e');
      return null;
    }
  }

  Future<void> deleteAutomationRule(String ruleId) async {
    try {
      await _dio.delete('/api/automation/rules/$ruleId');
    } catch (e) {
      _logger.e('Failed to delete automation rule: $e');
    }
  }

  Future<void> executeAutomationRule(String ruleId) async {
    try {
      await _dio.post('/api/automation/rules/$ruleId/execute');
    } catch (e) {
      _logger.e('Failed to execute automation rule: $e');
    }
  }

  Future<List<AutomationHistory>> getAutomationHistory(String roomId) async {
    try {
      final response = await _dio.get('/api/automation/room/$roomId/history');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AutomationHistory.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get automation history: $e');
      return [];
    }
  }

  // ==================== INVENTORY ====================

  Future<List<InventoryItem>> getInventoryItems() async {
    try {
      final response = await _dio.get('/api/inventory');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => InventoryItem.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get inventory items: $e');
      return [];
    }
  }

  Future<InventoryItem?> createInventoryItem(InventoryItem item) async {
    try {
      final response = await _dio.post('/api/inventory', data: item.toJson());
      if (response.statusCode == 201) {
        return InventoryItem.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to create inventory item: $e');
      return null;
    }
  }

  Future<InventoryItem?> updateInventoryItem(InventoryItem item) async {
    try {
      final response = await _dio.put('/api/inventory/${item.id}', data: item.toJson());
      if (response.statusCode == 200) {
        return InventoryItem.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to update inventory item: $e');
      return null;
    }
  }

  Future<List<InventoryItem>> getLowStockItems() async {
    try {
      final response = await _dio.get('/api/inventory/low-stock');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => InventoryItem.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get low stock items: $e');
      return [];
    }
  }

  // ==================== HARVEST TRACKING ====================

  Future<List<HarvestRecord>> getHarvestRecords({String? roomId}) async {
    try {
      String url = '/api/harvest';
      if (roomId != null) {
        url += '?roomId=$roomId';
      }

      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => HarvestRecord.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get harvest records: $e');
      return [];
    }
  }

  Future<HarvestRecord?> createHarvestRecord(HarvestRecord record) async {
    try {
      final response = await _dio.post('/api/harvest', data: record.toJson());
      if (response.statusCode == 201) {
        return HarvestRecord.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to create harvest record: $e');
      return null;
    }
  }

  Future<HarvestRecord?> updateHarvestRecord(HarvestRecord record) async {
    try {
      final response = await _dio.put('/api/harvest/${record.id}', data: record.toJson());
      if (response.statusCode == 200) {
        return HarvestRecord.fromJson(response.data);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to update harvest record: $e');
      return null;
    }
  }

  // ==================== AI PROVIDER SETTINGS ====================

  Future<Map<String, dynamic>> getAIProviderSettings() async {
    try {
      final response = await _dio.get('/api/ai/providers');
      if (response.statusCode == 200) {
        return response.data;
      }
      return {};
    } catch (e) {
      _logger.e('Failed to get AI provider settings: $e');
      return {};
    }
  }

  Future<bool> updateAIProviderSettings(Map<String, dynamic> settings) async {
    try {
      final response = await _dio.put('/api/ai/providers', data: settings);
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Failed to update AI provider settings: $e');
      return false;
    }
  }

  Future<bool> testAIConnection(String provider) async {
    try {
      final response = await _dio.post('/api/ai/providers/$provider/test');
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Failed to test AI connection: $e');
      return false;
    }
  }

  // ==================== SYSTEM HEALTH & STATUS ====================

  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final response = await _dio.get('/api/health');
      if (response.statusCode == 200) {
        return response.data;
      }
      return {};
    } catch (e) {
      _logger.e('Failed to get system health: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getVersion() async {
    try {
      final response = await _dio.get('/api/version');
      if (response.statusCode == 200) {
        return response.data;
      }
      return {};
    } catch (e) {
      _logger.e('Failed to get version: $e');
      return {};
    }
  }

  // ==================== LIVE VISION ====================

  Future<String?> startLiveVision(String roomId) async {
    try {
      final response = await _dio.post('/api/live-vision/start', data: {'roomId': roomId});
      if (response.statusCode == 200) {
        return response.data['sessionId'];
      }
      return null;
    } catch (e) {
      _logger.e('Failed to start live vision: $e');
      return null;
    }
  }

  Future<void> stopLiveVision(String sessionId) async {
    try {
      await _dio.post('/api/live-vision/$sessionId/stop');
    } catch (e) {
      _logger.e('Failed to stop live vision: $e');
    }
  }

  Future<String?> captureLiveVisionImage(String sessionId) async {
    try {
      final response = await _dio.post('/api/live-vision/$sessionId/capture');
      if (response.statusCode == 200) {
        return response.data['imageUrl'];
      }
      return null;
    } catch (e) {
      _logger.e('Failed to capture live vision image: $e');
      return null;
    }
  }

  // ==================== TRICHOME ANALYSIS ====================

  Future<Map<String, dynamic>> analyzeTrichomes(File imageFile, {Map<String, dynamic>? options}) async {
    try {
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imageFile.path),
        if (options != null) 'options': MultipartFile.fromString(jsonEncode(options)),
      });

      final response = await _dio.post('/api/trichome-analysis', data: formData);
      if (response.statusCode == 200) {
        return response.data;
      }
      return {};
    } catch (e) {
      _logger.e('Failed to analyze trichomes: $e');
      return {};
    }
  }

  // ==================== COST TRACKING ====================

  Future<Map<String, dynamic>> getCostAnalysis({String? roomId, DateTime? startDate, DateTime? endDate}) async {
    try {
      Map<String, dynamic> params = {};
      if (roomId != null) params['roomId'] = roomId;
      if (startDate != null) params['startDate'] = startDate.toIso8601String();
      if (endDate != null) params['endDate'] = endDate.toIso8601String();

      final response = await _dio.get('/api/costs', queryParameters: params);
      if (response.statusCode == 200) {
        return response.data;
      }
      return {};
    } catch (e) {
      _logger.e('Failed to get cost analysis: $e');
      return {};
    }
  }

  // ==================== SOCKET EVENT HANDLERS ====================

  void _handleSensorDataUpdate(dynamic data) {
    // Emit real-time sensor data updates
    _socket.emit('sensor_data_update', data);
  }

  void _handleAutomationStatusUpdate(dynamic data) {
    // Emit automation status updates
    _socket.emit('automation_status_update', data);
  }

  // ==================== PUBLIC SOCKET ACCESS ====================

  IO.Socket get socket => _socket;

  // ==================== UTILITY METHODS ====================

  bool get isConnected => _isConnected;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url;
    initialize(baseUrl: url);
  }

  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/api/health');
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Connection test failed: $e');
      return false;
    }
  }

  void dispose() {
    _socket.disconnect();
    _dio.close();
    _isConnected = false;
  }
}

// ==================== API ERROR HANDLING ====================

class APIException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic response;

  APIException(this.message, {this.statusCode, this.response});

  @override
  String toString() {
    return 'APIException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}

// ==================== RESPONSE INTERCEPTOR ====================

class ResponseInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Handle unauthorized - maybe redirect to login
      throw APIException('Unauthorized', statusCode: 401);
    } else if (err.response?.statusCode == 403) {
      throw APIException('Forbidden', statusCode: 403);
    } else if (err.response?.statusCode == 404) {
      throw APIException('Not found', statusCode: 404);
    } else if (err.response?.statusCode == 500) {
      throw APIException('Server error', statusCode: 500);
    }
    super.onError(err, handler);
  }
}