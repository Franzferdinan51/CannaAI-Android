import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:logger/logger.dart';
import 'package:image/image.dart' as img;
import 'base_ai_provider.dart';
import '../enhanced_ai_service.dart';

/// Offline rule-based AI provider for when no internet or ML models are available
class OfflineRuleProvider extends OfflineAIProvider {
  bool _isInitialized = false;
  final Map<String, SymptomRule> _symptomRules = {};
  final Map<String, StrainProfile> _strainProfiles = {};
  ProviderCapabilities? _capabilities;

  OfflineRuleProvider() {
    _initializeRules();
    _initializeStrainProfiles();
  }

  @override
  String getProviderName() => 'Offline Rules';

  @override
  AIProviderType getProviderType() => AIProviderType.offlineRules;

  @override
  Future<bool> testConnection() async {
    // Offline provider is always available
    if (!_isInitialized) {
      await initialize();
    }
    return true;
  }

  @override
  ProviderCapabilities getCapabilities() {
    return _capabilities ?? ProviderCapabilities(
      supportsImageAnalysis: true,
      supportsBatchAnalysis: true,
      supportsRealTimeAnalysis: true,
      supportsDetailedMetrics: false, // Limited in rule-based
      supportsConfidenceScoring: true,
      supportsStrainDetection: true,
      supportsGrowthStageDetection: true,
      supportsPurpleStrainDetection: true,
      supportsEnvironmentalContext: true,
      maxImageSize: 5 * 1024 * 1024, // 5MB
      maxBatchSize: 10,
      averageProcessingTime: Duration(milliseconds: 200),
      requiresInternet: false,
      reliabilityScore: 0.65, // Lower reliability than AI models
    );
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      logEvent('Initializing Offline Rule provider', {});

      // Load rules and profiles
      await _loadSymptomRules();
      await _loadStrainProfiles();

      _isInitialized = true;
      logEvent('Offline Rule provider initialized', {
        'symptom_rules': _symptomRules.length,
        'strain_profiles': _strainProfiles.length,
      });
    } catch (e) {
      logEvent('Initialization failed', {'error': e.toString()});
      rethrow;
    }
  }

  @override
  Future<PlantAnalysisResult> analyzePlant({
    required Uint8List imageData,
    required String strain,
    Map<String, dynamic>? environmentalData,
    required PlantAnalysisOptions options,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      logEvent('Starting offline rule-based analysis', {
        'strain': strain,
        'has_environmental_data': environmentalData != null,
      });

      final stopwatch = Stopwatch()..start();

      // Perform rule-based image analysis
      final imageAnalysis = await _analyzeImageWithRules(imageData);

      // Analyze environmental data with rules
      final environmentalAnalysis = _analyzeEnvironmentalWithRules(environmentalData);

      // Apply strain-specific rules
      final strainAnalysis = _applyStrainSpecificRules(strain, imageAnalysis, environmentalAnalysis);

      // Combine all analyses
      final combinedResult = _combineAnalyses(
        imageAnalysis: imageAnalysis,
        environmentalAnalysis: environmentalAnalysis,
        strainAnalysis: strainAnalysis,
        strain: strain,
      );

      stopwatch.stop();

      final plantAnalysisResult = PlantAnalysisResult(
        strainDetected: strain,
        symptoms: combinedResult['symptoms'],
        severity: combinedResult['severity'],
        confidenceScore: combinedResult['confidence_score'],
        detectedIssues: combinedResult['detected_issues'],
        deficiencies: combinedResult['deficiencies'],
        diseases: combinedResult['diseases'],
        pests: combinedResult['pests'],
        environmentalIssues: combinedResult['environmental_issues'],
        recommendations: combinedResult['recommendations'],
        actionableSteps: combinedResult['actionable_steps'],
        estimatedRecoveryTime: combinedResult['estimated_recovery_time'],
        preventionTips: combinedResult['prevention_tips'],
        growthStage: combinedResult['growth_stage'],
        isPurpleStrain: combinedResult['is_purple_strain'],
        metrics: PlantMetrics(
          leafColorScore: combinedResult['leaf_color_score'],
          leafHealthScore: combinedResult['leaf_health_score'],
          growthRateScore: combinedResult['growth_rate_score'],
          pestDamageScore: combinedResult['pest_damage_score'],
          nutrientDeficiencyScore: combinedResult['nutrient_deficiency_score'],
          diseaseScore: combinedResult['disease_score'],
          overallVigorScore: combinedResult['overall_vigor_score'],
        ),
        analysisTimestamp: DateTime.now(),
        analysisType: 'offline_rules',
        processingTime: stopwatch.elapsed,
        provider: getProviderName(),
      );

      logEvent('Offline analysis completed', {
        'confidence': plantAnalysisResult.confidenceScore,
        'symptoms_found': plantAnalysisResult.symptoms.length,
        'processing_time': plantAnalysisResult.processingTime.inMilliseconds,
      });

      return plantAnalysisResult;
    } catch (e) {
      logEvent('Analysis failed', {'error': e.toString()});
      throw Exception('Offline rule analysis failed: $e');
    }
  }

  void _initializeRules() {
    // Nutrient deficiency rules
    _symptomRules['nitrogen_deficiency'] = SymptomRule(
      id: 'nitrogen_deficiency',
      name: 'Nitrogen Deficiency',
      triggers: [
        ColorTrigger(colorRange: ColorRange.yellow, threshold: 0.4),
        PatternTrigger(pattern: 'uniform_yellowing'),
      ],
      confidence: 0.75,
      recommendations: [
        'Increase nitrogen in nutrient solution',
        'Check pH levels (6.0-6.5)',
        'Use nitrogen-rich fertilizer',
      ],
      severity: AnalysisSeverity.moderate,
    );

    _symptomRules['phosphorus_deficiency'] = SymptomRule(
      id: 'phosphorus_deficiency',
      name: 'Phosphorus Deficiency',
      triggers: [
        ColorTrigger(colorRange: ColorRange.purple, threshold: 0.3),
        PatternTrigger(pattern: 'purple_stems'),
      ],
      confidence: 0.70,
      recommendations: [
        'Add phosphorus-rich nutrients',
        'Check temperature (cold stress can cause uptake issues)',
        'Ensure pH is between 6.0-7.0',
      ],
      severity: AnalysisSeverity.moderate,
    );

    _symptomRules['potassium_deficiency'] = SymptomRule(
      id: 'potassium_deficiency',
      name: 'Potassium Deficiency',
      triggers: [
        ColorTrigger(colorRange: ColorRange.brown, threshold: 0.3),
        PatternTrigger(pattern: 'brown_edges'),
      ],
      confidence: 0.72,
      recommendations: [
        'Increase potassium levels',
        'Check for nutrient lockout',
        'Use bloom-specific nutrients if flowering',
      ],
      severity: AnalysisSeverity.moderate,
    );

    // Disease rules
    _symptomRules['powdery_mildew'] = SymptomRule(
      id: 'powdery_mildew',
      name: 'Powdery Mildew',
      triggers: [
        ColorTrigger(colorRange: ColorRange.white, threshold: 0.3),
        PatternTrigger(pattern: 'powdery_patches'),
      ],
      confidence: 0.80,
      recommendations: [
        'Increase air circulation immediately',
        'Reduce humidity to 40-50%',
        'Remove affected leaves',
        'Apply organic fungicide if severe',
      ],
      severity: AnalysisSeverity.severe,
    );

    // Pest rules
    _symptomRules['spider_mites'] = SymptomRule(
      id: 'spider_mites',
      name: 'Spider Mites',
      triggers: [
        PatternTrigger(pattern: 'yellow_spots'),
        PatternTrigger(pattern: 'webbing'),
      ],
      confidence: 0.68,
      recommendations: [
        'Isolate affected plants',
        'Increase humidity slightly (spider mites hate humidity)',
        'Apply neem oil or insecticidal soap',
        'Introduce predatory insects if available',
      ],
      severity: AnalysisSeverity.severe,
    );

    // Environmental stress rules
    _symptomRules['heat_stress'] = SymptomRule(
      id: 'heat_stress',
      name: 'Heat Stress',
      triggers: [
        PatternTrigger(pattern: 'curling_leaves'),
        ColorTrigger(colorRange: ColorRange.yellow, threshold: 0.2),
      ],
      confidence: 0.65,
      recommendations: [
        'Reduce temperature by 3-5°C',
        'Increase air circulation',
        'Check for adequate ventilation',
        'Consider adding shade cloth',
      ],
      severity: AnalysisSeverity.moderate,
    );

    _symptomRules['nutrient_burn'] = SymptomRule(
      id: 'nutrient_burn',
      name: 'Nutrient Burn',
      triggers: [
        ColorTrigger(colorRange: ColorRange.brown, threshold: 0.4),
        PatternTrigger(pattern: 'burnt_tips'),
      ],
      confidence: 0.85,
      recommendations: [
        'Flush growing medium with pH-balanced water',
        'Reduce nutrient concentration by 25-30%',
        'Check EC levels',
        'Skip next feeding',
      ],
      severity: AnalysisSeverity.severe,
    );
  }

  void _initializeStrainProfiles() {
    _strainProfiles['purple_haze'] = StrainProfile(
      name: 'Purple Haze',
      type: 'Sativa',
      characteristics: ['purple_coloration', 'long_flowering'],
      idealConditions: {
        'temperature': {'min': 19, 'max': 27},
        'humidity': {'min': 50, 'max': 70},
        'ph': {'min': 6.0, 'max': 7.0},
      },
      commonIssues: ['nutrient_sensitivity', 'long_flowering_period'],
      isPurpleStrain: true,
    );

    _strainProfiles['granddaddy_purple'] = StrainProfile(
      name: 'Granddaddy Purple',
      type: 'Indica',
      characteristics: ['purple_coloration', 'dense_buds'],
      idealConditions: {
        'temperature': {'min': 18, 'max': 26},
        'humidity': {'min': 40, 'max': 60},
        'ph': {'min': 6.2, 'max': 7.0},
      },
      commonIssues: ['mold_susceptibility', 'slow_growth'],
      isPurpleStrain: true,
    );

    _strainProfiles['blue_dream'] = StrainProfile(
      name: 'Blue Dream',
      type: 'Hybrid',
      characteristics: ['balanced_growth', 'moderate_flowering'],
      idealConditions: {
        'temperature': {'min': 20, 'max': 28},
        'humidity': {'min': 45, 'max': 65},
        'ph': {'min': 6.0, 'max': 6.8},
      },
      commonIssues: ['nutrient_burn_sensitivity'],
      isPurpleStrain: false,
    );
  }

  Future<void> _loadSymptomRules() async {
    // Simulate loading rules from storage
    await Future.delayed(Duration(milliseconds: 50));
  }

  Future<void> _loadStrainProfiles() async {
    // Simulate loading strain profiles from storage
    await Future.delayed(Duration(milliseconds: 30));
  }

  Future<Map<String, dynamic>> _analyzeImageWithRules(Uint8List imageData) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Analyze color distribution
      final colorAnalysis = _analyzeColorDistribution(image);

      // Detect patterns
      final patternAnalysis = _detectPatterns(image);

      // Apply symptom rules
      final matchedSymptoms = <String, dynamic>{};

      for (final rule in _symptomRules.values) {
        final matchScore = _evaluateRule(rule, colorAnalysis, patternAnalysis);
        if (matchScore > 0.5) {
          matchedSymptoms[rule.id] = {
            'rule': rule,
            'confidence': matchScore,
            'triggers_matched': rule.triggers.map((t) => t.description).toList(),
          };
        }
      }

      return {
        'color_analysis': colorAnalysis,
        'pattern_analysis': patternAnalysis,
        'matched_symptoms': matchedSymptoms,
        'overall_confidence': _calculateOverallConfidence(matchedSymptoms),
      };
    } catch (e) {
      logEvent('Image analysis failed', {'error': e.toString()});
      return _getFallbackImageAnalysis();
    }
  }

  Map<String, dynamic> _analyzeColorDistribution(img.Image image) {
    final random = Random();
    final sampleSize = min(500, image.width * image.height ~/ 20);

    final colorCounts = <String, int>{
      'green': 0,
      'yellow': 0,
      'brown': 0,
      'white': 0,
      'purple': 0,
      'red': 0,
    };

    // Sample pixels
    for (int i = 0; i < sampleSize; i++) {
      final x = random.nextInt(image.width);
      final y = random.nextInt(image.height);
      final pixel = image.getPixel(x, y);

      final dominantColor = _classifyPixelColor(pixel);
      colorCounts[dominantColor] = (colorCounts[dominantColor] ?? 0) + 1;
    }

    // Calculate color ratios
    final totalSamples = sampleSize;
    final colorRatios = <String, double>{};
    colorCounts.forEach((color, count) {
      colorRatios[color] = count / totalSamples;
    });

    return {
      'color_ratios': colorRatios,
      'dominant_color': colorRatios.entries.reduce((a, b) => a.value > b.value ? a : b).key,
      'color_diversity': _calculateColorDiversity(colorRatios),
    };
  }

  String _classifyPixelColor(img.Pixel pixel) {
    final r = pixel.r;
    final g = pixel.g;
    final b = pixel.b;

    // Simple color classification
    if (g > r && g > b && g > 100) {
      return 'green';
    } else if (r > g && r > b && r > g * 1.5) {
      return 'red';
    } else if (r > 150 && g > 100 && b < 100) {
      return 'yellow';
    } else if (r > 100 && b > 100 && g < 100) {
      return 'purple';
    } else if (r < 80 && g < 80 && b < 80) {
      return 'brown';
    } else if (r > 200 && g > 200 && b > 200) {
      return 'white';
    }

    return 'other';
  }

  Map<String, dynamic> _detectPatterns(img.Image image) {
    final patterns = <String, bool>{};

    // Simple pattern detection
    patterns['uniform_yellowing'] = _detectUniformYellowing(image);
    patterns['purple_stems'] = _detectPurpleStems(image);
    patterns['brown_edges'] = _detectBrownEdges(image);
    patterns['powdery_patches'] = _detectPowderyPatches(image);
    patterns['yellow_spots'] = _detectYellowSpots(image);
    patterns['webbing'] = _detectWebbing(image);
    patterns['curling_leaves'] = _detectCurlingLeaves(image);
    patterns['burnt_tips'] = _detectBurntTips(image);

    return patterns;
  }

  bool _detectUniformYellowing(img.Image image) {
    final colorAnalysis = _analyzeColorDistribution(image);
    final yellowRatio = colorAnalysis['color_ratios']['yellow'] as double? ?? 0.0;
    final greenRatio = colorAnalysis['color_ratios']['green'] as double? ?? 0.0;

    return yellowRatio > 0.3 && greenRatio < 0.4;
  }

  bool _detectPurpleStems(img.Image image) {
    // Simplified purple stem detection
    final random = Random();
    int purplePixels = 0;
    int edgePixels = 0;

    // Check edges for purple color
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        // Check if pixel is on edge (simplified)
        final isEdge = x < 50 || x > image.width - 50 || y < 50 || y > image.height - 50;
        if (isEdge) {
          edgePixels++;
          final pixel = image.getPixel(x, y);
          if (pixel.r > 100 && pixel.b > 100 && pixel.g < 100) {
            purplePixels++;
          }
        }
      }
    }

    return edgePixels > 0 && (purplePixels / edgePixels) > 0.2;
  }

  bool _detectBrownEdges(img.Image image) {
    final random = Random();
    int brownEdgePixels = 0;
    int edgePixels = 0;

    for (int y = 0; y < image.height; y += 5) {
      for (int x = 0; x < image.width; x += 5) {
        final isEdge = x < 20 || x > image.width - 20 || y < 20 || y > image.height - 20;
        if (isEdge) {
          edgePixels++;
          final pixel = image.getPixel(x, y);
          if (pixel.r < 150 && pixel.g < 120 && pixel.b < 100) {
            brownEdgePixels++;
          }
        }
      }
    }

    return edgePixels > 0 && (brownEdgePixels / edgePixels) > 0.15;
  }

  bool _detectPowderyPatches(img.Image image) {
    // Simplified powdery mildew detection
    final colorAnalysis = _analyzeColorDistribution(image);
    final whiteRatio = colorAnalysis['color_ratios']['white'] as double? ?? 0.0;

    return whiteRatio > 0.2;
  }

  bool _detectYellowSpots(img.Image image) {
    // Simplified yellow spot detection
    final random = Random();
    int yellowSpots = 0;
    int totalSamples = 0;

    for (int y = 10; y < image.height - 10; y += 15) {
      for (int x = 10; x < image.width - 10; x += 15) {
        totalSamples++;
        final pixel = image.getPixel(x, y);

        // Check for yellow spots (isolated yellow pixels)
        if (pixel.r > 150 && pixel.g > 150 && pixel.b < 100) {
          // Check if surrounded by green
          bool surroundedByGreen = false;
          for (int dy = -5; dy <= 5; dy += 5) {
            for (int dx = -5; dx <= 5; dx += 5) {
              if (dx == 0 && dy == 0) continue;
              final nx = x + dx;
              final ny = y + dy;
              if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
                final neighbor = image.getPixel(nx, ny);
                if (neighbor.g > neighbor.r && neighbor.g > neighbor.b) {
                  surroundedByGreen = true;
                  break;
                }
              }
            }
            if (surroundedByGreen) break;
          }

          if (surroundedByGreen) yellowSpots++;
        }
      }
    }

    return totalSamples > 0 && (yellowSpots / totalSamples) > 0.1;
  }

  bool _detectWebbing(img.Image image) {
    // Very simplified webbing detection (would be more complex in reality)
    final random = Random();
    int whiteLines = 0;

    // Look for thin white lines
    for (int y = 0; y < image.height - 10; y += 20) {
      for (int x = 0; x < image.width - 10; x += 20) {
        int whitePixels = 0;
        for (int dy = 0; dy < 10; dy++) {
          for (int dx = 0; dx < 10; dx++) {
            final pixel = image.getPixel(x + dx, y + dy);
            if (pixel.r > 200 && pixel.g > 200 && pixel.b > 200) {
              whitePixels++;
            }
          }
        }

        // If we have some white pixels but not a solid white area
        if (whitePixels > 2 && whitePixels < 50) {
          whiteLines++;
        }
      }
    }

    return whiteLines > 5;
  }

  bool _detectCurlingLeaves(img.Image image) {
    // Simplified curling detection - would need edge detection in reality
    return false; // Placeholder
  }

  bool _detectBurntTips(img.Image image) {
    // Check bottom edges for brown/black color
    final random = Random();
    int burntPixels = 0;
    int tipPixels = 0;

    for (int y = image.height - 30; y < image.height; y += 5) {
      for (int x = 0; x < image.width; x += 5) {
        tipPixels++;
        final pixel = image.getPixel(x, y);
        if (pixel.r < 100 && pixel.g < 80 && pixel.b < 60) {
          burntPixels++;
        }
      }
    }

    return tipPixels > 0 && (burntPixels / tipPixels) > 0.3;
  }

  double _evaluateRule(SymptomRule rule, Map<String, dynamic> colorAnalysis, Map<String, dynamic> patternAnalysis) {
    double totalScore = 0.0;
    int matchedTriggers = 0;

    for (final trigger in rule.triggers) {
      double triggerScore = 0.0;

      if (trigger is ColorTrigger) {
        final colorRatios = colorAnalysis['color_ratios'] as Map<String, double>;
        final threshold = trigger.threshold;

        switch (trigger.colorRange) {
          case ColorRange.yellow:
            triggerScore = (colorRatios['yellow'] ?? 0.0) >= threshold ? 1.0 : 0.0;
            break;
          case ColorRange.purple:
            triggerScore = (colorRatios['purple'] ?? 0.0) >= threshold ? 1.0 : 0.0;
            break;
          case ColorRange.brown:
            triggerScore = (colorRatios['brown'] ?? 0.0) >= threshold ? 1.0 : 0.0;
            break;
          case ColorRange.white:
            triggerScore = (colorRatios['white'] ?? 0.0) >= threshold ? 1.0 : 0.0;
            break;
        }
      } else if (trigger is PatternTrigger) {
        final patterns = patternAnalysis as Map<String, bool>;
        triggerScore = (patterns[trigger.pattern] ?? false) ? 1.0 : 0.0;
      }

      if (triggerScore > 0.5) {
        matchedTriggers++;
      }
      totalScore += triggerScore;
    }

    // Rule matches if enough triggers are activated
    final activationRatio = matchedTriggers / rule.triggers.length;
    if (activationRatio >= 0.5) {
      return (totalScore / rule.triggers.length) * rule.confidence;
    }

    return 0.0;
  }

  Map<String, dynamic> _analyzeEnvironmentalWithRules(Map<String, dynamic>? environmentalData) {
    if (environmentalData == null || environmentalData.isEmpty) {
      return {
        'issues': ['No environmental data available'],
        'overall_score': 0.5,
      };
    }

    final List<String> issues = [];
    double score = 1.0;

    // Temperature rules
    if (environmentalData.containsKey('temperature')) {
      final temp = environmentalData['temperature'] as double? ?? 0.0;
      if (temp < 18.0) {
        issues.add('Temperature too low (${temp.toStringAsFixed(1)}°C)');
        score -= 0.2;
      } else if (temp > 30.0) {
        issues.add('Temperature too high (${temp.toStringAsFixed(1)}°C)');
        score -= 0.2;
      }
    }

    // Humidity rules
    if (environmentalData.containsKey('humidity')) {
      final humidity = environmentalData['humidity'] as double? ?? 0.0;
      if (humidity < 40.0) {
        issues.add('Humidity too low (${humidity.toStringAsFixed(1)}%)');
        score -= 0.15;
      } else if (humidity > 70.0) {
        issues.add('Humidity too high (${humidity.toStringAsFixed(1)}%)');
        score -= 0.15;
      }
    }

    // pH rules
    if (environmentalData.containsKey('ph')) {
      final ph = environmentalData['ph'] as double? ?? 0.0;
      if (ph < 6.0) {
        issues.add('pH too low (${ph.toStringAsFixed(1)})');
        score -= 0.2;
      } else if (ph > 7.0) {
        issues.add('pH too high (${ph.toStringAsFixed(1)})');
        score -= 0.2;
      }
    }

    return {
      'issues': issues.isEmpty ? ['Environmental conditions optimal'] : issues,
      'overall_score': score.clamp(0.0, 1.0),
    };
  }

  Map<String, dynamic> _applyStrainSpecificRules(String strain, Map<String, dynamic> imageAnalysis, Map<String, dynamic> environmentalAnalysis) {
    final strainKey = strain.toLowerCase().replaceAll(' ', '_');
    final profile = _strainProfiles[strainKey];

    if (profile == null) {
      return {
        'is_purple_strain': strain.toLowerCase().contains('purple'),
        'strain_specific_issues': [],
        'adjusted_confidence': 0.7,
      };
    }

    final List<String> strainIssues = [];
    double adjustedConfidence = imageAnalysis['overall_confidence'] as double? ?? 0.7;

    // Adjust confidence based on strain characteristics
    if (profile.isPurpleStrain) {
      // Purple strains naturally have purple coloration
      final matchedSymptoms = imageAnalysis['matched_symptoms'] as Map<String, dynamic>;
      if (matchedSymptoms.containsKey('phosphorus_deficiency')) {
        // Reduce confidence for phosphorus deficiency in purple strains
        adjustedConfidence *= 0.8;
        strainIssues.add('Purple strain - discoloration may be natural');
      }
    }

    // Check against ideal conditions
    if (environmentalAnalysis['overall_score'] < 0.8) {
      final issues = environmentalAnalysis['issues'] as List<String>;
      for (final issue in issues) {
        if (issue.contains('temperature') || issue.contains('humidity')) {
          strainIssues.add('Environmental conditions not ideal for $strain');
        }
      }
    }

    return {
      'is_purple_strain': profile.isPurpleStrain,
      'strain_specific_issues': strainIssues,
      'adjusted_confidence': adjustedConfidence,
      'profile': profile,
    };
  }

  Map<String, dynamic> _combineAnalyses({
    required Map<String, dynamic> imageAnalysis,
    required Map<String, dynamic> environmentalAnalysis,
    required Map<String, dynamic> strainAnalysis,
    required String strain,
  }) {
    final List<String> symptoms = [];
    final List<String> detectedIssues = [];
    final List<String> deficiencies = [];
    final List<String> diseases = [];
    final List<String> pests = [];
    final List<String> recommendations = [];
    final List<String> environmentalIssues = environmentalAnalysis['issues'] as List<String>;

    // Process matched symptoms from image analysis
    final matchedSymptoms = imageAnalysis['matched_symptoms'] as Map<String, dynamic>;
    matchedSymptoms.forEach((symptomId, symptomData) {
      final rule = symptomData['rule'] as SymptomRule;
      final confidence = symptomData['confidence'] as double;

      symptoms.add(rule.name);
      detectedIssues.add(rule.name);

      // Categorize the issue
      if (symptomId.contains('deficiency')) {
        deficiencies.add(rule.name);
      } else if (symptomId.contains('mildew') || symptomId.contains('rot')) {
        diseases.add(rule.name);
      } else if (symptomId.contains('mites') || symptomId.contains('pest')) {
        pests.add(rule.name);
      }

      // Add recommendations from the rule
      recommendations.addAll(rule.recommendations);
    });

    // Add environmental issues to detected issues
    detectedIssues.addAll(environmentalIssues);

    // Add strain-specific recommendations
    if (strainAnalysis['strain_specific_issues'].isNotEmpty) {
      recommendations.addAll(strainAnalysis['strain_specific_issues']);
    }

    // Calculate severity
    final severity = _calculateSeverityFromSymptoms(symptoms, environmentalIssues);

    // Calculate confidence
    final baseConfidence = imageAnalysis['overall_confidence'] as double? ?? 0.7;
    final environmentalScore = environmentalAnalysis['overall_score'] as double? ?? 0.5;
    final strainAdjustedConfidence = strainAnalysis['adjusted_confidence'] as double? ?? 0.7;

    final overallConfidence = (baseConfidence + environmentalScore + strainAdjustedConfidence) / 3;

    return {
      'symptoms': symptoms.isEmpty ? ['No obvious symptoms detected'] : symptoms,
      'severity': severity,
      'confidence_score': overallConfidence,
      'detected_issues': detectedIssues,
      'deficiencies': deficiencies,
      'diseases': diseases,
      'pests': pests,
      'environmental_issues': environmentalIssues,
      'recommendations': recommendations,
      'actionable_steps': _generateActionableSteps(symptoms, environmentalIssues),
      'estimated_recovery_time': _estimateRecoveryTime(severity),
      'prevention_tips': _getPreventionTips(symptoms),
      'growth_stage': null, // Cannot determine from rules alone
      'is_purple_strain': strainAnalysis['is_purple_strain'],
      'leaf_color_score': _calculateLeafColorScore(matchedSymptoms),
      'leaf_health_score': overallConfidence,
      'growth_rate_score': 0.7, // Placeholder
      'pest_damage_score': pests.isNotEmpty ? 0.6 : 0.2,
      'nutrient_deficiency_score': deficiencies.isNotEmpty ? 0.7 : 0.3,
      'disease_score': diseases.isNotEmpty ? 0.8 : 0.2,
      'overall_vigor_score': overallConfidence,
    };
  }

  // Helper methods
  double _calculateColorDiversity(Map<String, double> colorRatios) {
    final totalRatio = colorRatios.values.fold(0.0, (sum, ratio) => sum + ratio);
    if (totalRatio == 0) return 0.0;

    final entropy = colorRatios.values.where((r) => r > 0).map((ratio) {
      final p = ratio / totalRatio;
      return -p * log(p) / log(2);
    }).fold(0.0, (sum, e) => sum + e);

    return entropy / log(colorRatios.length) / log(2); // Normalize
  }

  double _calculateOverallConfidence(Map<String, dynamic> matchedSymptoms) {
    if (matchedSymptoms.isEmpty) return 0.3;

    final confidences = matchedSymptoms.values.map((data) => data['confidence'] as double);
    return confidences.reduce((a, b) => a + b) / confidences.length;
  }

  AnalysisSeverity _calculateSeverityFromSymptoms(List<String> symptoms, List<String> environmentalIssues) {
    if (symptoms.isEmpty && environmentalIssues.length <= 1) {
      return AnalysisSeverity.healthy;
    } else if (symptoms.length <= 2 && environmentalIssues.length <= 2) {
      return AnalysisSeverity.mild;
    } else if (symptoms.length <= 4 || environmentalIssues.length <= 3) {
      return AnalysisSeverity.moderate;
    } else {
      return AnalysisSeverity.severe;
    }
  }

  double _calculateLeafColorScore(Map<String, dynamic> matchedSymptoms) {
    if (matchedSymptoms.isEmpty) return 0.8;

    // Base score reduced by symptom severity
    double score = 0.8;
    matchedSymptoms.forEach((symptomId, symptomData) {
      final rule = symptomData['rule'] as SymptomRule;
      final confidence = symptomData['confidence'] as double;

      if (rule.id.contains('yellowing') || rule.id.contains('burn')) {
        score -= confidence * 0.3;
      } else if (rule.id.contains('spot') || rule.id.contains('mildew')) {
        score -= confidence * 0.2;
      }
    });

    return score.clamp(0.0, 1.0);
  }

  List<String> _generateActionableSteps(List<String> symptoms, List<String> environmentalIssues) {
    final List<String> steps = [];

    for (final symptom in symptoms) {
      if (symptom.toLowerCase().contains('deficiency')) {
        steps.add('Check nutrient solution and adjust feeding schedule');
      } else if (symptom.toLowerCase().contains('mildew')) {
        steps.add('Increase air circulation and reduce humidity');
      } else if (symptom.toLowerCase().contains('pest') || symptom.toLowerCase().contains('mite')) {
        steps.add('Isolate plant and apply appropriate treatment');
      }
    }

    for (final issue in environmentalIssues) {
      if (issue.toLowerCase().contains('temperature')) {
        steps.add('Adjust temperature to optimal range (20-28°C)');
      } else if (issue.toLowerCase().contains('humidity')) {
        steps.add('Adjust humidity to optimal range (40-60%)');
      } else if (issue.toLowerCase().contains('ph')) {
        steps.add('Adjust pH to 6.0-6.5 range');
      }
    }

    return steps.isNotEmpty ? steps : ['Continue monitoring plant health'];
  }

  String _estimateRecoveryTime(AnalysisSeverity severity) {
    switch (severity) {
      case AnalysisSeverity.healthy:
        return 'N/A';
      case AnalysisSeverity.mild:
        return '3-7 days';
      case AnalysisSeverity.moderate:
        return '1-2 weeks';
      case AnalysisSeverity.severe:
        return '2-4 weeks';
      default:
        return '1-2 weeks';
    }
  }

  List<String> _getPreventionTips(List<String> symptoms) {
    return [
      'Maintain consistent environmental parameters',
      'Monitor pH and EC levels regularly',
      'Ensure proper air circulation',
      'Inspect plants daily for early signs of issues',
      'Follow proper watering and feeding schedules',
    ];
  }

  Map<String, dynamic> _getFallbackImageAnalysis() {
    return {
      'color_analysis': {},
      'pattern_analysis': {},
      'matched_symptoms': {},
      'overall_confidence': 0.2,
    };
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    logEvent('Provider disposed', {});
  }
}

// Supporting classes for rule-based analysis

class SymptomRule {
  final String id;
  final String name;
  final List<Trigger> triggers;
  final double confidence;
  final List<String> recommendations;
  final AnalysisSeverity severity;

  SymptomRule({
    required this.id,
    required this.name,
    required this.triggers,
    required this.confidence,
    required this.recommendations,
    required this.severity,
  });
}

abstract class Trigger {
  String get description;
}

class ColorTrigger extends Trigger {
  final ColorRange colorRange;
  final double threshold;

  ColorTrigger({required this.colorRange, required this.threshold});

  @override
  String get description => 'Color trigger: $colorRange >= ${(threshold * 100).toInt()}%';
}

class PatternTrigger extends Trigger {
  final String pattern;

  PatternTrigger({required this.pattern});

  @override
  String get description => 'Pattern trigger: $pattern';
}

enum ColorRange {
  yellow,
  purple,
  brown,
  white,
  red,
  green,
}

class StrainProfile {
  final String name;
  final String type;
  final List<String> characteristics;
  final Map<String, Map<String, double>> idealConditions;
  final List<String> commonIssues;
  final bool isPurpleStrain;

  StrainProfile({
    required this.name,
    required this.type,
    required this.characteristics,
    required this.idealConditions,
    required this.commonIssues,
    required this.isPurpleStrain,
  });
}