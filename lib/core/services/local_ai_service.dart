import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';

/// Local AI service for plant health analysis and cultivation advice
/// Replaces external AI services with rule-based algorithms
class LocalAIService {
  static final LocalAIService _instance = LocalAIService._internal();
  factory LocalAIService() => _instance;
  LocalAIService._internal();

  final Logger _logger = Logger();
  final Random _random = Random();

  /// Analyze plant image and provide health recommendations
  Future<Map<String, dynamic>> analyzePlantHealth({
    required Uint8List imageData,
    required String strain,
    Map<String, dynamic>? environmentalData,
  }) async {
    try {
      _logger.i('Starting local plant health analysis for strain: $strain');

      // Process image locally
      final imageAnalysis = await _analyzeImageLocally(imageData);

      // Analyze environmental factors
      final environmentalAnalysis = _analyzeEnvironmentalData(environmentalData);

      // Generate strain-specific recommendations
      final recommendations = _generateRecommendations(
        strain: strain,
        imageAnalysis: imageAnalysis,
        environmentalData: environmentalAnalysis,
      );

      // Calculate confidence score
      final confidenceScore = _calculateConfidenceScore(
        imageAnalysis,
        environmentalAnalysis,
      );

      final result = {
        'strain_detected': strain,
        'symptoms': imageAnalysis['symptoms'],
        'severity': imageAnalysis['severity'],
        'confidence_score': confidenceScore,
        'environmental_issues': environmentalAnalysis['issues'],
        'recommendations': recommendations,
        'actionable_steps': _generateActionableSteps(imageAnalysis, environmentalAnalysis),
        'estimated_recovery_time': _estimateRecoveryTime(imageAnalysis['severity']),
        'prevention_tips': _getPreventionTips(imageAnalysis['symptoms']),
        'analysis_timestamp': DateTime.now().toIso8601String(),
        'analysis_type': 'local_ai',
      };

      _logger.i('Local plant analysis completed with confidence: ${confidenceScore.toStringAsFixed(2)}');
      return result;
    } catch (e) {
      _logger.e('Local plant analysis failed: $e');
      rethrow;
    }
  }

  /// Analyze image locally for plant health indicators
  Future<Map<String, dynamic>> _analyzeImageLocally(Uint8List imageData) async {
    try {
      // Decode image
      final image = img.decodeImage(imageData);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Analyze color distribution
      final colorAnalysis = _analyzeColorDistribution(image);

      // Detect leaf patterns
      final leafPatterns = _detectLeafPatterns(image);

      // Identify potential symptoms
      final symptoms = _identifySymptoms(colorAnalysis, leafPatterns);

      // Assess severity
      final severity = _assessSeverity(symptoms, colorAnalysis);

      return {
        'symptoms': symptoms,
        'severity': severity,
        'color_analysis': colorAnalysis,
        'leaf_patterns': leafPatterns,
        'image_quality': _assessImageQuality(image),
      };
    } catch (e) {
      _logger.e('Image analysis failed: $e');
      // Return fallback analysis
      return _getFallbackImageAnalysis();
    }
  }

  /// Analyze color distribution in the image
  Map<String, dynamic> _analyzeColorDistribution(img.Image image) {
    // Sample pixels for color analysis (performance optimization)
    final sampleSize = min(1000, image.width * image.height ~/ 10);
    final List<int> redValues = [];
    final List<int> greenValues = [];
    final List<int> blueValues = [];

    for (int i = 0; i < sampleSize; i++) {
      final x = _random.nextInt(image.width);
      final y = _random.nextInt(image.height);
      final pixel = image.getPixel(x, y);

      redValues.add(pixel.r.toInt());
      greenValues.add(pixel.g.toInt());
      blueValues.add(pixel.b.toInt());
    }

    // Calculate averages and standard deviations
    final avgRed = redValues.reduce((a, b) => a + b) / redValues.length;
    final avgGreen = greenValues.reduce((a, b) => a + b) / greenValues.length;
    final avgBlue = blueValues.reduce((a, b) => a + b) / blueValues.length;

    // Calculate green ratio (indicator of plant health)
    final totalIntensity = avgRed + avgGreen + avgBlue;
    final greenRatio = avgGreen / totalIntensity;

    // Detect color anomalies
    final redRatio = avgRed / totalIntensity;
    final yellowRatio = (avgRed + avgGreen) / (2 * totalIntensity);

    return {
      'avg_red': avgRed,
      'avg_green': avgGreen,
      'avg_blue': avgBlue,
      'green_ratio': greenRatio,
      'red_ratio': redRatio,
      'yellow_ratio': yellowRatio,
      'brightness': (avgRed + avgGreen + avgBlue) / 3,
      'contrast': _calculateContrast(redValues + greenValues + blueValues),
    };
  }

  /// Detect leaf patterns and textures
  Map<String, dynamic> _detectLeafPatterns(img.Image image) {
    // Simplified pattern detection
    final edgeCount = _countEdges(image);
    final textureScore = _calculateTextureScore(image);
    final spotCount = _detectSpots(image);

    return {
      'edge_density': edgeCount / (image.width * image.height),
      'texture_score': textureScore,
      'spot_count': spotCount,
      'leaf_structure_detected': _detectLeafStructure(image),
    };
  }

  /// Identify symptoms based on image analysis
  List<String> _identifySymptoms(Map<String, dynamic> colorAnalysis, Map<String, dynamic> leafPatterns) {
    final List<String> symptoms = [];

    final greenRatio = colorAnalysis['green_ratio'] as double;
    final redRatio = colorAnalysis['red_ratio'] as double;
    final yellowRatio = colorAnalysis['yellow_ratio'] as double;
    final spotCount = leafPatterns['spot_count'] as int;
    final textureScore = leafPatterns['texture_score'] as double;

    // Yellowing leaves (nitrogen deficiency)
    if (yellowRatio > 0.4 && greenRatio < 0.3) {
      symptoms.add('Yellowing leaves (Nitrogen deficiency)');
    }

    // Red/Purple discoloration
    if (redRatio > 0.3 && greenRatio < 0.3) {
      symptoms.add('Purple/Red discoloration (Phosphorus deficiency or cold stress)');
    }

    // Brown spots (various issues)
    if (spotCount > 10) {
      symptoms.add('Brown spots (Calcium deficiency or mold)');
    }

    // Wilting (low texture score)
    if (textureScore < 0.3) {
      symptoms.add('Wilting (Underwatering or root issues)');
    }

    // Burnt tips (high red ratio, low green)
    if (redRatio > 0.4 && yellowRatio > 0.3) {
      symptoms.add('Burnt tips (Nutrient burn)');
    }

    // White patches (powdery mildew)
    if (colorAnalysis['brightness'] > 200 && spotCount > 5) {
      symptoms.add('White patches (Powdery mildew)');
    }

    // general poor health
    if (greenRatio < 0.2) {
      symptoms.add('Poor overall health');
    }

    return symptoms.isEmpty ? ['No obvious symptoms detected'] : symptoms;
  }

  /// Assess severity of detected symptoms
  String _assessSeverity(List<String> symptoms, Map<String, dynamic> colorAnalysis) {
    final greenRatio = colorAnalysis['green_ratio'] as double;

    if (symptoms.isEmpty && greenRatio > 0.4) {
      return 'Healthy';
    } else if (symptoms.length <= 2 && greenRatio > 0.3) {
      return 'Mild';
    } else if (symptoms.length <= 4 && greenRatio > 0.2) {
      return 'Moderate';
    } else {
      return 'Severe';
    }
  }

  /// Analyze environmental data for issues
  Map<String, dynamic> _analyzeEnvironmentalData(Map<String, dynamic>? environmentalData) {
    if (environmentalData == null || environmentalData.isEmpty) {
      return {
        'issues': ['No environmental data available'],
        'overall_score': 0.5,
      };
    }

    final List<String> issues = [];
    double score = 1.0;

    // Temperature analysis
    if (environmentalData.containsKey('temperature')) {
      final temp = environmentalData['temperature'] as double? ?? 0.0;
      if (temp < AppConstants.defaultTempMin) {
        issues.add('Temperature too low (${temp.toStringAsFixed(1)}°C)');
        score -= 0.2;
      } else if (temp > AppConstants.defaultTempMax) {
        issues.add('Temperature too high (${temp.toStringAsFixed(1)}°C)');
        score -= 0.2;
      }
    }

    // Humidity analysis
    if (environmentalData.containsKey('humidity')) {
      final humidity = environmentalData['humidity'] as double? ?? 0.0;
      if (humidity < AppConstants.defaultHumidityMin) {
        issues.add('Humidity too low (${humidity.toStringAsFixed(1)}%)');
        score -= 0.15;
      } else if (humidity > AppConstants.defaultHumidityMax) {
        issues.add('Humidity too high (${humidity.toStringAsFixed(1)}%)');
        score -= 0.15;
      }
    }

    // pH analysis
    if (environmentalData.containsKey('ph')) {
      final ph = environmentalData['ph'] as double? ?? 0.0;
      if (ph < AppConstants.defaultPhMin) {
        issues.add('pH too low (${ph.toStringAsFixed(1)})');
        score -= 0.2;
      } else if (ph > AppConstants.defaultPhMax) {
        issues.add('pH too high (${ph.toStringAsFixed(1)})');
        score -= 0.2;
      }
    }

    // EC analysis
    if (environmentalData.containsKey('ec')) {
      final ec = environmentalData['ec'] as double? ?? 0.0;
      if (ec < AppConstants.defaultEcMin) {
        issues.add('EC too low - insufficient nutrients (${ec.toStringAsFixed(1)} mS/cm)');
        score -= 0.15;
      } else if (ec > AppConstants.defaultEcMax) {
        issues.add('EC too high - nutrient burn risk (${ec.toStringAsFixed(1)} mS/cm)');
        score -= 0.15;
      }
    }

    // CO2 analysis
    if (environmentalData.containsKey('co2')) {
      final co2 = environmentalData['co2'] as double? ?? 0.0;
      if (co2 < AppConstants.defaultCo2Min) {
        issues.add('CO2 too low (${co2.toStringAsFixed(0)} ppm)');
        score -= 0.1;
      } else if (co2 > AppConstants.defaultCo2Max) {
        issues.add('CO2 too high (${co2.toStringAsFixed(0)} ppm)');
        score -= 0.1;
      }
    }

    return {
      'issues': issues.isEmpty ? ['Environmental conditions optimal'] : issues,
      'overall_score': score.clamp(0.0, 1.0),
    };
  }

  /// Generate strain-specific recommendations
  List<String> _generateRecommendations({
    required String strain,
    required Map<String, dynamic> imageAnalysis,
    required Map<String, dynamic> environmentalData,
  }) {
    final List<String> recommendations = [];
    final symptoms = imageAnalysis['symptoms'] as List<String>;
    final severity = imageAnalysis['severity'] as String;

    // General recommendations based on severity
    switch (severity) {
      case 'Severe':
        recommendations.add('Immediate attention required - consider quarantine');
        recommendations.add('Check all environmental parameters');
        break;
      case 'Moderate':
        recommendations.add('Monitor closely for next 3-5 days');
        break;
      case 'Mild':
        recommendations.add('Continue normal care with increased observation');
        break;
      case 'Healthy':
        recommendations.add('Plant appears healthy - maintain current conditions');
        break;
    }

    // Symptom-specific recommendations
    for (final symptom in symptoms) {
      if (symptom.toLowerCase().contains('yellow')) {
        recommendations.add('Increase nitrogen levels in feeding schedule');
        recommendations.add('Check pH levels and adjust to 6.0-6.5');
      } else if (symptom.toLowerCase().contains('purple')) {
        recommendations.add('Ensure temperature stays above 20°C');
        recommendations.add('Check phosphorus levels in nutrients');
      } else if (symptom.toLowerCase().contains('burnt')) {
        recommendations.add('Reduce nutrient concentration by 25-30%');
        recommendations.add('Flush with pH-balanced water');
      } else if (symptom.toLowerCase().contains('spot')) {
        recommendations.add('Improve air circulation');
        recommendations.add('Reduce humidity levels');
        recommendations.add('Check for calcium deficiency');
      } else if (symptom.toLowerCase().contains('wilting')) {
        recommendations.add('Check watering schedule - adjust frequency');
        recommendations.add('Inspect root system for damage');
      } else if (symptom.toLowerCase().contains('mildew')) {
        recommendations.add('Increase air circulation immediately');
        recommendations.add('Remove affected leaves');
        recommendations.add('Reduce humidity to 40-50%');
        recommendations.add('Consider organic fungicide treatment');
      }
    }

    // Strain-specific recommendations
    recommendations.addAll(_getStrainSpecificRecommendations(strain));

    return recommendations;
  }

  /// Get strain-specific cultivation recommendations
  List<String> _getStrainSpecificRecommendations(String strain) {
    switch (strain.toLowerCase()) {
      case 'blue dream':
        return [
          'Blue Dream thrives in 20-28°C with 45-65% humidity',
          'Requires moderate feeding - avoid over-fertilization',
        ];
      case 'girl scout cookies':
        return [
          'GSC prefers 21-29°C with slightly lower humidity (40-60%)',
          'Requires careful nutrient management',
        ];
      case 'og kush':
        return [
          'OG Kush needs warm temperatures (22-30°C)',
          'Lower humidity (35-55%) helps prevent mold',
        ];
      case 'purple haze':
        return [
          'Purple haze prefers cooler temperatures (19-27°C)',
          'Higher humidity (50-70%) beneficial for growth',
          'Longer flowering period requires patience',
        ];
      case 'northern lights':
        return [
          'Northern lights is forgiving for beginners',
          'Prefers cooler temperatures (18-26°C)',
          'Resistant to mold and pests',
        ];
      default:
        return [
          'Follow general cannabis cultivation guidelines',
          'Adjust conditions based on plant response',
        ];
    }
  }

  /// Calculate confidence score for analysis
  double _calculateConfidenceScore(Map<String, dynamic> imageAnalysis, Map<String, dynamic> environmentalAnalysis) {
    double confidence = 0.7; // Base confidence

    // Image quality impact
    final imageQuality = imageAnalysis['image_quality'] as double? ?? 0.5;
    confidence += (imageQuality - 0.5) * 0.2;

    // Environmental data availability
    final environmentalScore = environmentalAnalysis['overall_score'] as double? ?? 0.5;
    confidence += environmentalScore * 0.1;

    // Symptom clarity
    final symptoms = imageAnalysis['symptoms'] as List<String>;
    if (symptoms.length == 1 && symptoms.first == 'No obvious symptoms detected') {
      confidence -= 0.1; // Lower confidence when no symptoms found
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Generate actionable steps for the user
  List<String> _generateActionableSteps(Map<String, dynamic> imageAnalysis, Map<String, dynamic> environmentalAnalysis) {
    final List<String> steps = [];
    final symptoms = imageAnalysis['symptoms'] as List<String>;
    final environmentalIssues = environmentalAnalysis['issues'] as List<String>;

    // Environmental fixes
    for (final issue in environmentalIssues) {
      if (issue.toLowerCase().contains('temperature')) {
        if (issue.toLowerCase().contains('low')) {
          steps.add('Increase room temperature by 2-3°C');
        } else if (issue.toLowerCase().contains('high')) {
          steps.add('Decrease room temperature or improve ventilation');
        }
      } else if (issue.toLowerCase().contains('humidity')) {
        if (issue.toLowerCase().contains('low')) {
          steps.add('Add humidifier or mist plants');
        } else if (issue.toLowerCase().contains('high')) {
          steps.add('Increase ventilation or add dehumidifier');
        }
      } else if (issue.toLowerCase().contains('ph')) {
        steps.add('Adjust water pH to 6.0-6.5 range');
        steps.add('Flush growing medium with pH-balanced water');
      } else if (issue.toLowerCase().contains('ec')) {
        if (issue.toLowerCase().contains('low')) {
          steps.add('Increase nutrient concentration');
        } else if (issue.toLowerCase().contains('high')) {
          steps.add('Dilute nutrient solution by 25%');
          steps.add('Flush with plain water');
        }
      }
    }

    // Symptom-specific actions
    if (symptoms.any((s) => s.toLowerCase().contains('mildew'))) {
      steps.add('Immediately remove affected leaves');
      steps.add('Increase air circulation with fans');
      steps.add('Space plants further apart');
    }

    if (symptoms.any((s) => s.toLowerCase().contains('spot'))) {
      steps.add('Remove spotted leaves to prevent spread');
      steps.add('Improve air circulation');
    }

    if (symptoms.any((s) => s.toLowerCase().contains('burnt'))) {
      steps.add('Flush growing medium with pH-balanced water');
      steps.add('Reduce nutrient concentration for next feeding');
    }

    return steps.isNotEmpty ? steps : ['Continue current cultivation practices'];
  }

  /// Estimate recovery time based on severity
  String _estimateRecoveryTime(String severity) {
    switch (severity) {
      case 'Mild':
        return '3-7 days';
      case 'Moderate':
        return '1-2 weeks';
      case 'Severe':
        return '2-4 weeks';
      case 'Healthy':
        return 'N/A - Plant is healthy';
      default:
        return '1-2 weeks';
    }
  }

  /// Get prevention tips based on symptoms
  List<String> _getPreventionTips(List<String> symptoms) {
    final List<String> tips = [
      'Maintain consistent environmental parameters',
      'Monitor pH and EC levels regularly',
      'Ensure proper air circulation',
      'Water on a consistent schedule',
      'Inspect plants daily for early signs of issues',
    ];

    if (symptoms.any((s) => s.toLowerCase().contains('mold') || s.toLowerCase().contains('mildew'))) {
      tips.add('Keep humidity between 40-50% during flowering');
      tips.add('Prune lower leaves to improve airflow');
    }

    if (symptoms.any((s) => s.toLowerCase().contains('burnt'))) {
      tips.add('Always check nutrient strength before feeding');
      tips.add('Start with 50% recommended nutrient strength');
    }

    return tips;
  }

  /// Generate AI chat response for cultivation questions
  Future<String> generateCultivationAdvice({
    required String userMessage,
    String? currentStrain,
    Map<String, dynamic>? environmentalContext,
  }) async {
    try {
      _logger.i('Generating local cultivation advice for: ${userMessage.substring(0, 50)}...');

      // Simple keyword-based response generation
      final lowerMessage = userMessage.toLowerCase();

      // Watering advice
      if (lowerMessage.contains('water') || lowerMessage.contains('watering')) {
        return _generateWateringAdvice(currentStrain, environmentalContext);
      }

      // Nutrient advice
      if (lowerMessage.contains('nutrient') || lowerMessage.contains('feed') || lowerMessage.contains('fertilize')) {
        return _generateNutrientAdvice(currentStrain, environmentalContext);
      }

      // Lighting advice
      if (lowerMessage.contains('light') || lowerMessage.contains('lamp') || lowerMessage.contains('led')) {
        return _generateLightingAdvice();
      }

      // Temperature advice
      if (lowerMessage.contains('temperature') || lowerMessage.contains('temp') || lowerMessage.contains('hot') || lowerMessage.contains('cold')) {
        return _generateTemperatureAdvice(environmentalContext);
      }

      // Harvest advice
      if (lowerMessage.contains('harvest') || lowerMessage.contains('ready') || lowerMessage.contains('flowering')) {
        return _generateHarvestAdvice(currentStrain);
      }

      // Pest/disease advice
      if (lowerMessage.contains('pest') || lowerMessage.contains('bug') || lowerMessage.contains('disease') || lowerMessage.contains('mold')) {
        return _generatePestDiseaseAdvice();
      }

      // General advice fallback
      return _generateGeneralAdvice(currentStrain);
    } catch (e) {
      _logger.e('Failed to generate cultivation advice: $e');
      return 'I apologize, but I encountered an error processing your question. Please try rephrasing your cultivation question.';
    }
  }

  // Helper methods for generating specific advice
  String _generateWateringAdvice(String? strain, Map<String, dynamic>? context) {
    final baseAdvice = '''
Watering Guidelines:
• Water when top 1-2 inches of soil are dry
• Check soil moisture with finger or moisture meter
• Ensure good drainage to prevent root rot
• Water thoroughly until runoff occurs
• Adjust frequency based on environmental conditions
''';

    if (context != null && context.containsKey('humidity')) {
      final humidity = context['humidity'] as double? ?? 0.0;
      if (humidity > 70) {
        return '$baseAdvice\n\n⚠️ High humidity detected - reduce watering frequency and improve airflow.';
      } else if (humidity < 40) {
        return '$baseAdvice\n\n💡 Low humidity detected - you may need to water more frequently.';
      }
    }

    return baseAdvice;
  }

  String _generateNutrientAdvice(String? strain, Map<String, dynamic>? context) {
    String strainSpecific = '';
    if (strain?.toLowerCase().contains('kush') == true) {
      strainSpecific = '\n\nOG Kush strains are heavy feeders but sensitive to nutrient burn.';
    } else if (strain?.toLowerCase().contains('haze') == true) {
      strainSpecific = '\n\nHaze varieties prefer lighter feeding schedules.';
    }

    return '''
Nutrient Management Guidelines:
• Start with 50% recommended strength
• Gradually increase as plant shows demand
• Monitor for leaf discoloration
• Maintain pH between 6.0-6.5
• Flush with plain water every 2-3 weeks
• Use nutrients formulated for cannabis growth stage
$strainSpecific
''';
  }

  String _generateLightingAdvice() {
    return '''
Lighting Recommendations:
• Vegetative stage: 18-24 hours light per day
• Flowering stage: 12 hours light per day
• Maintain appropriate distance from canopy
• Ensure even light distribution
• Use appropriate spectrum for growth stage
• Replace bulbs according to manufacturer schedule
• Monitor for light burn (yellow/brown leaf tips)
''';
  }

  String _generateTemperatureAdvice(Map<String, dynamic>? context) {
    String currentStatus = '';
    if (context != null && context.containsKey('temperature')) {
      final temp = context['temperature'] as double? ?? 0.0;
      if (temp < 20) {
        currentStatus = '\n\n⚠️ Current temperature (${temp.toStringAsFixed(1)}°C) is too low.';
      } else if (temp > 30) {
        currentStatus = '\n\n⚠️ Current temperature (${temp.toStringAsFixed(1)}°C) is too high.';
      } else {
        currentStatus = '\n\n✅ Current temperature (${temp.toStringAsFixed(1)}°C) is within optimal range.';
      }
    }

    return '''
Temperature Management:
• Optimal range: 20-28°C during day
• Night temperatures can be 5-8°C cooler
• Use thermostats for automated control
• Ensure good air circulation
• Monitor for heat stress indicators
• Adjust ventilation as needed
$currentStatus
''';
  }

  String _generateHarvestAdvice(String? strain) {
    String strainSpecific = '';
    if (strain?.toLowerCase().contains('haze') == true) {
      strainSpecific = '\n\nPurple haze typically requires 10-11 weeks flowering.';
    } else if (strain?.toLowerCase().contains('northern lights') == true) {
      strainSpecific = '\n\nNorthern lights usually ready in 7-8 weeks flowering.';
    }

    return '''
Harvest Indicators:
• Pistils darken and curl inward
• Trichomes turn cloudy/amber
• Leaves begin to yellow naturally
• Aroma intensifies
• Check with magnification for trichome color
$strainSpecific

Harvest Tips:
• Flush plants 1-2 weeks before harvest
• Harvest in sections if trichomes develop unevenly
• Proper drying is crucial for quality
''';
  }

  String _generatePestDiseaseAdvice() {
    return '''
Pest and Disease Prevention:
• Maintain clean growing environment
• Ensure proper air circulation
• Monitor plants daily
• Quarantine new plants
• Use beneficial insects when possible
• Avoid overwatering
• Remove dead plant material promptly

Common Issues:
• Spider mites: Fine webbing, yellow spots
• Aphids: Sticky residue, curled leaves
• White flies: Flying insects, yellowing
• Powdery mildew: White powder on leaves
• Bud rot: Mold in dense buds
''';
  }

  String _generateGeneralAdvice(String? strain) {
    String strainInfo = '';
    if (strain != null) {
      strainInfo = '\n\nFor $strain: ${_getStrainSpecificRecommendations(strain).join(' ')}';
    }

    return '''
General Cannabis Cultivation Tips:
• Start with quality genetics
• Maintain consistent environment
• Monitor plants daily
• Keep detailed growing journal
• Start simple and advance gradually
• Learn to read your plants
• Don't overreact to minor issues
• Practice patience and consistency
$strainInfo

What specific aspect of cultivation would you like to know more about?
''';
  }

  // Utility methods
  double _calculateContrast(List<int> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance) / mean;
  }

  int _countEdges(img.Image image) {
    // Simplified edge detection - count significant color changes
    int edges = 0;
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final current = image.getPixel(x, y);
        final right = image.getPixel(x + 1, y);
        final bottom = image.getPixel(x, y + 1);

        if ((current.r - right.r).abs() > 30 || (current.g - right.g).abs() > 30 ||
            (current.b - right.b).abs() > 30 || (current.r - bottom.r).abs() > 30 ||
            (current.g - bottom.g).abs() > 30 || (current.b - bottom.b).abs() > 30) {
          edges++;
        }
      }
    }
    return edges;
  }

  double _calculateTextureScore(img.Image image) {
    // Simple texture calculation based on local variance
    double totalVariance = 0;
    int sampleCount = 0;

    for (int y = 1; y < image.height - 1; y += 10) {
      for (int x = 1; x < image.width - 1; x += 10) {
        final center = image.getPixel(x, y);
        final neighbors = [
          image.getPixel(x - 1, y), image.getPixel(x + 1, y),
          image.getPixel(x, y - 1), image.getPixel(x, y + 1)
        ];

        final avgR = neighbors.map((p) => p.r).reduce((a, b) => a + b) / neighbors.length;
        final avgG = neighbors.map((p) => p.g).reduce((a, b) => a + b) / neighbors.length;
        final avgB = neighbors.map((p) => p.b).reduce((a, b) => a + b) / neighbors.length;

        totalVariance += ((center.r - avgR).abs() + (center.g - avgG).abs() + (center.b - avgB).abs()) / 3;
        sampleCount++;
      }
    }

    return sampleCount > 0 ? (totalVariance / sampleCount) / 255 : 0.5;
  }

  int _detectSpots(img.Image image) {
    int spots = 0;
    for (int y = 1; y < image.height - 1; y += 5) {
      for (int x = 1; x < image.width - 1; x += 5) {
        final center = image.getPixel(x, y);
        final isDarkSpot = center.r < 100 && center.g < 100 && center.b < 100;

        if (isDarkSpot) {
          bool isIsolated = true;
          for (int dy = -2; dy <= 2 && isIsolated; dy++) {
            for (int dx = -2; dx <= 2 && isIsolated; dx++) {
              if (dx == 0 && dy == 0) continue;
              final neighbor = image.getPixel((x + dx).clamp(0, image.width - 1), (y + dy).clamp(0, image.height - 1));
              if (neighbor.r < 100 && neighbor.g < 100 && neighbor.b < 100) {
                isIsolated = false;
              }
            }
          }
          if (isIsolated) spots++;
        }
      }
    }
    return spots;
  }

  bool _detectLeafStructure(img.Image image) {
    // Simplified leaf structure detection
    int greenPixels = 0;
    int totalPixels = image.width * image.height ~/ 100; // Sample

    for (int i = 0; i < totalPixels; i++) {
      final x = _random.nextInt(image.width);
      final y = _random.nextInt(image.height);
      final pixel = image.getPixel(x, y);

      if (pixel.g > pixel.r && pixel.g > pixel.b && pixel.g > 50) {
        greenPixels++;
      }
    }

    return greenPixels / totalPixels > 0.3;
  }

  double _assessImageQuality(img.Image image) {
    // Simple image quality assessment
    final size = image.width * image.height;
    final minSize = 640 * 480;
    final maxSize = 1920 * 1080;

    if (size < minSize) return 0.3;
    if (size > maxSize) return 0.8;

    return (size - minSize) / (maxSize - minSize) * 0.5 + 0.5;
  }

  Map<String, dynamic> _getFallbackImageAnalysis() {
    return {
      'symptoms': ['Unable to analyze image - please ensure good lighting and focus'],
      'severity': 'Unknown',
      'color_analysis': {},
      'leaf_patterns': {},
      'image_quality': 0.0,
    };
  }
}