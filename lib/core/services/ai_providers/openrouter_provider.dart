import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'base_ai_provider.dart';
import '../enhanced_ai_service.dart';

/// OpenRouter AI provider for cloud-based model access
class OpenRouterProvider extends OnlineAIProvider {
  late final Dio _dio;
  bool _isConnected = false;
  String? _currentModel;
  Map<String, dynamic>? _modelInfo;
  ProviderCapabilities? _capabilities;

  // OpenRouter recommended models for plant analysis
  static const List<String> _recommendedModels = [
    'anthropic/claude-3.5-sonnet',
    'openai/gpt-4-vision-preview',
    'google/gemini-pro-vision',
    'anthropic/claude-3-opus',
    'meta-llama/llama-3.1-70b-instruct',
  ];

  OpenRouterProvider() {
    _dio = Dio();
    _dio.options.connectTimeout = Duration(seconds: 15);
    _dio.options.receiveTimeout = Duration(seconds: 90);

    // Configure OpenRouter settings
    configure(
      baseUrl: 'https://openrouter.ai/api/v1',
      timeout: Duration(seconds: 60),
      maxRetries: 3,
    );
  }

  @override
  String getProviderName() => 'OpenRouter';

  @override
  AIProviderType getProviderType() => AIProviderType.openRouter;

  @override
  Future<bool> testConnection() async {
    if (apiKey == null || apiKey!.isEmpty) {
      logEvent('No API key configured', {});
      return false;
    }

    try {
      // Test with a simple model list request
      final response = await _dio.get(
        '${baseUrl}/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'HTTP-Referer': 'https://cannai.app',
            'X-Title': 'CannaAI Plant Analysis',
          },
          sendTimeout: Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final models = response.data['data'] as List?;
        if (models != null && models.isNotEmpty) {
          // Select best available model for plant analysis
          await _selectBestModel(models);
          _isConnected = true;

          // Update capabilities based on model
          await _updateCapabilities();

          logEvent('Connected successfully', {
            'model': _currentModel,
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
      supportsImageAnalysis: true, // OpenRouter supports vision models
      supportsBatchAnalysis: true,
      supportsRealTimeAnalysis: true,
      supportsDetailedMetrics: true,
      supportsConfidenceScoring: true,
      supportsStrainDetection: true,
      supportsGrowthStageDetection: true,
      supportsPurpleStrainDetection: true,
      supportsEnvironmentalContext: true,
      maxImageSize: 20 * 1024 * 1024, // 20MB
      maxBatchSize: 5,
      averageProcessingTime: Duration(seconds: 8),
      requiresInternet: true,
      reliabilityScore: 0.95,
    );
  }

  @override
  Future<PlantAnalysisResult> analyzePlant({
    required Uint8List imageData,
    required String strain,
    Map<String, dynamic>? environmentalData,
    required PlantAnalysisOptions options,
  }) async {
    if (!_isConnected || apiKey == null) {
      throw Exception('OpenRouter not connected or API key missing');
    }

    try {
      logEvent('Starting plant analysis', {
        'strain': strain,
        'model': _currentModel,
        'has_environmental_data': environmentalData != null,
      });

      // Convert image to base64 for vision models
      final imageBase64 = base64Encode(imageData);
      final mimeType = _detectMimeType(imageData);

      // Create comprehensive analysis prompt
      final prompt = _createAnalysisPrompt(
        strain: strain,
        environmentalData: environmentalData,
        options: options,
      );

      // Prepare request data
      final requestData = {
        'model': _currentModel,
        'messages': [
          {
            'role': 'system',
            'content': '''You are an expert cannabis cultivation specialist with extensive knowledge of plant health diagnosis, nutrient deficiencies, pest identification, disease detection, and optimal growing conditions.

Analyze the provided plant image and environmental data to provide a comprehensive health assessment.

Respond with a detailed JSON analysis in this exact format:
{
  "symptoms": ["specific symptoms observed"],
  "severity": "healthy|mild|moderate|severe",
  "confidence_score": 0.0-1.0,
  "detected_issues": ["detailed issues identified"],
  "deficiencies": ["specific nutrient deficiencies"],
  "diseases": ["possible diseases detected"],
  "pests": ["pests or insects identified"],
  "environmental_issues": ["environmental problems"],
  "recommendations": ["specific treatment recommendations"],
  "actionable_steps": ["immediate actions to take"],
  "estimated_recovery_time": "timeframe for recovery",
  "prevention_tips": ["preventive measures"],
  "growth_stage": "seedling|vegetative|flowering|late flowering",
  "is_purple_strain": true/false,
  "leaf_color_score": 0.0-1.0,
  "leaf_health_score": 0.0-1.0,
  "growth_rate_score": 0.0-1.0,
  "pest_damage_score": 0.0-1.0,
  "nutrient_deficiency_score": 0.0-1.0,
  "disease_score": 0.0-1.0,
  "overall_vigor_score": 0.0-1.0,
  "detailed_analysis": {
    "leaf_condition": "detailed leaf analysis",
    "color_analysis": "color analysis details",
    "structural_assessment": "plant structure assessment",
    "environmental_impact": "environmental factors affecting health"
  },
  "reasoning": "detailed explanation of the analysis process and conclusions"
}

Important: Focus on accurate identification, provide confidence scores, and distinguish between natural purple coloration in purple strains and phosphorus deficiency.''',
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': prompt,
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$imageBase64',
                },
              },
            ],
          },
        ],
        'max_tokens': 2000,
        'temperature': 0.2,
        'response_format': {'type': 'json_object'},
      };

      final stopwatch = Stopwatch()..start();

      // Make request to OpenRouter
      final response = await makeRequestWithRetry(
        '/chat/completions',
        requestData,
      );

      stopwatch.stop();

      // Parse response
      final content = response['choices']?[0]?['message']?['content'] as String?;
      if (content == null) {
        throw Exception('No content in OpenRouter response');
      }

      // Parse JSON response
      final analysisData = jsonDecode(content);

      // Add usage information
      final usage = response['usage'] as Map<String, dynamic>?;

      // Convert to PlantAnalysisResult
      final result = _parseAnalysisResponse(
        analysisData,
        strain,
        stopwatch.elapsed,
        usage,
      );

      logEvent('Analysis completed', {
        'confidence': result.confidenceScore,
        'severity': result.severity,
        'processing_time': result.processingTime.inMilliseconds,
        'tokens_used': usage?['total_tokens'],
      });

      return result;
    } catch (e) {
      logEvent('Analysis failed', {'error': e.toString()});
      throw Exception('OpenRouter analysis failed: $e');
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
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://cannai.app',
            'X-Title': 'CannaAI Plant Analysis',
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
      throw Exception('OpenRouter API error: ${e.type} - ${e.message}');
    }
  }

  String _detectMimeType(Uint8List imageData) {
    // Simple MIME type detection based on file signature
    if (imageData.length >= 4) {
      final header = imageData.sublist(0, 4);
      if (header[0] == 0xFF && header[1] == 0xD8) {
        return 'image/jpeg';
      } else if (header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) {
        return 'image/png';
      }
    }
    return 'image/jpeg'; // Default fallback
  }

  String _createAnalysisPrompt({
    required String strain,
    Map<String, dynamic>? environmentalData,
    required PlantAnalysisOptions options,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('Please perform a comprehensive analysis of this cannabis plant:');
    buffer.writeln();
    buffer.writeln('**Plant Information:**');
    buffer.writeln('- Strain: $strain');

    if (environmentalData != null) {
      buffer.writeln('\n**Environmental Conditions:**');
      environmentalData.forEach((key, value) {
        buffer.writeln('- $key: $value');
      });
    }

    buffer.writeln('\n**Analysis Requirements:**');
    buffer.writeln('1. Visual examination of leaf color, spots, damage, and overall health');
    buffer.writeln('2. Identification of nutrient deficiencies, pests, or diseases');
    buffer.writeln('3. Assessment of growth stage and development');
    buffer.writeln('4. Evaluation of environmental stress factors');
    buffer.writeln('5. Specific focus on distinguishing purple strains from phosphorus deficiency');
    buffer.writeln('6. Confidence scoring for all assessments');

    if (options.useAdvancedDetection) {
      buffer.writeln('\n**Advanced Analysis Mode:**');
      buffer.writeln('- Use enhanced detection for subtle symptoms');
      buffer.writeln('- Consider early-stage issues');
      buffer.writeln('- Provide detailed metrics and scores');
    }

    buffer.writeln('\nPlease provide the analysis in the specified JSON format with detailed reasoning.');

    return buffer.toString();
  }

  PlantAnalysisResult _parseAnalysisResponse(
    Map<String, dynamic> data,
    String strain,
    Duration processingTime,
    Map<String, dynamic>? usage,
  ) {
    // Parse detailed analysis if available
    final detailedAnalysis = data['detailed_analysis'] as Map<String, dynamic>?;

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
        growthRateScore: (data['growth_rate_score'] as num?)?.toDouble(),
        pestDamageScore: (data['pest_damage_score'] as num?)?.toDouble(),
        nutrientDeficiencyScore: (data['nutrient_deficiency_score'] as num?)?.toDouble(),
        diseaseScore: (data['disease_score'] as num?)?.toDouble(),
        overallVigorScore: (data['overall_vigor_score'] as num?)?.toDouble(),
        customMetrics: detailedAnalysis != null ? {
          'leaf_condition_score': _calculateConditionScore(detailedAnalysis['leaf_condition']),
          'color_analysis_score': _calculateConditionScore(detailedAnalysis['color_analysis']),
          'structural_score': _calculateConditionScore(detailedAnalysis['structural_assessment']),
        } : null,
      ),
      analysisTimestamp: DateTime.now(),
      analysisType: 'openrouter_ai',
      processingTime: processingTime,
      provider: '${getProviderName()} ($_currentModel)',
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

  double? _calculateConditionScore(String? condition) {
    if (condition == null) return null;

    // Simple scoring based on keywords
    if (condition.toLowerCase().contains('excellent') || condition.toLowerCase().contains('healthy')) {
      return 0.9;
    } else if (condition.toLowerCase().contains('good') || condition.toLowerCase().contains('minor')) {
      return 0.7;
    } else if (condition.toLowerCase().contains('moderate') || condition.toLowerCase().contains('some')) {
      return 0.5;
    } else if (condition.toLowerCase().contains('poor') || condition.toLowerCase().contains('significant')) {
      return 0.3;
    } else if (condition.toLowerCase().contains('severe') || condition.toLowerCase().contains('critical')) {
      return 0.1;
    }

    return 0.5; // Default neutral score
  }

  Future<void> _selectBestModel(List<dynamic> availableModels) async {
    // Find the best available model from our recommended list
    for (final recommendedModel in _recommendedModels) {
      for (final model in availableModels) {
        final modelId = model['id'] as String?;
        if (modelId == recommendedModel) {
          _currentModel = modelId;
          _modelInfo = model as Map<String, dynamic>;
          logEvent('Selected model', {'model': modelId});
          return;
        }
      }
    }

    // Fallback to any available vision-capable model
    for (final model in availableModels) {
      final capabilities = model['capabilities'] as Map<String, dynamic>?;
      if (capabilities?['vision'] == true || (model['id'] as String?).contains('vision')) {
        _currentModel = model['id'] as String?;
        _modelInfo = model as Map<String, dynamic>;
        logEvent('Selected fallback vision model', {'model': _currentModel});
        return;
      }
    }

    // Last resort - use first available model
    if (availableModels.isNotEmpty) {
      _currentModel = availableModels.first['id'] as String?;
      _modelInfo = availableModels.first as Map<String, dynamic>;
      logEvent('Selected fallback model', {'model': _currentModel});
    }
  }

  Future<void> _updateCapabilities() async {
    final isVisionModel = _currentModel?.contains('vision') == true ||
                         _modelInfo?['capabilities']?['vision'] == true;

    _capabilities = ProviderCapabilities(
      supportsImageAnalysis: isVisionModel,
      supportsBatchAnalysis: true,
      supportsRealTimeAnalysis: true,
      supportsDetailedMetrics: true,
      supportsConfidenceScoring: true,
      supportsStrainDetection: true,
      supportsGrowthStageDetection: true,
      supportsPurpleStrainDetection: true,
      supportsEnvironmentalContext: true,
      maxImageSize: 20 * 1024 * 1024, // 20MB
      maxBatchSize: isVisionModel ? 3 : 5, // Smaller batches for vision models
      averageProcessingTime: isVisionModel ? Duration(seconds: 12) : Duration(seconds: 5),
      requiresInternet: true,
      reliabilityScore: _isConnected ? 0.95 : 0.0,
    );
  }

  /// Get available models
  Future<List<Map<String, dynamic>>> getAvailableModels() async {
    try {
      final response = await _dio.get(
        '${baseUrl}/models',
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      if (response.statusCode == 200) {
        final models = response.data['data'] as List?;
        return models?.cast<Map<String, dynamic>>() ?? [];
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
      final modelExists = models.any((m) => m['id'] == modelId);

      if (modelExists) {
        _currentModel = modelId;
        _modelInfo = models.firstWhere((m) => m['id'] == modelId);
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
    if (_currentModel == null) return null;

    return {
      'id': _currentModel,
      'info': _modelInfo,
      'connected': _isConnected,
      'provider': getProviderName(),
    };
  }

  /// Get usage statistics
  Map<String, dynamic> getUsageStats() {
    return {
      'provider': getProviderName(),
      'model': _currentModel,
      'connected': _isConnected,
      'requires_api_key': true,
      'supports_vision': _capabilities?.supportsImageAnalysis ?? false,
    };
  }

  @override
  Future<void> dispose() async {
    _dio.close();
    _isConnected = false;
    _currentModel = null;
    _modelInfo = null;
    logEvent('Provider disposed', {});
  }
}