import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'enhanced_ai_service.dart';
import 'api_service.dart';
import 'local_ai_service.dart';
import '../constants/app_constants.dart';

/// AI Integration Service that bridges the new AI system with existing app architecture
class AIIntegrationService {
  static final AIIntegrationService _instance = AIIntegrationService._internal();
  factory AIIntegrationService() => _instance;
  AIIntegrationService._internal();

  final Logger _logger = Logger();
  final EnhancedAIService _enhancedAI = EnhancedAIService();
  final LocalAIService _localAI = LocalAIService();
  final ApiService _apiService = ApiService();

  bool _initialized = false;
  AIProviderType? _currentProvider;

  /// Initialize the AI integration service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _logger.i('Initializing AI Integration Service...');

      // Initialize enhanced AI service
      await _enhancedAI.initialize();

      // Get current provider status
      final status = _enhancedAI.getProviderStatus();
      _currentProvider = _parseProviderType(status['current_provider'] as String?);

      _initialized = true;
      _logger.i('AI Integration Service initialized with provider: $_currentProvider');
    } catch (e) {
      _logger.e('Failed to initialize AI Integration Service: $e');
      rethrow;
    }
  }

  /// Enhanced plant analysis using the new AI service
  Future<Map<String, dynamic>> analyzePlantEnhanced({
    required String imagePath,
    required String strain,
    Map<String, dynamic>? environmentalData,
    bool forceRefresh = false,
    AnalysisType? analysisType,
  }) async {
    if (!_initialized) await initialize();

    try {
      _logger.i('Starting enhanced plant analysis for strain: $strain');

      // Read image data
      final file = await File(imagePath).readAsBytes();

      // Determine analysis options based on type
      final options = _getAnalysisOptions(analysisType, forceRefresh);

      // Perform enhanced analysis
      final result = await _enhancedAI.analyzePlant(
        imageData: file,
        strain: strain,
        environmentalData: environmentalData,
        options: options,
      );

      // Convert to API-compatible format
      final apiCompatibleResult = _convertToAPIFormat(result, imagePath, strain);

      // Save to local storage using existing API service
      await _apiService.analyzePlant(
        imagePath: imagePath,
        strain: strain,
        environmentalData: environmentalData,
      );

      _logger.i('Enhanced plant analysis completed successfully');
      return {
        'success': true,
        'data': apiCompatibleResult,
        'enhanced_analysis': result,
        'ai_provider': result.provider,
        'confidence': result.confidenceScore,
        'processing_time': result.processingTime.inMilliseconds,
      };
    } catch (e) {
      _logger.e('Enhanced plant analysis failed: $e');

      // Fallback to local AI service
      try {
        _logger.i('Falling back to local AI service');
        return await _analyzePlantWithLocalAI(imagePath, strain, environmentalData);
      } catch (fallbackError) {
        _logger.e('Fallback analysis also failed: $fallbackError');
        return {
          'success': false,
          'error': 'Analysis failed: ${e.toString()}',
          'fallback_error': fallbackError.toString(),
        };
      }
    }
  }

  /// Enhanced chat with context awareness
  Future<Map<String, dynamic>> sendEnhancedChatMessage({
    required String message,
    String? sessionId,
    String? currentStrain,
    Map<String, dynamic>? environmentalContext,
    List<Map<String, dynamic>>? conversationHistory,
  }) async {
    if (!_initialized) await initialize();

    try {
      _logger.i('Sending enhanced chat message for session: $sessionId');

      // Convert conversation history
      final chatHistory = conversationHistory?.map((msg) => ChatMessage(
        message: msg['message'] as String,
        isUser: msg['isUser'] as bool,
        timestamp: DateTime.parse(msg['timestamp'] as String),
        sessionId: sessionId,
      )).toList();

      // Generate enhanced response
      final response = await _enhancedAI.generateChatResponse(
        message: message,
        sessionId: sessionId ?? 'default',
        currentStrain: currentStrain,
        environmentalContext: environmentalContext,
        conversationHistory: chatHistory ?? [],
      );

      // Save to local storage
      await _apiService.sendChatMessage(
        message: message,
        sessionId: sessionId,
        currentStrain: currentStrain,
        environmentalContext: environmentalContext,
      );

      return {
        'success': true,
        'data': {
          'user_message': message,
          'ai_response': response.message,
          'session_id': sessionId,
          'timestamp': response.timestamp.toIso8601String(),
          'confidence': response.confidence,
          'source': response.source,
          'suggested_questions': response.suggestedQuestions,
          'metadata': response.metadata,
        },
        'enhanced_features': {
          'context_aware': true,
          'personalized': response.metadata?['expertise_level'] != null,
          'suggestions_available': response.suggestedQuestions?.isNotEmpty ?? false,
        },
      };
    } catch (e) {
      _logger.e('Enhanced chat failed: $e');

      // Fallback to local AI service
      try {
        _logger.i('Falling back to local AI chat');
        return await _apiService.sendChatMessage(
          message: message,
          sessionId: sessionId,
          currentStrain: currentStrain,
          environmentalContext: environmentalContext,
        );
      } catch (fallbackError) {
        _logger.e('Fallback chat also failed: $fallbackError');
        return {
          'success': false,
          'error': 'Chat failed: ${e.toString()}',
          'fallback_error': fallbackError.toString(),
        };
      }
    }
  }

  /// Get real-time suggestions based on sensor data
  Future<List<Map<String, dynamic>>> getRealTimeSuggestions({
    Map<String, dynamic>? sensorData,
    String? currentStrain,
  }) async {
    if (!_initialized) await initialize();

    try {
      // Use enhanced AI if available, otherwise generate basic suggestions
      final suggestions = await _enhancedAI.getRealTimeSuggestions(
        sensorData: sensorData ?? {},
        currentStrain: currentStrain,
      );

      return suggestions.map((suggestion) => {
        'id': DateTime.now().millisecondsSinceEpoch.toString() + suggestion.type.name,
        'type': suggestion.type.name,
        'title': suggestion.title,
        'description': suggestion.description,
        'priority': suggestion.priority.name,
        'actionable_steps': suggestion.actionableSteps,
        'expires_at': suggestion.expiresAt?.toIso8601String(),
        'ai_generated': true,
        'provider': _currentProvider.toString(),
      }).toList();
    } catch (e) {
      _logger.e('Failed to get real-time suggestions: $e');
      return _generateBasicSuggestions(sensorData, currentStrain);
    }
  }

  /// Batch analyze multiple images
  Future<Map<String, dynamic>> batchAnalyzePlants({
    required List<String> imagePaths,
    required String strain,
    Map<String, dynamic>? environmentalData,
    bool forceRefresh = false,
  }) async {
    if (!_initialized) await initialize();

    try {
      _logger.i('Starting batch analysis of ${imagePaths.length} images');

      final results = await _enhancedAI.batchAnalyze(
        images: imagePaths.map((path) => File(path).readAsBytesSync()).toList(),
        strain: strain,
        environmentalData: environmentalData,
        options: PlantAnalysisOptions(forceRefresh: forceRefresh, isBatchAnalysis: true),
      );

      final convertedResults = results.asMap().entries.map((entry) {
        final index = entry.key;
        final result = entry.value;
        return {
          'index': index,
          'image_path': imagePaths[index],
          'analysis': _convertToAPIFormat(result, imagePaths[index], strain),
          'enhanced_data': result,
        };
      }).toList();

      return {
        'success': true,
        'results': convertedResults,
        'total_processed': results.length,
        'batch_id': DateTime.now().millisecondsSinceEpoch.toString(),
        'provider': _currentProvider.toString(),
      };
    } catch (e) {
      _logger.e('Batch analysis failed: $e');
      return {
        'success': false,
        'error': 'Batch analysis failed: ${e.toString()}',
        'processed_count': 0,
      };
    }
  }

  /// Switch AI provider
  Future<bool> switchAIProvider(String providerName) async {
    if (!_initialized) await initialize();

    try {
      final providerType = _parseProviderType(providerName);
      if (providerType == null) {
        _logger.e('Unknown provider: $providerName');
        return false;
      }

      final success = await _enhancedAI.switchProvider(providerType);
      if (success) {
        _currentProvider = providerType;
        _logger.i('Switched to AI provider: $providerName');
      }

      return success;
    } catch (e) {
      _logger.e('Failed to switch AI provider: $e');
      return false;
    }
  }

  /// Get current AI service status
  Map<String, dynamic> getAIStatus() {
    if (!_initialized) {
      return {
        'initialized': false,
        'status': 'Not initialized',
      };
    }

    final enhancedStatus = _enhancedAI.getProviderStatus();
    final statistics = _enhancedAI.getStatistics();

    return {
      'initialized': true,
      'current_provider': _currentProvider.toString(),
      'enhanced_status': enhancedStatus,
      'statistics': statistics,
      'features': {
        'multi_provider_support': true,
        'offline_capability': true,
        'batch_analysis': true,
        'real_time_suggestions': true,
        'context_aware_chat': true,
        'image_processing': true,
        'caching': true,
      },
    };
  }

  /// Clear AI caches
  Future<void> clearCaches() async {
    if (_initialized) {
      await _enhancedAI.clearCaches();
      _logger.i('AI caches cleared');
    }
  }

  /// Analyze plant with local AI service (fallback)
  Future<Map<String, dynamic>> _analyzePlantWithLocalAI(
    String imagePath,
    String strain,
    Map<String, dynamic>? environmentalData,
  ) async {
    final result = await _localAI.analyzePlantHealth(
      imageData: await File(imagePath).readAsBytes(),
      strain: strain,
      environmentalData: environmentalData,
    );

    return {
      'success': true,
      'data': {
        'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
        'userId': 'current_user',
        'strainId': strain,
        'imageUrl': imagePath,
        'timestamp': DateTime.now().toIso8601String(),
        'result': {
          'overallHealth': _mapLocalSeverityToHealth(result['severity']),
          'confidence': result['confidence_score'],
          'detectedIssues': result['detected_issues'],
          'detectedDeficiencies': result['symptoms'],
          'recommendations': result['recommendations'],
          'metrics': {
            'leafColorScore': 0.7,
            'leafHealthScore': result['confidence_score'],
            'overallVigorScore': result['confidence_score'],
          },
        },
        'notes': 'Analysis performed with local AI',
        'isBookmarked': false,
        'metadata': {
          'analysis_type': 'local_ai',
          'offline_mode': true,
        },
      },
      'local_analysis': result,
      'fallback_used': true,
    };
  }

  /// Generate basic suggestions without AI
  List<Map<String, dynamic>> _generateBasicSuggestions(
    Map<String, dynamic>? sensorData,
    String? currentStrain,
  ) {
    final suggestions = <Map<String, dynamic>>[];

    if (sensorData != null) {
      // Temperature suggestions
      if (sensorData.containsKey('temperature')) {
        final temp = sensorData['temperature'] as double? ?? 0.0;
        if (temp < AppConstants.defaultTempMin) {
          suggestions.add({
            'id': 'temp_low',
            'type': 'environmental',
            'title': 'Low Temperature Alert',
            'description': 'Temperature is ${temp.toStringAsFixed(1)}°C, below optimal range',
            'priority': 'medium',
            'actionable_steps': ['Increase temperature by 2-3°C', 'Check heating system'],
            'ai_generated': false,
          });
        } else if (temp > AppConstants.defaultTempMax) {
          suggestions.add({
            'id': 'temp_high',
            'type': 'environmental',
            'title': 'High Temperature Alert',
            'description': 'Temperature is ${temp.toStringAsFixed(1)}°C, above optimal range',
            'priority': 'high',
            'actionable_steps': ['Improve ventilation', 'Reduce lighting intensity'],
            'ai_generated': false,
          });
        }
      }

      // Humidity suggestions
      if (sensorData.containsKey('humidity')) {
        final humidity = sensorData['humidity'] as double? ?? 0.0;
        if (humidity < AppConstants.defaultHumidityMin) {
          suggestions.add({
            'id': 'humidity_low',
            'type': 'environmental',
            'title': 'Low Humidity Alert',
            'description': 'Humidity is ${humidity.toStringAsFixed(1)}%, below optimal range',
            'priority': 'medium',
            'actionable_steps': ['Add humidifier', 'Mist plants regularly'],
            'ai_generated': false,
          });
        } else if (humidity > AppConstants.defaultHumidityMax) {
          suggestions.add({
            'id': 'humidity_high',
            'type': 'environmental',
            'title': 'High Humidity Alert',
            'description': 'Humidity is ${humidity.toStringAsFixed(1)}%, above optimal range',
            'priority': 'high',
            'actionable_steps': ['Increase ventilation', 'Add dehumidifier'],
            'ai_generated': false,
          });
        }
      }
    }

    // General suggestions
    if (suggestions.isEmpty) {
      suggestions.add({
        'id': 'general_check',
        'type': 'maintenance',
        'title': 'General Plant Check',
        'description': 'Perform routine plant health check',
        'priority': 'low',
        'actionable_steps': ['Check leaves for discoloration', 'Inspect for pests', 'Verify environmental conditions'],
        'ai_generated': false,
      });
    }

    return suggestions;
  }

  /// Get analysis options based on type
  PlantAnalysisOptions _getAnalysisOptions(AnalysisType? type, bool forceRefresh) {
    switch (type) {
      case AnalysisType.quick:
        return PlantAnalysisOptions(
          forceRefresh: forceRefresh,
          includeDetailedMetrics: false,
          useAdvancedDetection: false,
          timeout: Duration(seconds: 10),
        );
      case AnalysisType.detailed:
        return PlantAnalysisOptions(
          forceRefresh: forceRefresh,
          includeDetailedMetrics: true,
          useAdvancedDetection: true,
          timeout: Duration(seconds: 30),
        );
      case AnalysisType.trichome:
        return PlantAnalysisOptions(
          forceRefresh: forceRefresh,
          includeDetailedMetrics: true,
          useAdvancedDetection: true,
          imageProcessing: ImageProcessingOptions(
            maxWidth: 2048,
            maxHeight: 2048,
            quality: 0.95,
            enhanceContrast: true,
          ),
          timeout: Duration(seconds: 20),
        );
      default:
        return PlantAnalysisOptions(forceRefresh: forceRefresh);
    }
  }

  /// Convert enhanced analysis result to API-compatible format
  Map<String, dynamic> _convertToAPIFormat(
    PlantAnalysisResult result,
    String imagePath,
    String strain,
  ) {
    return {
      'id': 'enhanced_${DateTime.now().millisecondsSinceEpoch}',
      'userId': 'current_user',
      'strainId': strain,
      'imageUrl': imagePath,
      'timestamp': result.analysisTimestamp.toIso8601String(),
      'result': {
        'overallHealth': _mapSeverityToHealth(result.severity),
        'confidence': result.confidenceScore,
        'detectedIssues': result.detectedIssues,
        'detectedDeficiencies': result.deficiencies,
        'detectedDiseases': result.diseases,
        'detectedPests': result.pests,
        'growthStage': result.growthStage,
        'recommendedAction': result.recommendations.isNotEmpty
            ? result.recommendations.first
            : null,
        'recommendations': result.recommendations,
        'metrics': {
          'leafColorScore': result.metrics.leafColorScore,
          'leafHealthScore': result.metrics.leafHealthScore,
          'growthRateScore': result.metrics.growthRateScore,
          'pestDamageScore': result.metrics.pestDamageScore,
          'nutrientDeficiencyScore': result.metrics.nutrientDeficiencyScore,
          'diseaseScore': result.metrics.diseaseScore,
          'overallVigorScore': result.metrics.overallVigorScore,
          'customMetrics': result.metrics.customMetrics,
        },
        'isPurpleStrain': result.isPurpleStrain,
      },
      'notes': 'Analysis performed with ${result.provider}',
      'isBookmarked': false,
      'metadata': {
        'ai_provider': result.provider,
        'analysis_type': result.analysisType,
        'processing_time': result.processingTime.inMilliseconds,
        'enhanced_ai': true,
        'symptoms': result.symptoms,
        'environmental_issues': result.environmentalIssues,
        'actionable_steps': result.actionableSteps,
        'estimated_recovery_time': result.estimatedRecoveryTime,
        'prevention_tips': result.preventionTips,
      },
    };
  }

  /// Map analysis severity to health status
  String _mapSeverityToHealth(AnalysisSeverity severity) {
    switch (severity) {
      case AnalysisSeverity.healthy:
        return 'healthy';
      case AnalysisSeverity.mild:
        return 'stressed';
      case AnalysisSeverity.moderate:
        return 'stressed';
      case AnalysisSeverity.severe:
        return 'critical';
      default:
        return 'unknown';
    }
  }

  /// Map local AI severity to health status
  String _mapLocalSeverityToHealth(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'healthy':
        return 'healthy';
      case 'mild':
        return 'stressed';
      case 'moderate':
        return 'stressed';
      case 'severe':
        return 'critical';
      default:
        return 'unknown';
    }
  }

  /// Parse provider type from string
  AIProviderType? _parseProviderType(String? providerName) {
    if (providerName == null) return null;

    switch (providerName.toLowerCase()) {
      case 'lm studio':
      case 'lm_studio':
        return AIProviderType.lmStudio;
      case 'openrouter':
        return AIProviderType.openRouter;
      case 'device ml':
      case 'device_ml':
        return AIProviderType.deviceML;
      case 'offline rules':
      case 'offline_rules':
        return AIProviderType.offlineRules;
      default:
        return null;
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    if (_initialized) {
      await _enhancedAI.dispose();
      _initialized = false;
      _logger.i('AI Integration Service disposed');
    }
  }
}

// Additional enums for compatibility
enum AnalysisType {
  quick,
  detailed,
  trichome,
  liveVision,
}