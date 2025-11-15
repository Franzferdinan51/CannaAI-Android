import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'enhanced_ai_service.dart';
import 'ai_integration_service.dart';
import '../constants/app_constants.dart';

/// Enhanced chat service with AI integration and context awareness
class EnhancedChatService {
  static final EnhancedChatService _instance = EnhancedChatService._internal();
  factory EnhancedChatService() => _instance;
  EnhancedChatService._internal();

  final Logger _logger = Logger();
  final AIIntegrationService _aiIntegration = AIIntegrationService();

  bool _initialized = false;
  final Map<String, ChatSession> _sessions = {};
  final List<ChatTemplate> _quickTemplates = [];

  // Stream controllers for real-time updates
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<ChatSession> _sessionController =
      StreamController<ChatSession>.broadcast();

  /// Initialize the enhanced chat service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _logger.i('Initializing Enhanced Chat Service...');

      // Initialize AI integration
      await _aiIntegration.initialize();

      // Load chat templates
      _loadChatTemplates();

      _initialized = true;
      _logger.i('Enhanced Chat Service initialized');
    } catch (e) {
      _logger.e('Failed to initialize Enhanced Chat Service: $e');
      rethrow;
    }
  }

  /// Send message with enhanced AI capabilities
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? sessionId,
    String? currentStrain,
    Map<String, dynamic>? environmentalContext,
    bool useEnhancedAI = true,
  }) async {
    if (!_initialized) await initialize();

    // Get or create session
    final session = _getOrCreateSession(sessionId ?? 'default');

    try {
      _logger.i('Sending message in session: ${session.id}');

      // Add user message to session
      final userMessage = ChatMessage(
        id: _generateMessageId(),
        sessionId: session.id,
        content: message,
        isUser: true,
        timestamp: DateTime.now(),
      );

      session.messages.add(userMessage);
      session.lastActivity = DateTime.now();
      session.messageCount++;

      // Broadcast user message
      _messageController.add(userMessage);

      Map<String, dynamic> response;

      if (useEnhancedAI) {
        // Use enhanced AI with context awareness
        response = await _sendEnhancedMessage(
          message: message,
          session: session,
          currentStrain: currentStrain,
          environmentalContext: environmentalContext,
        );
      } else {
        // Use basic AI (fallback)
        response = await _sendBasicMessage(
          message: message,
          session: session,
          currentStrain: currentStrain,
          environmentalContext: environmentalContext,
        );
      }

      // Add AI response to session
      final aiMessage = ChatMessage(
        id: _generateMessageId(),
        sessionId: session.id,
        content: response['data']['ai_response'] as String,
        isUser: false,
        timestamp: DateTime.parse(response['data']['timestamp'] as String),
        metadata: {
          'confidence': response['data']['confidence'],
          'source': response['data']['source'],
          'suggested_questions': response['data']['suggested_questions'],
          'enhanced_features': response['enhanced_features'],
        },
      );

      session.messages.add(aiMessage);
      session.lastActivity = DateTime.now();

      // Update session context
      _updateSessionContext(session, message, currentStrain, environmentalContext);

      // Broadcast AI message and updated session
      _messageController.add(aiMessage);
      _sessionController.add(session);

      _logger.i('Message processed successfully for session: ${session.id}');
      return response;
    } catch (e) {
      _logger.e('Failed to send message: $e');

      // Add error message to session
      final errorMessage = ChatMessage(
        id: _generateMessageId(),
        sessionId: session.id,
        content: 'I apologize, but I encountered an error processing your message. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
        metadata: {'error': e.toString()},
      );

      session.messages.add(errorMessage);
      _messageController.add(errorMessage);

      return {
        'success': false,
        'error': e.toString(),
        'data': {
          'ai_response': errorMessage.content,
          'timestamp': errorMessage.timestamp.toIso8601String(),
          'confidence': 0.0,
          'source': 'error',
        },
      };
    }
  }

  /// Get quick response templates
  List<ChatTemplate> getQuickTemplates({String? category}) {
    if (category == null) {
      return List.from(_quickTemplates);
    }

    return _quickTemplates.where((template) => template.category == category).toList();
  }

  /// Get suggested questions based on context
  List<String> getSuggestedQuestions({
    String? sessionId,
    String? currentStrain,
    Map<String, dynamic>? environmentalContext,
  }) {
    final session = sessionId != null ? _sessions[sessionId] : null;
    final suggestions = <String>[];

    // Add strain-specific suggestions
    if (currentStrain != null) {
      suggestions.addAll(_getStrainSpecificSuggestions(currentStrain));
    }

    // Add environmental suggestions
    if (environmentalContext != null) {
      suggestions.addAll(_getEnvironmentalSuggestions(environmentalContext));
    }

    // Add context-based suggestions from session
    if (session != null) {
      suggestions.addAll(_getSessionBasedSuggestions(session));
    }

    // Add general suggestions if none found
    if (suggestions.isEmpty) {
      suggestions.addAll(_getGeneralSuggestions());
    }

    // Limit and randomize
    suggestions.shuffle();
    return suggestions.take(5).toList();
  }

  /// Get chat session
  ChatSession? getSession(String sessionId) {
    return _sessions[sessionId];
  }

  /// Get all sessions
  List<ChatSession> getAllSessions() {
    return _sessions.values.toList()..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  }

  /// Get session messages
  List<ChatMessage> getSessionMessages(String sessionId) {
    return _sessions[sessionId]?.messages ?? [];
  }

  /// Delete session
  Future<bool> deleteSession(String sessionId) async {
    try {
      _sessions.remove(sessionId);
      _logger.i('Deleted chat session: $sessionId');
      return true;
    } catch (e) {
      _logger.e('Failed to delete session: $e');
      return false;
    }
  }

  /// Clear session messages
  Future<bool> clearSession(String sessionId) async {
    try {
      final session = _sessions[sessionId];
      if (session != null) {
        session.messages.clear();
        session.messageCount = 0;
        session.lastActivity = DateTime.now();
        session.context.clear();
        _sessionController.add(session);
        _logger.i('Cleared chat session: $sessionId');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Failed to clear session: $e');
      return false;
    }
  }

  /// Update session context
  void updateSessionContext(String sessionId, Map<String, dynamic> context) {
    final session = _sessions[sessionId];
    if (session != null) {
      session.context.addAll(context);
      session.lastActivity = DateTime.now();
      _sessionController.add(session);
    }
  }

  /// Search messages across all sessions
  List<ChatSearchResult> searchMessages(String query) {
    if (query.isEmpty) return [];

    final results = <ChatSearchResult>[];
    final lowerQuery = query.toLowerCase();

    for (final session in _sessions.values) {
      for (int i = 0; i < session.messages.length; i++) {
        final message = session.messages[i];
        if (message.content.toLowerCase().contains(lowerQuery)) {
          results.add(ChatSearchResult(
            sessionId: session.id,
            messageId: message.id,
            content: message.content,
            timestamp: message.timestamp,
            isUser: message.isUser,
            context: _getMessageContext(message, session.messages, i),
          ));
        }
      }
    }

    // Sort by timestamp (most recent first)
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results.take(50).toList(); // Limit results
  }

  /// Get chat statistics
  Map<String, dynamic> getStatistics() {
    final totalSessions = _sessions.length;
    final totalMessages = _sessions.values.fold(0, (sum, session) => sum + session.messageCount);
    final activeSessions = _sessions.values.where((s) =>
        DateTime.now().difference(s.lastActivity).inHours < 24
    ).length;

    final messageTypes = <String, int>{};
    for (final session in _sessions.values) {
      for (final message in session.messages) {
        final type = message.isUser ? 'user' : 'ai';
        messageTypes[type] = (messageTypes[type] ?? 0) + 1;
      }
    }

    return {
      'total_sessions': totalSessions,
      'total_messages': totalMessages,
      'active_sessions_24h': activeSessions,
      'message_types': messageTypes,
      'average_messages_per_session': totalSessions > 0 ? totalMessages / totalSessions : 0.0,
      'ai_integration_enabled': _aiIntegration.getAIStatus()['initialized'] ?? false,
      'current_ai_provider': _aiIntegration.getAIStatus()['current_provider'],
    };
  }

  // Private helper methods

  Future<Map<String, dynamic>> _sendEnhancedMessage({
    required String message,
    required ChatSession session,
    String? currentStrain,
    Map<String, dynamic>? environmentalContext,
  }) async {
    return await _aiIntegration.sendEnhancedChatMessage(
      message: message,
      sessionId: session.id,
      currentStrain: currentStrain,
      environmentalContext: environmentalContext,
      conversationHistory: session.messages.map((msg) => {
        'message': msg.content,
        'isUser': msg.isUser,
        'timestamp': msg.timestamp.toIso8601String(),
      }).toList(),
    );
  }

  Future<Map<String, dynamic>> _sendBasicMessage({
    required String message,
    required ChatSession session,
    String? currentStrain,
    Map<String, dynamic>? environmentalContext,
  }) async {
    // This would use the existing API service chat functionality
    // For now, return a simple response
    return {
      'success': true,
      'data': {
        'ai_response': _generateBasicResponse(message, currentStrain),
        'timestamp': DateTime.now().toIso8601String(),
        'confidence': 0.6,
        'source': 'basic_ai',
        'suggested_questions': _getBasicSuggestions(message),
      },
      'enhanced_features': {
        'context_aware': false,
        'personalized': false,
        'suggestions_available': true,
      },
    };
  }

  ChatSession _getOrCreateSession(String sessionId) {
    return _sessions.putIfAbsent(sessionId, () => ChatSession(
      id: sessionId,
      createdAt: DateTime.now(),
      lastActivity: DateTime.now(),
      messages: [],
      messageCount: 0,
      context: {},
    ));
  }

  void _updateSessionContext(
    ChatSession session,
    String message,
    String? currentStrain,
    Map<String, dynamic>? environmentalContext,
  ) {
    // Update current strain
    if (currentStrain != null) {
      session.context['current_strain'] = currentStrain;
    }

    // Update environmental context
    if (environmentalContext != null) {
      session.context['last_environmental_data'] = environmentalContext;
    }

    // Analyze message for learning
    _analyzeMessageForLearning(session, message);
  }

  void _analyzeMessageForLearning(ChatSession session, String message) {
    final lowerMessage = message.toLowerCase();

    // Track interests
    if (lowerMessage.contains('nutrient') || lowerMessage.contains('feeding')) {
      session.interests.add('nutrients');
    } else if (lowerMessage.contains('water') || lowerMessage.contains('watering')) {
      session.interests.add('watering');
    } else if (lowerMessage.contains('light') || lowerMessage.contains('lamp')) {
      session.interests.add('lighting');
    } else if (lowerMessage.contains('harvest') || lowerMessage.contains('ready')) {
      session.interests.add('harvesting');
    }

    // Track question types
    if (lowerMessage.contains('how to') || lowerMessage.contains('what is')) {
      session.questionTypes.add('educational');
    } else if (lowerMessage.contains('problem') || lowerMessage.contains('issue')) {
      session.questionTypes.add('troubleshooting');
    }
  }

  List<String> _getStrainSpecificSuggestions(String strain) {
    final suggestions = <String>[];

    if (strain.toLowerCase().contains('purple')) {
      suggestions.addAll([
        'How can I enhance purple coloration?',
        'Is the purple color normal or a deficiency?',
        'What are the ideal conditions for purple strains?',
      ]);
    }

    if (strain.toLowerCase().contains('haze')) {
      suggestions.addAll([
        'How long should I flower haze strains?',
        'What are the specific needs of haze varieties?',
        'When is the best time to harvest haze strains?',
      ]);
    }

    if (strain.toLowerCase().contains('kush')) {
      suggestions.addAll([
        'What are the ideal conditions for Kush strains?',
        'How do I prevent common Kush issues?',
        'What nutrients work best for Kush varieties?',
      ]);
    }

    return suggestions;
  }

  List<String> _getEnvironmentalSuggestions(Map<String, dynamic> context) {
    final suggestions = <String>[];

    if (context.containsKey('temperature')) {
      final temp = context['temperature'] as double? ?? 0.0;
      if (temp < 20.0) {
        suggestions.add('How can I help my plants with low temperatures?');
      } else if (temp > 28.0) {
        suggestions.add('What should I do about high temperatures?');
      }
    }

    if (context.containsKey('humidity')) {
      final humidity = context['humidity'] as double? ?? 0.0;
      if (humidity > 70.0) {
        suggestions.add('What should I do about high humidity?');
      } else if (humidity < 40.0) {
        suggestions.add('How can I increase humidity for my plants?');
      }
    }

    return suggestions;
  }

  List<String> _getSessionBasedSuggestions(ChatSession session) {
    final suggestions = <String>[];

    // Based on interests
    for (final interest in session.interests) {
      switch (interest) {
        case 'nutrients':
          suggestions.addAll([
            'What are the signs of nutrient deficiencies?',
            'How do I fix nutrient burn?',
            'When should I adjust nutrient levels?',
          ]);
          break;
        case 'watering':
          suggestions.addAll([
            'How often should I water my plants?',
            'What are the signs of overwatering?',
            'How does humidity affect watering needs?',
          ]);
          break;
        case 'lighting':
          suggestions.addAll([
            'What\'s the best light schedule for my stage?',
            'How far should lights be from plants?',
            'How much light do cannabis plants need?',
          ]);
          break;
        case 'harvesting':
          suggestions.addAll([
            'How do I know when to harvest?',
            'What should I look for in trichomes?',
            'How do I properly flush before harvest?',
          ]);
          break;
      }
    }

    return suggestions;
  }

  List<String> _getGeneralSuggestions() {
    return [
      'How do I maintain plant health?',
      'What are common cannabis problems?',
      'How can I improve my grow setup?',
      'What should I monitor daily?',
      'How do I prevent pests and diseases?',
    ];
  }

  String _generateBasicResponse(String message, String? currentStrain) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
      return 'Hello! I\'m here to help you with your cannabis cultivation questions. What can I assist you with today?';
    }

    if (lowerMessage.contains('water')) {
      return 'For proper watering, check if the top 1-2 inches of soil are dry before watering. Ensure good drainage and adjust frequency based on temperature and humidity levels.';
    }

    if (lowerMessage.contains('nutrient')) {
      return 'Nutrient management is crucial for healthy growth. Start with 50% strength nutrients and gradually increase as your plants show demand. Always maintain pH between 6.0-6.5 for optimal uptake.';
    }

    if (lowerMessage.contains('light')) {
      return 'Lighting requirements vary by growth stage. Provide 18-24 hours of light during vegetative growth and 12 hours during flowering. Maintain appropriate distance to prevent light burn.';
    }

    if (lowerMessage.contains('harvest')) {
      return 'Harvest timing is critical for quality. Look for trichomes turning from clear to cloudy/amber, pistils darkening, and leaves yellowing. Use magnification to check trichome color.';
    }

    return 'I\'m here to help with cannabis cultivation. Could you be more specific about what you\'d like to know? I can assist with nutrients, lighting, watering, pest control, harvesting, and more.';
  }

  List<String> _getBasicSuggestions(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('water')) {
      return [
        'How often should I water my plants?',
        'What are the signs of overwatering?',
        'How does temperature affect watering?',
      ];
    }

    if (lowerMessage.contains('nutrient')) {
      return [
        'What nutrients do I need for vegetative stage?',
        'How do I fix nutrient burn?',
        'What are signs of nutrient deficiencies?',
      ];
    }

    return [
      'How do I maintain plant health?',
      'What are common growing problems?',
      'How can I improve my setup?',
    ];
  }

  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  String _getMessageContext(ChatMessage message, List<ChatMessage> messages, int index) {
    final start = (index - 2).clamp(0, messages.length);
    final end = (index + 2).clamp(0, messages.length);
    final contextMessages = messages.sublist(start, end);

    return contextMessages.map((msg) => msg.content).join(' ');
  }

  void _loadChatTemplates() {
    _quickTemplates.addAll([
      ChatTemplate(
        id: 'watering_help',
        title: 'Watering Issues',
        category: 'watering',
        message: 'My plant has watering issues. What should I do?',
        icon: '💧',
      ),
      ChatTemplate(
        id: 'nutrient_help',
        title: 'Nutrient Problems',
        category: 'nutrients',
        message: 'I think my plant has nutrient deficiencies. Can you help?',
        icon: '🌱',
      ),
      ChatTemplate(
        id: 'lighting_help',
        title: 'Lighting Setup',
        category: 'lighting',
        message: 'I need help with my lighting setup.',
        icon: '💡',
      ),
      ChatTemplate(
        id: 'pest_help',
        title: 'Pest Issues',
        category: 'pests',
        message: 'I found pests on my plants. What should I do?',
        icon: '🐛',
      ),
      ChatTemplate(
        id: 'harvest_help',
        title: 'Harvesting Questions',
        category: 'harvesting',
        message: 'When should I harvest my plants?',
        icon: '✂️',
      ),
    ]);
  }

  /// Get streams
  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<ChatSession> get sessionStream => _sessionController.stream;

  /// Dispose service
  Future<void> dispose() async {
    _messageController.close();
    _sessionController.close();
    await _aiIntegration.dispose();
    _initialized = false;
    _logger.i('Enhanced Chat Service disposed');
  }
}

// Supporting classes

class ChatSession {
  final String id;
  final DateTime createdAt;
  DateTime lastActivity;
  List<ChatMessage> messages;
  int messageCount;
  Map<String, dynamic> context;
  Set<String> interests;
  Set<String> questionTypes;

  ChatSession({
    required this.id,
    required this.createdAt,
    required this.lastActivity,
    this.messages = const [],
    this.messageCount = 0,
    this.context = const {},
    this.interests = const {},
    this.questionTypes = const {},
  });
}

class ChatMessage {
  final String id;
  final String sessionId;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.metadata,
  });
}

class ChatTemplate {
  final String id;
  final String title;
  final String category;
  final String message;
  final String icon;

  ChatTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.message,
    required this.icon,
  });
}

class ChatSearchResult {
  final String sessionId;
  final String messageId;
  final String content;
  final DateTime timestamp;
  final bool isUser;
  final String context;

  ChatSearchResult({
    required this.sessionId,
    required this.messageId,
    required this.content,
    required this.timestamp,
    required this.isUser,
    required this.context,
  });
}