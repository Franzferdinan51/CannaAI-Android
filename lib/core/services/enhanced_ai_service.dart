import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'ai_providers/base_ai_provider.dart';
import 'ai_providers/lm_studio_provider.dart';
import 'ai_providers/openrouter_provider.dart';
import 'ai_providers/device_ml_provider.dart';
import 'ai_providers/offline_rule_provider.dart';
import 'ai_providers/chat_provider.dart';
import 'image_processing_service.dart';
import 'ai_cache_service.dart';

/// Comprehensive AI service that manages multiple AI providers
/// Supports online, offline, and hybrid analysis modes
class EnhancedAIService {
  static final EnhancedAIService _instance = EnhancedAIService._internal();
  factory EnhancedAIService() => _instance;
  EnhancedAIService._internal();

  final Logger _logger = Logger();
  final ImageProcessingService _imageProcessor = ImageProcessingService();
  final AICacheService _cache = AICacheService();

  // AI Providers
  late final LMStudioProvider _lmStudioProvider;
  late final OpenRouterProvider _openRouterProvider;
  late final DeviceMLProvider _deviceMLProvider;
  late final OfflineRuleProvider _offlineRuleProvider;
  late final ChatProvider _chatProvider;

  // Provider priority and fallback
  final List<AIProviderType> _providerPriority = [
    AIProviderType.lmStudio,
    AIProviderType.openRouter,
    AIProviderType.deviceML,
    AIProviderType.offlineRules,
  ];

  bool _initialized = false;
  AIProviderType? _currentProvider;
  Map<String, bool> _providerAvailability = {};

  /// Initialize all AI providers and test connectivity
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _logger.i('Initializing Enhanced AI Service...');

      // Initialize providers
      _lmStudioProvider = LMStudioProvider();
      _openRouterProvider = OpenRouterProvider();
      _deviceMLProvider = DeviceMLProvider();
      _offlineRuleProvider = OfflineRuleProvider();
      _chatProvider = ChatProvider();

      // Test provider availability
      await _testProviderAvailability();

      // Select best available provider
      await _selectBestProvider();

      // Initialize cache
      await _cache.initialize();

      _initialized = true;
      _logger.i('Enhanced AI Service initialized with provider: $_currentProvider');
    } catch (e) {
      _logger.e('Failed to initialize Enhanced AI Service: $e');
      rethrow;
    }
  }

  /// Analyze plant image with automatic provider fallback
  Future<PlantAnalysisResult> analyzePlant({
    required Uint8List imageData,
    required String strain,
    Map<String, dynamic>? environmentalData,
    PlantAnalysisOptions? options,
  }) async {
    if (!_initialized) await initialize();

    final analysisOptions = options ?? PlantAnalysisOptions();

    try {
      _logger.i('Starting plant analysis with strain: $strain');

      // Generate cache key
      final cacheKey = _generateAnalysisCacheKey(imageData, strain, environmentalData);

      // Check cache first
      final cachedResult = await _cache.getCachedAnalysis(cacheKey);
      if (cachedResult != null && !analysisOptions.forceRefresh) {
        _logger.i('Returning cached analysis result');
        return cachedResult;
      }

      // Preprocess image
      final processedImage = await _imageProcessor.preprocessImage(
        imageData,
        options: analysisOptions.imageProcessing,
      );

      // Try providers in priority order
      PlantAnalysisResult? result;
      AIProviderType? usedProvider;

      for (final providerType in _providerPriority) {
        if (!_providerAvailability[providerType.toString()]!) continue;

        try {
          result = await _analyzeWithProvider(
            providerType,
            processedImage,
            strain,
            environmentalData,
            analysisOptions,
          );
          usedProvider = providerType;
          break;
        } catch (e) {
          _logger.w('Provider $providerType failed: $e, trying next provider');
          // Mark provider as temporarily unavailable
          _providerAvailability[providerType.toString()] = false;
          // Schedule re-check after delay
          Timer(Duration(minutes: 5), () => _testSingleProvider(providerType));
        }
      }

      if (result == null) {
        // All providers failed, use emergency fallback
        result = await _getEmergencyFallbackAnalysis(strain, environmentalData);
        usedProvider = AIProviderType.offlineRules;
      }

      // Cache the result
      await _cache.cacheAnalysis(cacheKey, result);

      // Update provider selection based on success
      if (usedProvider != null && usedProvider != _currentProvider) {
        _currentProvider = usedProvider;
        _logger.i('Switched to provider: $_currentProvider');
      }

      _logger.i('Plant analysis completed with confidence: ${result.confidenceScore.toStringAsFixed(2)}');
      return result;
    } catch (e) {
      _logger.e('Plant analysis completely failed: $e');
      return await _getEmergencyFallbackAnalysis(strain, environmentalData);
    }
  }

  /// Analyze plant with specific provider
  Future<PlantAnalysisResult> _analyzeWithProvider(
    AIProviderType providerType,
    Uint8List imageData,
    String strain,
    Map<String, dynamic>? environmentalData,
    PlantAnalysisOptions options,
  ) async {
    switch (providerType) {
      case AIProviderType.lmStudio:
        return await _lmStudioProvider.analyzePlant(
          imageData: imageData,
          strain: strain,
          environmentalData: environmentalData,
          options: options,
        );
      case AIProviderType.openRouter:
        return await _openRouterProvider.analyzePlant(
          imageData: imageData,
          strain: strain,
          environmentalData: environmentalData,
          options: options,
        );
      case AIProviderType.deviceML:
        return await _deviceMLProvider.analyzePlant(
          imageData: imageData,
          strain: strain,
          environmentalData: environmentalData,
          options: options,
        );
      case AIProviderType.offlineRules:
        return await _offlineRuleProvider.analyzePlant(
          imageData: imageData,
          strain: strain,
          environmentalData: environmentalData,
          options: options,
        );
    }
  }

  /// Generate AI chat response with context awareness
  Future<ChatResponse> generateChatResponse({
    required String message,
    required String sessionId,
    String? currentStrain,
    Map<String, dynamic>? environmentalContext,
    List<ChatMessage>? conversationHistory,
  }) async {
    if (!_initialized) await initialize();

    try {
      _logger.i('Generating chat response for session: $sessionId');

      // Enrich context with real-time sensor data if available
      final enrichedContext = await _enrichChatContext(environmentalContext);

      final response = await _chatProvider.generateResponse(
        message: message,
        sessionId: sessionId,
        currentStrain: currentStrain,
        environmentalContext: enrichedContext,
        conversationHistory: conversationHistory ?? [],
        currentProvider: _currentProvider!,
      );

      // Cache conversation
      await _cache.cacheChatMessage(sessionId, message, response);

      return response;
    } catch (e) {
      _logger.e('Chat response generation failed: $e');
      return ChatResponse(
        message: 'I apologize, but I\'m having trouble processing your message right now. Please try again or rephrase your question.',
        sessionId: sessionId,
        timestamp: DateTime.now(),
        confidence: 0.5,
        source: 'fallback',
      );
    }
  }

  /// Get real-time analysis suggestions based on sensor data
  Future<List<AnalysisSuggestion>> getRealTimeSuggestions({
    required Map<String, dynamic> sensorData,
    String? currentStrain,
  }) async {
    if (!_initialized) await initialize();

    try {
      final suggestions = <AnalysisSuggestion>[];

      // Analyze sensor data for anomalies
      final anomalies = _analyzeSensorAnomalies(sensorData);

      for (final anomaly in anomalies) {
        suggestions.add(AnalysisSuggestion(
          type: SuggestionType.environmental,
          title: anomaly['title'],
          description: anomaly['description'],
          priority: anomaly['priority'],
          actionableSteps: List<String>.from(anomaly['steps']),
        ));
      }

      // Add strain-specific suggestions
      if (currentStrain != null) {
        final strainSuggestions = await _getStrainSpecificSuggestions(
          currentStrain,
          sensorData,
        );
        suggestions.addAll(strainSuggestions);
      }

      // Sort by priority
      suggestions.sort((a, b) => b.priority.index.compareTo(a.priority.index));

      return suggestions;
    } catch (e) {
      _logger.e('Failed to generate real-time suggestions: $e');
      return [];
    }
  }

  /// Batch analyze multiple images efficiently
  Future<List<PlantAnalysisResult>> batchAnalyze({
    required List<Uint8List> images,
    required String strain,
    Map<String, dynamic>? environmentalData,
    PlantAnalysisOptions? options,
  }) async {
    if (!_initialized) await initialize();

    final results = <PlantAnalysisResult>[];
    final batchOptions = options?.copyWith(isBatchAnalysis: true) ??
                        PlantAnalysisOptions(isBatchAnalysis: true);

    try {
      // Process in parallel batches to manage memory
      const batchSize = 3;
      for (int i = 0; i < images.length; i += batchSize) {
        final batch = images.skip(i).take(batchSize).toList();
        final futures = batch.map((image) => analyzePlant(
          imageData: image,
          strain: strain,
          environmentalData: environmentalData,
          options: batchOptions,
        ));

        final batchResults = await Future.wait(futures);
        results.addAll(batchResults);

        // Small delay between batches to prevent overheating
        if (i + batchSize < images.length) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      return results;
    } catch (e) {
      _logger.e('Batch analysis failed: $e');
      rethrow;
    }
  }

  /// Test availability of all providers
  Future<void> _testProviderAvailability() async {
    _logger.i('Testing AI provider availability...');

    for (final providerType in _providerPriority) {
      final isAvailable = await _testSingleProvider(providerType);
      _providerAvailability[providerType.toString()] = isAvailable;
      _logger.d('Provider $providerType available: $isAvailable');
    }
  }

  /// Test individual provider availability
  Future<bool> _testSingleProvider(AIProviderType providerType) async {
    try {
      switch (providerType) {
        case AIProviderType.lmStudio:
          return await _lmStudioProvider.testConnection();
        case AIProviderType.openRouter:
          return await _openRouterProvider.testConnection();
        case AIProviderType.deviceML:
          return await _deviceMLProvider.isAvailable();
        case AIProviderType.offlineRules:
          return true; // Always available
      }
    } catch (e) {
      _logger.w('Provider test failed for $providerType: $e');
      return false;
    }
  }

  /// Select best available provider based on capabilities and availability
  Future<void> _selectBestProvider() async {
    for (final providerType in _providerPriority) {
      if (_providerAvailability[providerType.toString()] == true) {
        _currentProvider = providerType;
        _logger.i('Selected AI provider: $providerType');
        return;
      }
    }

    // Fallback to offline rules
    _currentProvider = AIProviderType.offlineRules;
    _logger.w('All online providers unavailable, using offline rules');
  }

  /// Generate cache key for analysis
  String _generateAnalysisCacheKey(
    Uint8List imageData,
    String strain,
    Map<String, dynamic>? environmentalData,
  ) {
    final imageHash = _imageProcessor.generateImageHash(imageData);
    final envHash = environmentalData != null
        ? jsonEncode(environmentalData).hashCode.toString()
        : '';
    return '${imageHash}_${strain}_$envHash';
  }

  /// Enrich chat context with real-time data
  Future<Map<String, dynamic>> _enrichChatContext(
    Map<String, dynamic>? context,
  ) async {
    final enriched = Map<String, dynamic>.from(context ?? {});

    try {
      // Add current provider info
      enriched['current_ai_provider'] = _currentProvider.toString();
      enriched['analysis_mode'] = _isOnlineMode() ? 'online' : 'offline';

      // Add system status
      enriched['system_status'] = {
        'available_providers': _providerAvailability.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList(),
        'current_provider': _currentProvider.toString(),
      };

      return enriched;
    } catch (e) {
      _logger.e('Failed to enrich chat context: $e');
      return context ?? {};
    }
  }

  /// Analyze sensor data for anomalies
  List<Map<String, dynamic>> _analyzeSensorAnomalies(Map<String, dynamic> sensorData) {
    final anomalies = <Map<String, dynamic>>[];

    // Temperature anomalies
    if (sensorData.containsKey('temperature')) {
      final temp = sensorData['temperature'] as double? ?? 0.0;
      if (temp < AppConstants.defaultTempMin) {
        anomalies.add({
          'title': 'Low Temperature Alert',
          'description': 'Temperature is ${temp.toStringAsFixed(1)}°C, below optimal range',
          'priority': SuggestionPriority.medium,
          'steps': ['Increase temperature by 2-3°C', 'Check heating system'],
        });
      } else if (temp > AppConstants.defaultTempMax) {
        anomalies.add({
          'title': 'High Temperature Alert',
          'description': 'Temperature is ${temp.toStringAsFixed(1)}°C, above optimal range',
          'priority': SuggestionPriority.high,
          'steps': ['Improve ventilation', 'Reduce lighting intensity', 'Add cooling'],
        });
      }
    }

    // Humidity anomalies
    if (sensorData.containsKey('humidity')) {
      final humidity = sensorData['humidity'] as double? ?? 0.0;
      if (humidity < AppConstants.defaultHumidityMin) {
        anomalies.add({
          'title': 'Low Humidity Alert',
          'description': 'Humidity is ${humidity.toStringAsFixed(1)}%, below optimal range',
          'priority': SuggestionPriority.medium,
          'steps': ['Add humidifier', 'Mist plants', 'Increase watering'],
        });
      } else if (humidity > AppConstants.defaultHumidityMax) {
        anomalies.add({
          'title': 'High Humidity Alert',
          'description': 'Humidity is ${humidity.toStringAsFixed(1)}%, above optimal range',
          'priority': SuggestionPriority.high,
          'steps': ['Increase ventilation', 'Add dehumidifier', 'Prune lower leaves'],
        });
      }
    }

    return anomalies;
  }

  /// Get strain-specific suggestions
  Future<List<AnalysisSuggestion>> _getStrainSpecificSuggestions(
    String strain,
    Map<String, dynamic> sensorData,
  ) async {
    // This would integrate with strain database
    // For now, return empty list
    return [];
  }

  /// Get emergency fallback analysis when all providers fail
  Future<PlantAnalysisResult> _getEmergencyFallbackAnalysis(
    String strain,
    Map<String, dynamic>? environmentalData,
  ) async {
    return PlantAnalysisResult(
      strainDetected: strain,
      symptoms: ['Analysis temporarily unavailable'],
      severity: AnalysisSeverity.unknown,
      confidenceScore: 0.3,
      detectedIssues: [],
      deficiencies: [],
      diseases: [],
      pests: [],
      environmentalIssues: [],
      recommendations: [
        'Please try again in a few moments',
        'Ensure good lighting and focus for images',
        'Check internet connection for enhanced analysis',
      ],
      actionableSteps: ['Monitor plant closely'],
      estimatedRecoveryTime: 'Unknown',
      preventionTips: ['Regular monitoring', 'Proper environmental control'],
      growthStage: null,
      isPurpleStrain: strain.toLowerCase().contains('purple'),
      metrics: PlantMetrics(
        leafColorScore: 0.5,
        leafHealthScore: 0.5,
        overallVigorScore: 0.5,
      ),
      analysisTimestamp: DateTime.now(),
      analysisType: 'emergency_fallback',
      processingTime: Duration(milliseconds: 100),
      provider: 'offline_rules',
    );
  }

  /// Check if currently using online mode
  bool _isOnlineMode() {
    return _currentProvider != AIProviderType.offlineRules;
  }

  /// Get current provider status
  Map<String, dynamic> getProviderStatus() {
    return {
      'current_provider': _currentProvider.toString(),
      'provider_availability': _providerAvailability,
      'is_online_mode': _isOnlineMode(),
      'initialized': _initialized,
    };
  }

  /// Force switch to specific provider
  Future<bool> switchProvider(AIProviderType providerType) async {
    if (!_providerAvailability[providerType.toString()]!) {
      // Test provider before switching
      final isAvailable = await _testSingleProvider(providerType);
      if (!isAvailable) {
        _logger.w('Provider $providerType is not available');
        return false;
      }
      _providerAvailability[providerType.toString()] = true;
    }

    _currentProvider = providerType;
    _logger.i('Manually switched to provider: $providerType');
    return true;
  }

  /// Clear all caches
  Future<void> clearCaches() async {
    await _cache.clearAllCaches();
    _logger.i('AI service caches cleared');
  }

  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'initialized': _initialized,
      'current_provider': _currentProvider.toString(),
      'provider_availability': _providerAvailability,
      'cache_stats': _cache.getStatistics(),
      'is_online_mode': _isOnlineMode(),
    };
  }

  /// Dispose of all resources
  Future<void> dispose() async {
    await _cache.dispose();

    // Dispose providers
    try {
      await _lmStudioProvider.dispose();
    } catch (e) {
      _logger.w('Error disposing LM Studio provider: $e');
    }

    try {
      await _openRouterProvider.dispose();
    } catch (e) {
      _logger.w('Error disposing OpenRouter provider: $e');
    }

    try {
      await _deviceMLProvider.dispose();
    } catch (e) {
      _logger.w('Error disposing Device ML provider: $e');
    }

    _initialized = false;
    _logger.i('Enhanced AI Service disposed');
  }
}

// Supporting classes and enums

enum AIProviderType {
  lmStudio,
  openRouter,
  deviceML,
  offlineRules,
}

class PlantAnalysisOptions {
  final bool forceRefresh;
  final bool includeDetailedMetrics;
  final bool useAdvancedDetection;
  final ImageProcessingOptions imageProcessing;
  final bool isBatchAnalysis;
  final Duration? timeout;

  const PlantAnalysisOptions({
    this.forceRefresh = false,
    this.includeDetailedMetrics = true,
    this.useAdvancedDetection = true,
    this.imageProcessing = const ImageProcessingOptions(),
    this.isBatchAnalysis = false,
    this.timeout,
  });

  PlantAnalysisOptions copyWith({
    bool? forceRefresh,
    bool? includeDetailedMetrics,
    bool? useAdvancedDetection,
    ImageProcessingOptions? imageProcessing,
    bool? isBatchAnalysis,
    Duration? timeout,
  }) {
    return PlantAnalysisOptions(
      forceRefresh: forceRefresh ?? this.forceRefresh,
      includeDetailedMetrics: includeDetailedMetrics ?? this.includeDetailedMetrics,
      useAdvancedDetection: useAdvancedDetection ?? this.useAdvancedDetection,
      imageProcessing: imageProcessing ?? this.imageProcessing,
      isBatchAnalysis: isBatchAnalysis ?? this.isBatchAnalysis,
      timeout: timeout ?? this.timeout,
    );
  }
}

class ImageProcessingOptions {
  final int maxWidth;
  final int maxHeight;
  final double quality;
  final bool enhanceContrast;
  final bool autoCrop;
  final bool detectLeaves;

  const ImageProcessingOptions({
    this.maxWidth = 1024,
    this.maxHeight = 1024,
    this.quality = 0.85,
    this.enhanceContrast = true,
    this.autoCrop = true,
    this.detectLeaves = true,
  });
}

class PlantAnalysisResult {
  final String strainDetected;
  final List<String> symptoms;
  final AnalysisSeverity severity;
  final double confidenceScore;
  final List<String> detectedIssues;
  final List<String> deficiencies;
  final List<String> diseases;
  final List<String> pests;
  final List<String> environmentalIssues;
  final List<String> recommendations;
  final List<String> actionableSteps;
  final String estimatedRecoveryTime;
  final List<String> preventionTips;
  final String? growthStage;
  final bool isPurpleStrain;
  final PlantMetrics metrics;
  final DateTime analysisTimestamp;
  final String analysisType;
  final Duration processingTime;
  final String provider;

  const PlantAnalysisResult({
    required this.strainDetected,
    required this.symptoms,
    required this.severity,
    required this.confidenceScore,
    this.detectedIssues = const [],
    this.deficiencies = const [],
    this.diseases = const [],
    this.pests = const [],
    this.environmentalIssues = const [],
    this.recommendations = const [],
    this.actionableSteps = const [],
    required this.estimatedRecoveryTime,
    this.preventionTips = const [],
    this.growthStage,
    this.isPurpleStrain = false,
    required this.metrics,
    required this.analysisTimestamp,
    required this.analysisType,
    required this.processingTime,
    required this.provider,
  });
}

class PlantMetrics {
  final double? leafColorScore;
  final double? leafHealthScore;
  final double? growthRateScore;
  final double? pestDamageScore;
  final double? nutrientDeficiencyScore;
  final double? diseaseScore;
  final double? overallVigorScore;
  final Map<String, double>? customMetrics;

  const PlantMetrics({
    this.leafColorScore,
    this.leafHealthScore,
    this.growthRateScore,
    this.pestDamageScore,
    this.nutrientDeficiencyScore,
    this.diseaseScore,
    this.overallVigorScore,
    this.customMetrics,
  });
}

enum AnalysisSeverity {
  healthy,
  mild,
  moderate,
  severe,
  unknown,
}

class ChatResponse {
  final String message;
  final String sessionId;
  final DateTime timestamp;
  final double confidence;
  final String source;
  final List<String>? suggestedQuestions;
  final Map<String, dynamic>? metadata;

  const ChatResponse({
    required this.message,
    required this.sessionId,
    required this.timestamp,
    required this.confidence,
    required this.source,
    this.suggestedQuestions,
    this.metadata,
  });
}

class ChatMessage {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final String? sessionId;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.sessionId,
    this.metadata,
  });
}

class AnalysisSuggestion {
  final SuggestionType type;
  final String title;
  final String description;
  final SuggestionPriority priority;
  final List<String> actionableSteps;
  final DateTime? expiresAt;

  const AnalysisSuggestion({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.actionableSteps,
    this.expiresAt,
  });
}

enum SuggestionType {
  environmental,
  nutrient,
  pest,
  disease,
  lighting,
  watering,
  harvesting,
}

enum SuggestionPriority {
  low,
  medium,
  high,
  critical,
}