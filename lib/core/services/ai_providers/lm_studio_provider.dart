import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'base_ai_provider.dart';
import '../enhanced_ai_service.dart';

/// LM Studio AI provider for local model inference
class LMStudioProvider extends OnlineAIProvider {
  late final Dio _dio;
  bool _isConnected = false;
  String? _modelId;
  ProviderCapabilities? _capabilities;

  LMStudioProvider() {
    _dio = Dio();
    _dio.options.connectTimeout = Duration(seconds: 10);
    _dio.options.receiveTimeout = Duration(seconds: 60);

    // Configure default LM Studio settings
    configure(
      baseUrl: 'http://localhost:1234',
      timeout: Duration(seconds: 45),
      maxRetries: 2,
    );
  }

  @override
  String getProviderName() => 'LM Studio';

  @override
  AIProviderType getProviderType() => AIProviderType.lmStudio;

  @override
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get(
        '${baseUrl}/v1/models',
        options: Options(sendTimeout: Duration(seconds: 5)),
      );

      if (response.statusCode == 200) {
        final models = response.data['data'] as List?;
        if (models != null && models.isNotEmpty) {
          _modelId = models.first['id'] as String?;
          _isConnected = true;

          // Update capabilities based on model
          await _updateCapabilities();

          logEvent('Connected successfully', {
            'model': _modelId,
            'available_models': models.length,
          });
          return true;
        }
      }

      _isConnected = false;
      return false;
    } catch (e) {
      _isConnected = false;
      logEvent('Connection test failed', {'error': e.toString()});
      return false;
    }
  }

  @override
  ProviderCapabilities getCapabilities() {
    return _capabilities ?? ProviderCapabilities(
      supportsImageAnalysis: false, // LM Studio primarily text-based
      supportsBatchAnalysis: true,
      supportsRealTimeAnalysis: true,
      supportsDetailedMetrics: true,
      supportsConfidenceScoring: true,
      supportsStrainDetection: true,
      supportsGrowthStageDetection: true,
      supportsPurpleStrainDetection: true,
      supportsEnvironmentalContext: true,
      maxImageSize: 0, // Not applicable for text models
      maxBatchSize: 10,
      averageProcessingTime: Duration(seconds: 3),
      requiresInternet: false,
      reliabilityScore: 0.85,
    );
  }

  @override
  Future<PlantAnalysisResult> analyzePlant({
    required Uint8List imageData,
    required String strain,
    Map<String, dynamic>? environmentalData,
    required PlantAnalysisOptions options,
  }) async {
    if (!_isConnected) {
      throw Exception('LM Studio not connected');
    }

    try {
      logEvent('Starting plant analysis', {
        'strain': strain,
        'has_environmental_data': environmentalData != null,
      });

      // Convert image to base64 for analysis (if vision model available)
      final imageBase64 = base64Encode(imageData);

      // Create comprehensive analysis prompt
      final prompt = _createAnalysisPrompt(
        strain: strain,
        environmentalData: environmentalData,
        options: options,
      );

      // Prepare request data
      final requestData = {
        'model': _modelId,
        'messages': [
          {
            'role': 'system',
            'content': '''You are an expert cannabis cultivation specialist with deep knowledge of plant health, nutrient deficiencies, pests, diseases, and optimal growing conditions.

Provide detailed analysis in the following JSON format:
{
  "symptoms": ["list of detected symptoms"],
  "severity": "healthy|mild|moderate|severe",
  "confidence_score": 0.0-1.0,
  "detected_issues": ["specific issues identified"],
  "deficiencies": ["nutrient deficiencies"],
  "diseases": ["possible diseases"],
  "pests": ["pests detected"],
  "environmental_issues": ["environmental problems"],
  "recommendations": ["specific recommendations"],
  "actionable_steps": ["immediate actions to take"],
  "estimated_recovery_time": "timeframe for recovery",
  "prevention_tips": ["prevention measures"],
  "growth_stage": "seedling|vegetative|flowering|late flowering",
  "is_purple_strain": true/false,
  "leaf_color_score": 0.0-1.0,
  "leaf_health_score": 0.0-1.0,
  "overall_vigor_score": 0.0-1.0,
  "reasoning": "detailed explanation of analysis"
}''',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'max_tokens': 1500,
        'temperature': 0.3,
        'response_format': {'type': 'json_object'},
      };

      final stopwatch = Stopwatch()..start();

      // Make request to LM Studio
      final response = await makeRequestWithRetry(
        '/v1/chat/completions',
        requestData,
      );

      stopwatch.stop();

      // Parse response
      final content = response['choices']?[0]?['message']?['content'] as String?;
      if (content == null) {
        throw Exception('No content in LM Studio response');
      }

      // Parse JSON response
      final analysisData = jsonDecode(content);

      // Convert to PlantAnalysisResult
      final result = _parseAnalysisResponse(
        analysisData,
        strain,
        stopwatch.elapsed,
      );

      logEvent('Analysis completed', {
        'confidence': result.confidenceScore,
        'severity': result.severity,
        'processing_time': result.processingTime.inMilliseconds,
      });

      return result;
    } catch (e) {
      logEvent('Analysis failed', {'error': e.toString()});
      throw Exception('LM Studio analysis failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> makeHttpRequest(
    String endpoint,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl$endpoint',
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            ...?headers,
          },
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      throw Exception('Dio error: ${e.type} - ${e.message}');
    }
  }

  String _createAnalysisPrompt({
    required String strain,
    Map<String, dynamic>? environmentalData,
    required PlantAnalysisOptions options,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('Please analyze this cannabis plant for health issues:');
    buffer.writeln();
    buffer.writeln('Strain: $strain');

    if (environmentalData != null) {
      buffer.writeln('\nEnvironmental Conditions:');
      environmentalData.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }

    buffer.writeln('\nAnalysis Requirements:');
    buffer.writeln('- Identify any nutrient deficiencies, pests, or diseases');
    buffer.writeln('- Assess overall plant health and severity');
    buffer.writeln('- Provide specific, actionable recommendations');
    buffer.writeln('- Include confidence scores for all assessments');
    buffer.writeln('- Distinguish between purple strains and phosphorus deficiency');

    if (options.useAdvancedDetection) {
      buffer.writeln('- Use advanced detection patterns');
      buffer.writeln('- Consider subtle symptom indicators');
    }

    return buffer.toString();
  }

  PlantAnalysisResult _parseAnalysisResponse(
    Map<String, dynamic> data,
    String strain,
    Duration processingTime,
  ) {
    return PlantAnalysisResult(
      strainDetected: strain,
      symptoms: List<String>.from(data['symptoms'] ?? []),
      severity: _parseSeverity(data['severity'] as String?),
      confidenceScore: (data['confidence_score'] as num?)?.toDouble() ?? 0.5,
      detectedIssues: List<String>.from(data['detected_issues'] ?? []),
      deficiencies: List<String>.from(data['deficiencies'] ?? []),
      diseases: List<String>.from(data['diseases'] ?? []),
      pests: List<String>.from(data['pests'] ?? []),
      environmentalIssues: List<String>.from(data['environmental_issues'] ?? []),
      recommendations: List<String>.from(data['recommendations'] ?? []),
      actionableSteps: List<String>.from(data['actionable_steps'] ?? []),
      estimatedRecoveryTime: data['estimated_recovery_time'] as String? ?? 'Unknown',
      preventionTips: List<String>.from(data['prevention_tips'] ?? []),
      growthStage: data['growth_stage'] as String?,
      isPurpleStrain: data['is_purple_strain'] as bool? ?? false,
      metrics: PlantMetrics(
        leafColorScore: (data['leaf_color_score'] as num?)?.toDouble(),
        leafHealthScore: (data['leaf_health_score'] as num?)?.toDouble(),
        overallVigorScore: (data['overall_vigor_score'] as num?)?.toDouble(),
      ),
      analysisTimestamp: DateTime.now(),
      analysisType: 'lm_studio_ai',
      processingTime: processingTime,
      provider: getProviderName(),
    );
  }

  AnalysisSeverity _parseSeverity(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'healthy':
        return AnalysisSeverity.healthy;
      case 'mild':
        return AnalysisSeverity.mild;
      case 'moderate':
        return AnalysisSeverity.moderate;
      case 'severe':
        return AnalysisSeverity.severe;
      default:
        return AnalysisSeverity.unknown;
    }
  }

  Future<void> _updateCapabilities() async {
    // Update capabilities based on available model
    // This could involve querying model capabilities
    _capabilities = ProviderCapabilities(
      supportsImageAnalysis: false, // Text-based unless vision model detected
      supportsBatchAnalysis: true,
      supportsRealTimeAnalysis: true,
      supportsDetailedMetrics: true,
      supportsConfidenceScoring: true,
      supportsStrainDetection: true,
      supportsGrowthStageDetection: true,
      supportsPurpleStrainDetection: true,
      supportsEnvironmentalContext: true,
      maxImageSize: 0,
      maxBatchSize: 10,
      averageProcessingTime: Duration(seconds: 3),
      requiresInternet: false,
      reliabilityScore: _isConnected ? 0.85 : 0.0,
    );
  }

  /// Get available models
  Future<List<String>> getAvailableModels() async {
    try {
      final response = await _dio.get('${baseUrl}/v1/models');
      if (response.statusCode == 200) {
        final models = response.data['data'] as List?;
        return models?.map((m) => m['id'] as String).toList() ?? [];
      }
    } catch (e) {
      logEvent('Failed to get models', {'error': e.toString()});
    }
    return [];
  }

  /// Switch to specific model
  Future<bool> switchModel(String modelId) async {
    try {
      final models = await getAvailableModels();
      if (models.contains(modelId)) {
        _modelId = modelId;
        await _updateCapabilities();
        logEvent('Switched to model', {'model': modelId});
        return true;
      }
      return false;
    } catch (e) {
      logEvent('Model switch failed', {'error': e.toString()});
      return false;
    }
  }

  /// Get current model info
  Map<String, dynamic>? getCurrentModelInfo() {
    if (_modelId == null) return null;

    return {
      'id': _modelId,
      'connected': _isConnected,
      'provider': getProviderName(),
    };
  }

  @override
  Future<void> dispose() async {
    _dio.close();
    _isConnected = false;
    _modelId = null;
    logEvent('Provider disposed', {});
  }
}