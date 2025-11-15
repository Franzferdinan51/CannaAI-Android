import 'dart:async';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import '../enhanced_ai_service.dart';

/// Base interface for all AI providers
abstract class BaseAIProvider {
  final Logger _logger = Logger();

  /// Analyze plant image and return analysis result
  Future<PlantAnalysisResult> analyzePlant({
    required Uint8List imageData,
    required String strain,
    Map<String, dynamic>? environmentalData,
    required PlantAnalysisOptions options,
  });

  /// Test provider connectivity/availability
  Future<bool> testConnection();

  /// Get provider capabilities
  ProviderCapabilities getCapabilities();

  /// Get provider name
  String getProviderName();

  /// Get provider type
  AIProviderType getProviderType();

  /// Dispose provider resources
  Future<void> dispose();

  /// Log provider-specific events
  void logEvent(String event, Map<String, dynamic>? metadata) {
    _logger.d('[$getProviderName()] $event', error: metadata);
  }
}

/// Provider capabilities definition
class ProviderCapabilities {
  final bool supportsImageAnalysis;
  final bool supportsBatchAnalysis;
  final bool supportsRealTimeAnalysis;
  final bool supportsDetailedMetrics;
  final bool supportsConfidenceScoring;
  final bool supportsStrainDetection;
  final bool supportsGrowthStageDetection;
  final bool supportsPurpleStrainDetection;
  final bool supportsEnvironmentalContext;
  final int maxImageSize;
  final int maxBatchSize;
  final Duration averageProcessingTime;
  final bool requiresInternet;
  final double reliabilityScore;

  const ProviderCapabilities({
    required this.supportsImageAnalysis,
    required this.supportsBatchAnalysis,
    required this.supportsRealTimeAnalysis,
    required this.supportsDetailedMetrics,
    required this.supportsConfidenceScoring,
    required this.supportsStrainDetection,
    required this.supportsGrowthStageDetection,
    required this.supportsPurpleStrainDetection,
    required this.supportsEnvironmentalContext,
    required this.maxImageSize,
    required this.maxBatchSize,
    required this.averageProcessingTime,
    required this.requiresInternet,
    required this.reliabilityScore,
  });
}

/// Base class for online AI providers
abstract class OnlineAIProvider extends BaseAIProvider {
  String? _baseUrl;
  String? _apiKey;
  Duration _timeout = Duration(seconds: 30);
  int _maxRetries = 3;

  /// Configure provider
  void configure({
    String? baseUrl,
    String? apiKey,
    Duration? timeout,
    int? maxRetries,
  }) {
    _baseUrl = baseUrl;
    _apiKey = apiKey;
    if (timeout != null) _timeout = timeout;
    if (maxRetries != null) _maxRetries = maxRetries;
  }

  /// Get base URL
  String? get baseUrl => _baseUrl;

  /// Get API key
  String? get apiKey => _apiKey;

  /// Get timeout
  Duration get timeout => _timeout;

  /// Get max retries
  int get maxRetries => _maxRetries;

  /// Make HTTP request with retry logic
  Future<Map<String, dynamic>> makeRequestWithRetry(
    String endpoint,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async {
    Map<String, dynamic>? lastError;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final result = await makeHttpRequest(
          endpoint,
          data,
          headers: headers,
          timeout: _timeout * (attempt + 1), // Exponential backoff
        );
        return result;
      } catch (e) {
        lastError = {
          'error': e.toString(),
          'attempt': attempt + 1,
          'provider': getProviderName(),
        };
        logEvent('Request attempt ${attempt + 1} failed', lastError);

        if (attempt < _maxRetries - 1) {
          // Wait before retry with exponential backoff
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }

    throw Exception('All retry attempts failed. Last error: $lastError');
  }

  /// Make actual HTTP request (to be implemented by concrete providers)
  Future<Map<String, dynamic>> makeHttpRequest(
    String endpoint,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
    Duration? timeout,
  });
}

/// Base class for offline AI providers
abstract class OfflineAIProvider extends BaseAIProvider {
  /// Initialize provider resources
  Future<void> initialize() async {}

  /// Check if provider is ready for use
  bool isReady() => true;

  /// Load provider models/data
  Future<void> loadModels() async {}

  /// Unload provider models/data to free memory
  Future<void> unloadModels() async {}
}