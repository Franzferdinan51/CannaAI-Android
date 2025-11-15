import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:logger/logger.dart';
import 'base_ai_provider.dart';
import '../enhanced_ai_service.dart';
import '../local_ai_service.dart';

/// Chat provider for AI cultivation assistant with context awareness
class ChatProvider {
  final Logger _logger = Logger();
  final LocalAIService _localAI = LocalAIService();

  // Context management
  final Map<String, ChatContext> _sessions = {};
  final List<ChatTemplate> _templates = [];
  final Map<String, List<String>> _quickSuggestions = {};

  // Provider delegation
  OnlineAIProvider? _currentOnlineProvider;

  ChatProvider() {
    _initializeTemplates();
    _initializeQuickSuggestions();
  }

  /// Set the current online provider for chat
  void setCurrentProvider(OnlineAIProvider provider) {
    _currentOnlineProvider = provider;
    _logger.d('Chat provider set to: ${provider.getProviderName()}');
  }

  /// Generate AI chat response with context awareness
  Future<ChatResponse> generateResponse({
    required String message,
    required String sessionId,
    String? currentStrain,
    Map<String, dynamic>? environmentalContext,
    required List<ChatMessage> conversationHistory,
    required AIProviderType currentProvider,
  }) async {
    try {
      _logger.i('Generating chat response for session: $sessionId');

      // Get or create session context
      final context = _getOrCreateContext(sessionId);

      // Update context with new information
      await _updateContext(
        context,
        message,
        currentStrain,
        environmentalContext,
        conversationHistory,
      );

      // Generate response based on provider type
      ChatResponse response;
      if (currentProvider == AIProviderType.offlineRules || _currentOnlineProvider == null) {
        response = await _generateOfflineResponse(context, message);
      } else {
        response = await _generateOnlineResponse(context, message);
      }

      // Update conversation history
      _addToHistory(context, ChatMessage(
        message: message,
        isUser: true,
        timestamp: DateTime.now(),
        sessionId: sessionId,
      ));
      _addToHistory(context, ChatMessage(
        message: response.message,
        isUser: false,
        timestamp: DateTime.now(),
        sessionId: sessionId,
        metadata: response.metadata,
      ));

      // Generate suggested questions
      final suggestedQuestions = _generateSuggestedQuestions(context, response);

      return ChatResponse(
        message: response.message,
        sessionId: sessionId,
        timestamp: response.timestamp,
        confidence: response.confidence,
        source: response.source,
        suggestedQuestions: suggestedQuestions,
        metadata: {
          ...?response.metadata,
          'context_updated': true,
          'session_age': DateTime.now().difference(context.createdAt).inMinutes,
        },
      );
    } catch (e) {
      _logger.e('Chat response generation failed: $e');
      return _getFallbackResponse(sessionId, message);
    }
  }

  /// Get or create chat session context
  ChatContext _getOrCreateContext(String sessionId) {
    return _sessions.putIfAbsent(sessionId, () => ChatContext(
      id: sessionId,
      createdAt: DateTime.now(),
      lastActivity: DateTime.now(),
      conversationHistory: [],
      userPreferences: {},
      learnedPatterns: {},
    ));
  }

  /// Update context with new information
  Future<void> _updateContext(
    ChatContext context,
    String message,
    String? currentStrain,
    Map<String, dynamic>? environmentalContext,
    List<ChatMessage> conversationHistory,
  ) async {
    // Update activity
    context.lastActivity = DateTime.now();

    // Update current strain if provided
    if (currentStrain != null) {
      context.currentStrain = currentStrain;
    }

    // Update environmental context
    if (environmentalContext != null) {
      context.lastKnownEnvironment = Map.from(environmentalContext);
    }

    // Analyze message for patterns and preferences
    await _analyzeMessagePatterns(context, message);

    // Update conversation history
    if (conversationHistory.isNotEmpty) {
      context.conversationHistory = List.from(conversationHistory.takeLast(20)); // Keep last 20 messages
    }
  }

  /// Analyze message for learning patterns
  Future<void> _analyzeMessagePatterns(ChatContext context, String message) async {
    final lowerMessage = message.toLowerCase();

    // Identify user interests
    if (lowerMessage.contains('nutrient') || lowerMessage.contains('feeding')) {
      context.interests.add('nutrients');
    } else if (lowerMessage.contains('light') || lowerMessage.contains('lamp')) {
      context.interests.add('lighting');
    } else if (lowerMessage.contains('water') || lowerMessage.contains('watering')) {
      context.interests.add('watering');
    } else if (lowerMessage.contains('harvest') || lowerMessage.contains('ready')) {
      context.interests.add('harvesting');
    } else if (lowerMessage.contains('pest') || lowerMessage.contains('bug')) {
      context.interests.add('pests');
    } else if (lowerMessage.contains('disease') || lowerMessage.contains('mold')) {
      context.interests.add('diseases');
    }

    // Identify expertise level
    if (lowerMessage.contains('beginner') || lowerMessage.contains('new') || lowerMessage.contains('help')) {
      context.expertiseLevel = ExpertiseLevel.beginner;
    } else if (lowerMessage.contains('advanced') || lowerMessage.contains('expert') || lowerMessage.contains('experienced')) {
      context.expertiseLevel = ExpertiseLevel.advanced;
    }

    // Track question patterns
    if (lowerMessage.contains('how to') || lowerMessage.contains('what is') || lowerMessage.contains('why')) {
      context.questionTypes.add('educational');
    } else if (lowerMessage.contains('problem') || lowerMessage.contains('issue') || lowerMessage.contains('help')) {
      context.questionTypes.add('troubleshooting');
    } else if (lowerMessage.contains('when') || lowerMessage.contains('time') || lowerMessage.contains('schedule')) {
      context.questionTypes.add('timing');
    }
  }

  /// Generate response using offline/local AI
  Future<ChatResponse> _generateOfflineResponse(ChatContext context, String message) async {
    try {
      // Create context-aware prompt for local AI
      final contextualPrompt = _buildContextualPrompt(context, message);

      // Generate response using local AI service
      final aiResponse = await _localAI.generateCultivationAdvice(
        userMessage: contextualPrompt,
        currentStrain: context.currentStrain,
        environmentalContext: context.lastKnownEnvironment,
      );

      // Personalize response based on context
      final personalizedResponse = _personalizeResponse(context, aiResponse);

      return ChatResponse(
        message: personalizedResponse,
        sessionId: context.id,
        timestamp: DateTime.now(),
        confidence: 0.7, // Lower confidence for offline responses
        source: 'offline_ai',
        metadata: {
          'expertise_level': context.expertiseLevel.toString(),
          'interests': context.interests.toList(),
          'response_type': 'contextual_offline',
        },
      );
    } catch (e) {
      _logger.e('Offline response generation failed: $e');
      return _getTemplateResponse(context, message);
    }
  }

  /// Generate response using online AI provider
  Future<ChatResponse> _generateOnlineResponse(ChatContext context, String message) async {
    if (_currentOnlineProvider == null) {
      return _generateOfflineResponse(context, message);
    }

    try {
      // Build comprehensive prompt with context
      final prompt = _buildComprehensivePrompt(context, message);

      // Prepare request for online provider
      final requestData = {
        'model': _getCurrentModel(),
        'messages': [
          {
            'role': 'system',
            'content': _getSystemPrompt(context),
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'max_tokens': 1000,
        'temperature': _getTemperatureForExpertise(context.expertiseLevel),
      };

      // Make request (simplified - would use actual provider method)
      final response = await _makeOnlineRequest(requestData);

      final content = response['choices']?[0]?['message']?['content'] as String?;
      if (content == null) {
        throw Exception('No content in online response');
      }

      return ChatResponse(
        message: content,
        sessionId: context.id,
        timestamp: DateTime.now(),
        confidence: 0.9, // Higher confidence for online responses
        source: _currentOnlineProvider!.getProviderName(),
        metadata: {
          'expertise_level': context.expertiseLevel.toString(),
          'interests': context.interests.toList(),
          'response_type': 'contextual_online',
          'model_used': _getCurrentModel(),
        },
      );
    } catch (e) {
      _logger.e('Online response generation failed: $e');
      // Fallback to offline response
      return _generateOfflineResponse(context, message);
    }
  }

  /// Build contextual prompt for AI
  String _buildContextualPrompt(ChatContext context, String message) {
    final buffer = StringBuffer();

    // Add context about user
    if (context.expertiseLevel != ExpertiseLevel.intermediate) {
      buffer.writeln('User expertise level: ${context.expertiseLevel.name}');
      buffer.writeln('Please adjust your response accordingly.\n');
    }

    // Add strain information
    if (context.currentStrain != null) {
      buffer.writeln('Current strain: ${context.currentStrain}');
    }

    // Add environmental context
    if (context.lastKnownEnvironment != null) {
      buffer.writeln('Current environmental conditions:');
      context.lastKnownEnvironment!.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
      buffer.writeln();
    }

    // Add conversation context
    if (context.conversationHistory.isNotEmpty) {
      final recentMessages = context.conversationHistory.takeLast(3);
      if (recentMessages.isNotEmpty) {
        buffer.writeln('Recent conversation context:');
        for (final msg in recentMessages) {
          final prefix = msg.isUser ? 'User' : 'Assistant';
          buffer.writeln('  $prefix: ${msg.message}');
        }
        buffer.writeln();
      }
    }

    // Add the current message
    buffer.writeln('Current question: $message');

    return buffer.toString();
  }

  /// Build comprehensive prompt for online AI
  String _buildComprehensivePrompt(ChatContext context, String message) {
    final buffer = StringBuffer();

    buffer.writeln('You are an expert cannabis cultivation assistant providing personalized advice.');
    buffer.writeln();

    // User context
    buffer.writeln('**User Context:**');
    buffer.writeln('- Expertise level: ${context.expertiseLevel.name}');
    buffer.writeln('- Current strain: ${context.currentStrain ?? "Unknown"}');
    buffer.writeln('- Interests: ${context.interests.join(", ")}');
    buffer.writeln('- Session age: ${DateTime.now().difference(context.createdAt).inMinutes} minutes');

    // Environmental context
    if (context.lastKnownEnvironment != null) {
      buffer.writeln('\n**Environmental Conditions:**');
      context.lastKnownEnvironment!.forEach((key, value) {
        buffer.writeln('- $key: $value');
      });
    }

    // Conversation history
    if (context.conversationHistory.isNotEmpty) {
      buffer.writeln('\n**Recent Conversation:**');
      final recentMessages = context.conversationHistory.takeLast(5);
      for (final msg in recentMessages) {
        final role = msg.isUser ? 'User' : 'Assistant';
        buffer.writeln('$role: ${msg.message}');
      }
    }

    // Current question
    buffer.writeln('\n**Current Question:**');
    buffer.writeln(message);

    // Response guidelines
    buffer.writeln('\n**Response Guidelines:**');
    buffer.writeln('- Provide advice appropriate for ${context.expertiseLevel.name} level');
    buffer.writeln('- Be concise but thorough');
    buffer.writeln('- Include actionable steps when relevant');
    buffer.writeln('- Consider current environmental conditions');
    buffer.writeln('- Reference current strain characteristics if applicable');

    return buffer.toString();
  }

  /// Get system prompt based on context
  String _getSystemPrompt(ChatContext context) {
    final basePrompt = '''
You are an expert cannabis cultivation assistant with deep knowledge of:
- Plant health and nutrient management
- Pest and disease identification and treatment
- Environmental control and optimization
- Strain-specific cultivation requirements
- Harvesting and curing techniques

Your role is to provide accurate, practical advice tailored to the user's expertise level and current situation.
Always prioritize plant health and safe cultivation practices.
If you're uncertain about something, acknowledge it and suggest consulting additional resources.
''';

    // Add expertise-specific guidance
    switch (context.expertiseLevel) {
      case ExpertiseLevel.beginner:
        return basePrompt + '''

For beginners, always:
- Explain concepts clearly and simply
- Provide step-by-step instructions
- Include warnings about common mistakes
- Suggest starting with conservative approaches
- Recommend learning resources when helpful
''';
      case ExpertiseLevel.advanced:
        return basePrompt + '''

For advanced users, you can:
- Use technical terminology when appropriate
- Discuss advanced cultivation techniques
- Provide nuanced recommendations
- Assume familiarity with basic concepts
- Suggest optimization strategies
''';
      case ExpertiseLevel.intermediate:
      default:
        return basePrompt + '''

For intermediate users:
- Balance detailed explanations with practical advice
- Introduce some advanced concepts with explanation
- Provide context for recommendations
- Include troubleshooting tips
''';
    }
  }

  /// Personalize response based on context
  String _personalizeResponse(ChatContext context, String response) {
    // Add personalized greeting based on session age
    final sessionAge = DateTime.now().difference(context.createdAt).inMinutes;
    String personalizedResponse = response;

    if (sessionAge < 5) {
      personalizedResponse = "Hi! I'm here to help with your cannabis cultivation questions. $response";
    } else if (context.interests.isNotEmpty) {
      // Reference user interests when relevant
      final primaryInterest = context.interests.first;
      personalizedResponse = "$response\n\nSince you're interested in $primaryInterest, feel free to ask me more specific questions about that topic.";
    }

    return personalizedResponse;
  }

  /// Get temperature setting for AI based on expertise level
  double _getTemperatureForExpertise(ExpertiseLevel level) {
    switch (level) {
      case ExpertiseLevel.beginner:
        return 0.3; // More consistent, conservative responses
      case ExpertiseLevel.advanced:
        return 0.8; // More creative, detailed responses
      case ExpertiseLevel.intermediate:
      default:
        return 0.5; // Balanced responses
    }
  }

  /// Generate suggested questions based on context
  List<String> _generateSuggestedQuestions(ChatContext context, ChatResponse response) {
    final suggestions = <String>[];

    // Base suggestions on user interests
    for (final interest in context.interests) {
      suggestions.addAll(_quickSuggestions[interest] ?? []);
    }

    // Add suggestions based on environmental context
    if (context.lastKnownEnvironment != null) {
      final env = context.lastKnownEnvironment!;

      if ((env['temperature'] as num?)?.toDouble() > 28.0) {
        suggestions.add('How can I help my plants with high temperatures?');
      }
      if ((env['humidity'] as num?)?.toDouble() > 70.0) {
        suggestions.add('What should I do about high humidity?');
      }
      if ((env['ph'] as num?)?.toDouble() != null &&
          ((env['ph'] as num?)?.toDouble()! < 6.0 || (env['ph'] as num?)?.toDouble()! > 7.0)) {
        suggestions.add('How do I adjust pH levels properly?');
      }
    }

    // Add strain-specific suggestions
    if (context.currentStrain != null) {
      final strain = context.currentStrain!.toLowerCase();
      if (strain.contains('purple')) {
        suggestions.add('How can I enhance purple coloration?');
        suggestions.add('Is the purple color normal or a deficiency?');
      }
      if (strain.contains('haze')) {
        suggestions.add('How long should I flower haze strains?');
      }
      if (strain.contains('kush')) {
        suggestions.add('What are the ideal conditions for Kush strains?');
      }
    }

    // Add suggestions based on conversation flow
    if (context.questionTypes.contains('troubleshooting')) {
      suggestions.add('What are the most common problems at this stage?');
      suggestions.add('How can I prevent future issues?');
    }

    // Limit and randomize suggestions
    suggestions.shuffle();
    return suggestions.take(4).toList();
  }

  /// Get fallback response when all else fails
  ChatResponse _getFallbackResponse(String sessionId, String message) {
    return ChatResponse(
      message: "I'm having trouble processing your request right now. Let me help you with some general cannabis cultivation advice instead. What specific aspect of growing would you like to know about? I can help with nutrients, lighting, watering, pest control, or harvesting.",
      sessionId: sessionId,
      timestamp: DateTime.now(),
      confidence: 0.3,
      source: 'fallback',
      suggestedQuestions: [
        'How often should I water my plants?',
        'What nutrients do cannabis plants need?',
        'How do I know when to harvest?',
        'What are common cannabis pests?',
      ],
    );
  }

  /// Get template response based on message type
  ChatResponse _getTemplateResponse(ChatContext context, String message) {
    final lowerMessage = message.toLowerCase();

    // Find matching template
    for (final template in _templates) {
      if (template.keywords.any((keyword) => lowerMessage.contains(keyword))) {
        return ChatResponse(
          message: template.response,
          sessionId: context.id,
          timestamp: DateTime.now(),
          confidence: 0.6,
          source: 'template',
          suggestedQuestions: template.followUpQuestions,
          metadata: {'template_id': template.id},
        );
      }
    }

    return _getFallbackResponse(context.id, message);
  }

  /// Make online request (simplified implementation)
  Future<Map<String, dynamic>> _makeOnlineRequest(Map<String, dynamic> requestData) async {
    // This would be implemented based on the specific online provider
    // For now, return a mock response
    await Future.delayed(Duration(seconds: 1));

    return {
      'choices': [
        {
          'message': {
            'content': _generateMockResponse(requestData),
          },
        },
      ],
    };
  }

  /// Generate mock response for testing
  String _generateMockResponse(Map<String, dynamic> requestData) {
    final messages = requestData['messages'] as List;
    final userMessage = messages.last['content'] as String;

    if (userMessage.toLowerCase().contains('water')) {
      return "Based on your current setup, I recommend watering when the top 1-2 inches of soil feel dry. Check soil moisture daily and adjust frequency based on environmental conditions. Higher temperatures and lower humidity will require more frequent watering.";
    } else if (userMessage.toLowerCase().contains('nutrient')) {
      return "For optimal growth, maintain a balanced nutrient regimen with higher nitrogen during vegetative stage and increased phosphorus and potassium during flowering. Always start with 50% of the recommended strength and gradually increase as your plants show demand.";
    } else {
      return "I'm here to help with your cannabis cultivation. Based on your current setup and experience level, I can provide personalized advice on nutrients, lighting, watering, pest control, and harvesting. What specific aspect would you like to focus on?";
    }
  }

  /// Get current model from online provider
  String _getCurrentModel() {
    return 'gpt-4'; // Placeholder - would get from actual provider
  }

  /// Add message to conversation history
  void _addToHistory(ChatContext context, ChatMessage message) {
    context.conversationHistory.add(message);

    // Keep only last 50 messages
    if (context.conversationHistory.length > 50) {
      context.conversationHistory = context.conversationHistory.sublist(
        context.conversationHistory.length - 50,
      );
    }
  }

  /// Initialize chat templates
  void _initializeTemplates() {
    _templates.addAll([
      ChatTemplate(
        id: 'watering_help',
        keywords: ['water', 'watering', 'moisture', 'dry', 'wet'],
        response: 'Proper watering is crucial for cannabis cultivation. Water when the top 1-2 inches of soil feel dry, ensure good drainage, and adjust frequency based on environmental conditions. Always check soil moisture before watering to avoid overwatering.',
        followUpQuestions: [
          'How often should I water my plants?',
          'What are the signs of overwatering?',
          'How does humidity affect watering needs?',
        ],
      ),
      ChatTemplate(
        id: 'nutrient_help',
        keywords: ['nutrient', 'feeding', 'fertilizer', 'feed'],
        response: 'Nutrient management is key to healthy cannabis growth. Start with 50% strength nutrients, monitor plant response, and gradually increase. Maintain pH between 6.0-6.5 for optimal nutrient uptake. Different growth stages require different nutrient ratios.',
        followUpQuestions: [
          'What nutrients do I need for vegetative stage?',
          'How do I fix nutrient burn?',
          'What are the signs of nutrient deficiencies?',
        ],
      ),
      ChatTemplate(
        id: 'lighting_help',
        keywords: ['light', 'lamp', 'led', 'mh', 'hps'],
        response: 'Lighting is one of the most important factors. Provide 18-24 hours of light during vegetative stage and 12 hours during flowering. Maintain appropriate distance from canopy to prevent light burn while ensuring adequate coverage.',
        followUpQuestions: [
          'What\'s the best light schedule for vegetative stage?',
          'How far should LEDs be from plants?',
          'How much light do cannabis plants need?',
        ],
      ),
      ChatTemplate(
        id: 'harvest_help',
        keywords: ['harvest', 'ready', 'flowering', 'trichomes'],
        response: 'Harvest timing is crucial for quality. Look for trichomes turning from clear to cloudy/amber, pistils darkening and curling, and leaves yellowing. Use a magnifier to check trichome color - this is the most reliable indicator.',
        followUpQuestions: [
          'How do I know when to harvest?',
          'What do cloudy trichomes mean?',
          'Should I flush before harvesting?',
        ],
      ),
    ]);
  }

  /// Initialize quick suggestions
  void _initializeQuickSuggestions() {
    _quickSuggestions.addAll({
      'nutrients': [
        'What are the signs of nitrogen deficiency?',
        'How do I fix nutrient burn?',
        'When should I start flowering nutrients?',
        'What\'s the best pH for cannabis?',
      ],
      'watering': [
        'How often should I water my plants?',
        'What are the signs of overwatering?',
        'How much water should I use?',
        'Should I water before or after lights on?',
      ],
      'lighting': [
        'What\'s the best light schedule?',
        'How far should LEDs be from plants?',
        'What color spectrum is best?',
        'How much light do cannabis plants need?',
      ],
      'pests': [
        'How do I get rid of spider mites?',
        'What are the signs of pests?',
        'How can I prevent pests naturally?',
        'What pesticides are safe for cannabis?',
      ],
      'diseases': [
        'How do I treat powdery mildew?',
        'What causes root rot?',
        'How can I prevent mold?',
        'What are signs of nutrient deficiencies?',
      ],
      'harvesting': [
        'How do I know when to harvest?',
        'What do cloudy trichomes mean?',
        'Should I flush before harvesting?',
        'How do I properly dry cannabis?',
      ],
    });
  }

  /// Clean up old sessions
  void cleanupOldSessions({Duration maxAge = const Duration(days: 7)}) {
    final cutoffTime = DateTime.now().subtract(maxAge);
    final expiredSessions = <String>[];

    _sessions.forEach((sessionId, context) {
      if (context.lastActivity.isBefore(cutoffTime)) {
        expiredSessions.add(sessionId);
      }
    });

    for (final sessionId in expiredSessions) {
      _sessions.remove(sessionId);
    }

    if (expiredSessions.isNotEmpty) {
      _logger.i('Cleaned up ${expiredSessions.length} expired chat sessions');
    }
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStats() {
    final totalSessions = _sessions.length;
    final activeSessions = _sessions.values.where((c) =>
        DateTime.now().difference(c.lastActivity).inMinutes < 60
    ).length;

    return {
      'total_sessions': totalSessions,
      'active_sessions': activeSessions,
      'average_session_length': totalSessions > 0 ?
          _sessions.values.map((c) => DateTime.now().difference(c.createdAt).inMinutes).reduce((a, b) => a + b) / totalSessions : 0,
      'common_interests': _getAllInterests(),
    };
  }

  List<String> _getAllInterests() {
    final allInterests = <String>{};
    for (final context in _sessions.values) {
      allInterests.addAll(context.interests);
    }
    return allInterests.toList()..sort();
  }

  /// Clear all session data
  void clearAllSessions() {
    _sessions.clear();
    _logger.i('All chat sessions cleared');
  }
}

// Supporting classes

class ChatContext {
  final String id;
  final DateTime createdAt;
  DateTime lastActivity;
  List<ChatMessage> conversationHistory;
  String? currentStrain;
  Map<String, dynamic>? lastKnownEnvironment;
  Set<String> interests;
  Set<String> questionTypes;
  ExpertiseLevel expertiseLevel;
  Map<String, dynamic> userPreferences;
  Map<String, dynamic> learnedPatterns;

  ChatContext({
    required this.id,
    required this.createdAt,
    required this.lastActivity,
    this.conversationHistory = const [],
    this.currentStrain,
    this.lastKnownEnvironment,
    this.interests = const {},
    this.questionTypes = const {},
    this.expertiseLevel = ExpertiseLevel.intermediate,
    this.userPreferences = const {},
    this.learnedPatterns = const {},
  });
}

class ChatTemplate {
  final String id;
  final List<String> keywords;
  final String response;
  final List<String> followUpQuestions;

  ChatTemplate({
    required this.id,
    required this.keywords,
    required this.response,
    required this.followUpQuestions,
  });
}

enum ExpertiseLevel {
  beginner,
  intermediate,
  advanced,
}