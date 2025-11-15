// Comprehensive AI Assistant service for CannaAI Android
// Multi-provider AI system with chat interface

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/comprehensive/data_models.dart';
import 'comprehensive_api_service.dart';
import 'ai_providers/base_ai_provider.dart';
import 'ai_providers/lm_studio_provider.dart';
import 'ai_providers/openrouter_provider.dart';
import 'ai_providers/offline_rule_provider.dart';
import 'ai_providers/device_ml_provider.dart';

class AIAssistantService {
  static final AIAssistantService _instance = AIAssistantService._internal();
  factory AIAssistantService() => _instance;
  AIAssistantService._internal();

  final Logger _logger = Logger();
  final APIService _apiService = APIService();
  final ImagePicker _imagePicker = ImagePicker();

  // AI Providers
  late Map<AIProvider, BaseAIProvider> _providers;
  AIProvider _primaryProvider = AIProvider.deviceML;

  // Chat sessions
  final Map<String, StreamController<AIChatEvent>> _sessionControllers = {};
  final Map<String, List<AIChatMessage>> _sessionMessages = {};

  // Settings and configuration
  AISettings _aiSettings = AISettings(
    primaryProvider: AIProvider.deviceML,
    providers: {},
    enableLocalAnalysis: true,
    enableCloudAnalysis: false,
    preferences: AnalysisPreferences(
      confidenceThreshold: 0.7,
      includeImageAnalysis: true,
      includeEnvironmentalContext: true,
      enabledTypes: [AnalysisType.health, AnalysisType.pest, AnalysisType.nutrient],
    ),
  );

  bool _isInitialized = false;

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize AI providers
      _providers = {
        AIProvider.lmStudio: LMStudioProvider(),
        AIProvider.openRouter: OpenRouterProvider(),
        AIProvider.openai: OpenRouterProvider(), // Using OpenRouter as fallback
        AIProvider.offline: OfflineRuleProvider(),
        AIProvider.deviceML: DeviceMLProvider(),
      };

      // Load saved settings
      await _loadAISettings();

      // Configure providers
      await _configureProviders();

      _isInitialized = true;
      _logger.i('AI Assistant Service initialized with ${_providers.length} providers');
    } catch (e) {
      _logger.e('Failed to initialize AI Assistant Service: $e');
    }
  }

  Future<void> _loadAISettings() async {
    try {
      final serverSettings = await _apiService.getAIProviderSettings();
      if (serverSettings.isNotEmpty) {
        // TODO: Parse server settings and update local settings
        _logger.i('Loaded AI settings from server');
      }
    } catch (e) {
      _logger.e('Failed to load AI settings from server, using defaults: $e');
    }
  }

  Future<void> _configureProviders() async {
    for (final entry in _providers.entries) {
      try {
        final provider = entry.value;
        final config = _aiSettings.providers[entry.key] ??
            AIProviderConfig(
              baseUrl: '',
              apiKey: '',
              model: _getDefaultModel(entry.key),
              isEnabled: true,
            );

        await provider.configure(config);
        _logger.i('Configured ${entry.key.name} provider');
      } catch (e) {
        _logger.e('Failed to configure ${entry.key.name} provider: $e');
      }
    }
  }

  String _getDefaultModel(AIProvider provider) {
    switch (provider) {
      case AIProvider.lmStudio:
        return 'llama-2-7b-chat';
      case AIProvider.openRouter:
        return 'anthropic/claude-3-haiku';
      case AIProvider.openai:
        return 'gpt-3.5-turbo';
      case AIProvider.deviceML:
        return 'mobilebert-base';
      case AIProvider.offline:
        return 'rules-engine';
    }
  }

  // ==================== CHAT SESSION MANAGEMENT ====================

  Future<List<AIChatSession>> getChatSessions() async {
    try {
      final sessions = await _apiService.getChatSessions();

      // Load messages for each session
      for (final session in sessions) {
        await _loadSessionMessages(session.id);
      }

      return sessions;
    } catch (e) {
      _logger.e('Failed to get chat sessions: $e');
      return [];
    }
  }

  Future<AIChatSession?> createChatSession(String title, {String? plantId, String? roomId}) async {
    try {
      final session = await _apiService.createChatSession(title, plantId: plantId, roomId: roomId);
      if (session != null) {
        _sessionControllers[session.id] = StreamController<AIChatEvent>.broadcast();
        _sessionMessages[session.id] = [];
        _emitSessionEvent(session.id, AIChatEvent.sessionCreated(session));
      }
      return session;
    } catch (e) {
      _logger.e('Failed to create chat session: $e');
      return null;
    }
  }

  Future<void> deleteChatSession(String sessionId) async {
    try {
      await _apiService.deleteChatSession(sessionId);

      final controller = _sessionControllers.remove(sessionId);
      controller?.close();

      _sessionMessages.remove(sessionId);
    } catch (e) {
      _logger.e('Failed to delete chat session: $e');
    }
  }

  Future<void> _loadSessionMessages(String sessionId) async {
    try {
      // TODO: Load messages from local database or API
      _sessionMessages[sessionId] = [];
    } catch (e) {
      _logger.e('Failed to load session messages: $e');
    }
  }

  // ==================== CHAT MESSAGING ====================

  Future<AIChatMessage?> sendMessage(String sessionId, String message, {List<File>? images}) async {
    try {
      _emitSessionEvent(sessionId, AIChatEvent.messageSending(message));

      // Add user message to session
      final userMessage = AIChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'user',
        content: message,
        timestamp: DateTime.now(),
        images: images?.map((file) => file.path).toList() ?? [],
        isFromAI: false,
      );

      _addMessageToSession(sessionId, userMessage);
      _emitSessionEvent(sessionId, AIChatEvent.messageReceived(userMessage));

      // Generate AI response
      final aiResponse = await _generateAIResponse(sessionId, message, images);

      if (aiResponse != null) {
        _addMessageToSession(sessionId, aiResponse);
        _emitSessionEvent(sessionId, AIChatEvent.messageReceived(aiResponse));
        return aiResponse;
      }

      return null;
    } catch (e) {
      _logger.e('Failed to send message: $e');
      _emitSessionEvent(sessionId, AIChatEvent.error('Failed to send message: $e'));
      return null;
    }
  }

  Future<AIChatMessage?> _generateAIResponse(String sessionId, String message, List<File>? images) async {
    try {
      // Get context information
      final context = await _buildChatContext(sessionId);

      // Try primary provider first
      var response = await _generateResponseWithProvider(_primaryProvider, message, images, context);

      // Fallback to offline provider if primary fails
      if (response == null && _primaryProvider != AIProvider.offline) {
        _logger.w('Primary provider failed, trying offline provider');
        response = await _generateResponseWithProvider(AIProvider.offline, message, images, context);
      }

      if (response != null) {
        return AIChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: response.content,
          timestamp: DateTime.now(),
          images: [],
          modelUsed: response.model,
          isFromAI: true,
          metadata: {
            'provider': response.provider,
            'confidence': response.confidence,
            'context': context,
          },
        );
      }

      return null;
    } catch (e) {
      _logger.e('Failed to generate AI response: $e');
      return null;
    }
  }

  Future<AIProviderResponse?> _generateResponseWithProvider(
    AIProvider provider,
    String message,
    List<File>? images,
    Map<String, dynamic> context,
  ) async {
    try {
      final aiProvider = _providers[provider];
      if (aiProvider == null || !_isProviderEnabled(provider)) {
        return null;
      }

      // Prepare request
      final request = AIProviderRequest(
        message: message,
        images: images,
        context: context,
        systemPrompt: _getSystemPrompt(context),
        temperature: 0.7,
        maxTokens: 1000,
      );

      // Generate response
      final response = await aiProvider.generateResponse(request);
      return response;
    } catch (e) {
      _logger.e('Failed to generate response with ${provider.name}: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _buildChatContext(String sessionId) async {
    final context = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      // Get session details
      final sessions = await getChatSessions();
      final session = sessions.firstWhere((s) => s.id == sessionId);

      if (session.contextPlantId != null) {
        // Add plant context
        context['plant'] = await _getPlantContext(session.contextPlantId!);
      }

      if (session.contextRoomId != null) {
        // Add room context
        context['room'] = await _getRoomContext(session.contextRoomId!);
      }

      // Add recent messages for context
      final messages = _sessionMessages[sessionId] ?? [];
      if (messages.isNotEmpty) {
        context['recentMessages'] = messages
            .skip(messages.length - 5) // Last 5 messages
            .map((msg) => {
                  'role': msg.role,
                  'content': msg.content,
                  'timestamp': msg.timestamp.toIso8601String(),
                })
            .toList();
      }

    } catch (e) {
      _logger.e('Failed to build chat context: $e');
    }

    return context;
  }

  Future<Map<String, dynamic>?> _getPlantContext(String plantId) async {
    try {
      final plants = await _apiService.getPlants();
      final plant = plants.firstWhere((p) => p.id == plantId);

      return {
        'id': plant.id,
        'name': plant.name,
        'strain': plant.strainId,
        'stage': plant.currentStage.name,
        'health': plant.healthStatus.name,
        'age': plant.ageInDays,
        'lastAnalysis': await _getLatestAnalysisContext(plantId),
      };
    } catch (e) {
      _logger.e('Failed to get plant context: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getRoomContext(String roomId) async {
    try {
      final rooms = await _apiService.getRooms();
      final room = rooms.firstWhere((r) => r.id == roomId);

      final sensorData = await _apiService.getCurrentSensorData(roomId);

      return {
        'id': room.id,
        'name': room.name,
        'type': room.type.name,
        'currentSensorData': sensorData?.toJson(),
      };
    } catch (e) {
      _logger.e('Failed to get room context: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getLatestAnalysisContext(String plantId) async {
    try {
      final analyses = await _apiService.getAnalysisHistory(plantId);
      if (analyses.isNotEmpty) {
        final latestAnalysis = analyses.first;
        return {
          'healthScore': latestAnalysis.healthScore,
          'issues': latestAnalysis.issues,
          'recommendations': latestAnalysis.recommendations,
          'analyzedAt': latestAnalysis.analyzedAt.toIso8601String(),
        };
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get analysis context: $e');
      return null;
    }
  }

  String _getSystemPrompt(Map<String, dynamic> context) {
    String systemPrompt = '''You are CannaAI Pro, an expert cannabis cultivation assistant.
    Your role is to provide helpful, accurate advice about cannabis growing, plant health,
    and cultivation best practices.

    Guidelines:
    - Always provide practical, actionable advice
    - Consider environmental conditions when making recommendations
    - Suggest specific solutions for identified problems
    - Be encouraging and supportive
    - Never provide illegal or harmful advice
    - If uncertain, recommend consulting with a cultivation expert

    Focus areas:
    - Plant health diagnosis
    - Nutrient recommendations
    - Environmental optimization
    - Pest and disease management
    - Harvest timing and techniques
    - Strain-specific guidance''';

    // Add context-specific information
    if (context['plant'] != null) {
      final plant = context['plant'] as Map<String, dynamic>;
      systemPrompt += '''

    Current Plant Information:
    - Name: ${plant['name']}
    - Growth Stage: ${plant['stage']}
    - Health Status: ${plant['health']}
    - Age: ${plant['age']} days''';
    }

    if (context['room'] != null) {
      final room = context['room'] as Map<String, dynamic>;
      final sensorData = room['currentSensorData'] as Map<String, dynamic>?;

      systemPrompt += '''

    Current Room Environment: ''';

      if (sensorData != null) {
        systemPrompt += '''
    - Temperature: ${sensorData['temperature']}°C
    - Humidity: ${sensorData['humidity']}%
    - pH: ${sensorData['ph']}
    - EC: ${sensorData['ec']} dS/m
    - CO2: ${sensorData['co2']} ppm''';
      }
    }

    return systemPrompt;
  }

  void _addMessageToSession(String sessionId, AIChatMessage message) {
    _sessionMessages[sessionId] ??= [];
    _sessionMessages[sessionId]!.add(message);
  }

  void _emitSessionEvent(String sessionId, AIChatEvent event) {
    final controller = _sessionControllers[sessionId];
    if (controller != null && !controller.isClosed) {
      controller.add(event);
    }
  }

  // ==================== IMAGE ANALYSIS ====================

  Future<AnalysisResult?> analyzeImage(File imageFile, {
    String? plantId,
    AnalysisType type = AnalysisType.health,
    Map<String, dynamic>? sensorContext,
  }) async {
    try {
      // Try primary provider for image analysis
      var result = await _analyzeImageWithProvider(_primaryProvider, imageFile, plantId, type, sensorContext);

      // Fallback to device ML provider
      if (result == null && _primaryProvider != AIProvider.deviceML) {
        result = await _analyzeImageWithProvider(AIProvider.deviceML, imageFile, plantId, type, sensorContext);
      }

      // Final fallback to offline rule provider
      if (result == null) {
        result = await _analyzeImageWithProvider(AIProvider.offline, imageFile, plantId, type, sensorContext);
      }

      return result;
    } catch (e) {
      _logger.e('Failed to analyze image: $e');
      return null;
    }
  }

  Future<AnalysisResult?> _analyzeImageWithProvider(
    AIProvider provider,
    File imageFile,
    String? plantId,
    AnalysisType type,
    Map<String, dynamic>? sensorContext,
  ) async {
    try {
      final aiProvider = _providers[provider];
      if (aiProvider == null || !_isProviderEnabled(provider) || !aiProvider.supportsImageAnalysis) {
        return null;
      }

      final imageAnalysis = await aiProvider.analyzeImage(
        imageFile,
        type: type,
        context: sensorContext ?? {},
      );

      if (imageAnalysis != null) {
        return AnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          plantId: plantId ?? '',
          type: type,
          healthScore: imageAnalysis.confidence,
          issues: imageAnalysis.issues,
          recommendations: imageAnalysis.recommendations,
          confidence: imageAnalysis.confidence,
          details: imageAnalysis.details,
          images: [imageFile.path],
          analyzedAt: DateTime.now(),
          createdAt: DateTime.now(),
          aiProvider: provider.name,
        );
      }

      return null;
    } catch (e) {
      _logger.e('Failed to analyze image with ${provider.name}: $e');
      return null;
    }
  }

  // ==================== QUICK RESPONSES & SUGGESTIONS ====================

  Future<List<String>> getSuggestedQuestions({String? plantId, String? context}) async {
    try {
      final suggestions = <String>[];

      if (plantId != null) {
        // Plant-specific questions
        suggestions.addAll([
          'How is my plant doing overall?',
          'What nutrients does my plant need right now?',
          'Are there any signs of disease or pests?',
          'When should I expect to harvest?',
          'Is the lighting schedule optimal for this stage?',
        ]);
      } else {
        // General cultivation questions
        suggestions.addAll([
          'What are the ideal conditions for vegetative growth?',
          'How do I identify nutrient deficiencies?',
          'What are the signs of overwatering?',
          'How do I optimize my yield?',
          'What are common pest control methods?',
        ]);
      }

      // Context-specific suggestions
      if (context != null) {
        switch (context.toLowerCase()) {
          case 'watering':
            suggestions.addAll([
              'How often should I water my plants?',
              'What are the signs of underwatering?',
              'How much water should I use per watering?',
            ]);
            break;
          case 'lighting':
            suggestions.addAll([
              'What light schedule should I use?',
              'How far should lights be from the canopy?',
              'What light intensity is optimal?',
            ]);
            break;
          case 'nutrients':
            suggestions.addAll([
              'What NPK ratio should I use?',
              'When should I start feeding nutrients?',
              'How do I fix nutrient burn?',
            ]);
            break;
        }
      }

      return suggestions;
    } catch (e) {
      _logger.e('Failed to get suggested questions: $e');
      return [];
    }
  }

  Future<String> getQuickResponse(String query) async {
    try {
      // Use offline provider for quick responses
      final provider = _providers[AIProvider.offline];
      if (provider != null && _isProviderEnabled(AIProvider.offline)) {
        final request = AIProviderRequest(
          message: query,
          systemPrompt: _getSystemPrompt({}),
          temperature: 0.5,
          maxTokens: 200,
        );

        final response = await provider.generateResponse(request);
        if (response != null) {
          return response.content;
        }
      }

      // Fallback responses
      final fallbackResponses = {
        'hello': 'Hello! I\'m CannaAI Pro, your cultivation assistant. How can I help you with your plants today?',
        'help': 'I can help you with plant health analysis, nutrient recommendations, environmental optimization, pest management, and general cultivation advice. What would you like to know?',
        'analyze': 'I can analyze your plant images for health issues, pests, and nutrient deficiencies. Please upload a photo of your plant for analysis.',
        'water': 'For watering, check soil moisture 2-3 inches deep. Water when the top inch feels dry, usually every 2-3 days depending on conditions.',
        'light': 'During vegetative stage, provide 18-20 hours of light. During flowering, switch to 12 hours on, 12 hours off for best results.',
      };

      final lowerQuery = query.toLowerCase();
      for (final key in fallbackResponses.keys) {
        if (lowerQuery.contains(key)) {
          return fallbackResponses[key]!;
        }
      }

      return 'I\'m here to help with your cannabis cultivation. Could you be more specific about what you\'d like to know?';
    } catch (e) {
      _logger.e('Failed to get quick response: $e');
      return 'I apologize, but I\'m having trouble responding right now. Please try again later.';
    }
  }

  // ==================== SETTINGS & CONFIGURATION ====================

  Future<void> updateAISettings(AISettings settings) async {
    try {
      _aiSettings = settings;
      _primaryProvider = settings.primaryProvider;

      // Save to server
      await _apiService.updateAIProviderSettings({
        'primaryProvider': settings.primaryProvider.name,
        'providers': settings.providers.map((key, value) => MapEntry(key.name, value.toJson())),
        'enableLocalAnalysis': settings.enableLocalAnalysis,
        'enableCloudAnalysis': settings.enableCloudAnalysis,
        'preferences': settings.preferences.toJson(),
      });

      // Reconfigure providers
      await _configureProviders();
    } catch (e) {
      _logger.e('Failed to update AI settings: $e');
    }
  }

  Future<bool> testAIProvider(AIProvider provider) async {
    try {
      return await _apiService.testAIConnection(provider.name);
    } catch (e) {
      _logger.e('Failed to test AI provider: $e');
      return false;
    }
  }

  Future<void> configureAIProvider(AIProvider provider, AIProviderConfig config) async {
    try {
      _aiSettings.providers[provider] = config;
      await updateAISettings(_aiSettings);

      final aiProvider = _providers[provider];
      if (aiProvider != null) {
        await aiProvider.configure(config);
      }
    } catch (e) {
      _logger.e('Failed to configure AI provider: $e');
    }
  }

  AISettings get currentSettings => _aiSettings;

  bool _isProviderEnabled(AIProvider provider) {
    final config = _aiSettings.providers[provider];
    return config?.isEnabled ?? true;
  }

  // ==================== PROVIDER INFORMATION ====================

  List<AIProvider> get availableProviders => _providers.keys.toList();

  AIProviderCapabilities getProviderCapabilities(AIProvider provider) {
    final aiProvider = _providers[provider];
    return aiProvider?.capabilities ?? AIProviderCapabilities();
  }

  // ==================== EVENTS & STREAMS ====================

  Stream<AIChatEvent> getChatEvents(String sessionId) {
    _sessionControllers[sessionId] ??= StreamController<AIChatEvent>.broadcast();
    return _sessionControllers[sessionId]!.stream;
  }

  // ==================== CLEANUP ====================

  void dispose() {
    for (final controller in _sessionControllers.values) {
      controller.close();
    }
    _sessionControllers.clear();
    _sessionMessages.clear();

    for (final provider in _providers.values) {
      provider.dispose();
    }
    _providers.clear();
  }
}

// ==================== SUPPORTING CLASSES ====================

class AIChatEvent {
  final String sessionId;
  final AIChatEventType type;
  final String? message;
  final AIChatMessage? chatMessage;
  final AIChatSession? chatSession;
  final DateTime timestamp;

  AIChatEvent({
    required this.sessionId,
    required this.type,
    this.message,
    this.chatMessage,
    this.chatSession,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AIChatEvent.messageSending(String message) {
    return AIChatEvent(
      sessionId: '',
      type: AIChatEventType.messageSending,
      message: message,
    );
  }

  factory AIChatEvent.messageReceived(AIChatMessage message) {
    return AIChatEvent(
      sessionId: '',
      type: AIChatEventType.messageReceived,
      chatMessage: message,
    );
  }

  factory AIChatEvent.sessionCreated(AIChatSession session) {
    return AIChatEvent(
      sessionId: session.id,
      type: AIChatEventType.sessionCreated,
      chatSession: session,
    );
  }

  factory AIChatEvent.error(String message) {
    return AIChatEvent(
      sessionId: '',
      type: AIChatEventType.error,
      message: message,
    );
  }
}

enum AIChatEventType {
  messageSending,
  messageReceived,
  sessionCreated,
  sessionDeleted,
  error,
  typingStarted,
  typingStopped,
}