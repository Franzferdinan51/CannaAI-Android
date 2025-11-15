// Specialized tools service for CannaAI Android
// Pest ID, Harvest Tracker, Inventory Manager, Nutrient Calculator, etc.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/comprehensive/data_models.dart';
import 'comprehensive_api_service.dart';
import 'comprehensive_ai_assistant_service.dart';

class SpecializedToolsService {
  static final SpecializedToolsService _instance = SpecializedToolsService._internal();
  factory SpecializedToolsService() => _instance;
  SpecializedToolsService._internal();

  final Logger _logger = Logger();
  final APIService _apiService = APIService();
  final AIAssistantService _aiService = AIAssistantService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isInitialized = false;

  // Data storage
  final Map<String, dynamic> _pestDatabase = {};
  final Map<String, dynamic> _nutrientDatabase = {};
  final Map<String, dynamic> _harvestTemplates = {};

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadPestDatabase();
      await _loadNutrientDatabase();
      await _loadHarvestTemplates();
      _isInitialized = true;
      _logger.i('Specialized Tools Service initialized');
    } catch (e) {
      _logger.e('Failed to initialize Specialized Tools Service: $e');
    }
  }

  Future<void> _loadPestDatabase() async {
    try {
      // Load pest database from assets or API
      final pests = await _apiService.getPestDatabase();
      if (pests.isNotEmpty) {
        _pestDatabase = Map.fromEntries(
          pests.map((pest) => MapEntry(pest['id'], pest)),
        );
      }
    } catch (e) {
      _logger.e('Failed to load pest database: $e');
      // Load local fallback database
      _loadLocalPestDatabase();
    }
  }

  Future<void> _loadLocalPestDatabase() async {
    _pestDatabase = {
      'spider_mites': {
        'id': 'spider_mites',
        'name': 'Spider Mites',
        'type': 'pest',
        'category': 'arachnid',
        'description': 'Tiny arachnids that feed on plant sap',
        'symptoms': [
          'Yellow spots on leaves',
          'Fine webbing on plant',
          'Tiny moving dots on underside of leaves',
          'Stunted growth',
        ],
        'solutions': [
          'Increase humidity',
          'Use neem oil spray',
          'Introduce predatory mites',
          'Isolate affected plants',
        ],
        'prevention': [
          'Maintain proper airflow',
          'Regular inspection',
          'Quarantine new plants',
          'Keep plants healthy',
        ],
        'severity': 'medium',
        'lifecycle': '5-7 days',
        'optimalConditions': {
          'temperature': '20-30°C',
          'humidity': '40-60%',
        },
        'images': [],
      },
      'aphids': {
        'id': 'aphids',
        'name': 'Aphids',
        'type': 'pest',
        'category': 'insect',
        'description': 'Small sap-sucking insects that reproduce rapidly',
        'symptoms': [
          'Curled or yellowed leaves',
          'Sticky honeydew on leaves',
          'Black sooty mold',
          'Ant presence',
          'Deformed growth',
        ],
        'solutions': [
          'Insecticidal soap',
          'Neem oil spray',
          'Ladybug introduction',
          'Water jet spray',
          'Pruning affected areas',
        ],
        'prevention': [
          'Regular monitoring',
          'Beneficial insects',
          'Companion planting',
          'Healthy soil',
        ],
        'severity': 'low',
        'lifecycle': '7-10 days',
        'optimalConditions': {
          'temperature': '15-25°C',
          'humidity': '60-80%',
        },
        'images': [],
      },
      'powdery_mildew': {
        'id': 'powdery_mildew',
        'name': 'Powdery Mildew',
        'type': 'disease',
        'category': 'fungal',
        'description': 'Fungal disease affecting leaves and stems',
        'symptoms': [
          'White powdery spots on leaves',
          'Yellowing and browning',
          'Leaf curling',
          'Reduced photosynthesis',
          'Stunted growth',
        ],
        'solutions': [
          'Increase air circulation',
          'Sulfur-based fungicides',
          'Potassium bicarbonate spray',
          'Reduce humidity',
          'Remove affected leaves',
        ],
        'prevention': [
          'Proper spacing',
          'Good ventilation',
          'Resistant varieties',
          'Regular monitoring',
        ],
        'severity': 'medium',
        'lifecycle': 'continuous',
        'optimalConditions': {
          'temperature': '15-25°C',
          'humidity': '40-60%',
        },
        'images': [],
      },
      // Add more pests/diseases...
    };
  }

  Future<void> _loadNutrientDatabase() async {
    _nutrientDatabase = {
      'nitrogen': {
        'id': 'nitrogen',
        'name': 'Nitrogen (N)',
        'symbol': 'N',
        'role': 'Growth and leaf development',
        'deficiencySymptoms': [
          'Yellowing of lower leaves',
          'Stunted growth',
          'Pale green color',
          'Reduced flowering',
          'Small leaf size',
        ],
        'excessSymptoms': [
          'Dark green leaves',
          'Weak stems',
          'Delayed flowering',
          'Leaf burn',
          'Reduced bud development',
        ],
        'optimalRange': {
          'vegetative': '150-200 ppm',
          'flowering': '50-100 ppm',
        },
        'sources': [
          'High nitrogen fertilizers',
          'Organic compost',
          'Fish emulsion',
          'Blood meal',
        ],
      },
      'phosphorus': {
        'id': 'phosphorus',
        'name': 'Phosphorus (P)',
        'symbol': 'P',
        'role': 'Root development and flowering',
        'deficiencySymptoms': [
          'Purple stems',
          'Slow growth',
          'Dark green leaves',
          'Poor root development',
          'Late flowering',
        ],
        'excessSymptoms': [
          'Iron deficiency',
          'Zinc deficiency',
          'Calcium deficiency',
          'Micronutrient lockout',
        ],
        'optimalRange': {
          'vegetative': '30-50 ppm',
          'flowering': '50-100 ppm',
        },
        'sources': [
          'Bone meal',
          'Rock phosphate',
          'Guano',
          'Superphosphate',
        ],
      },
      'potassium': {
        'id': 'potassium',
        'name': 'Potassium (K)',
        'symbol': 'K',
        'role': 'Overall plant health and disease resistance',
        'deficiencySymptoms': [
          'Yellow/brown leaf edges',
          'Weak stems',
          'Poor disease resistance',
          'Slow growth',
          'Low brix in fruits',
        ],
        'excessSymptoms': [
          'Magnesium deficiency',
          'Calcium deficiency',
          'Iron deficiency',
        ],
        'optimalRange': {
          'vegetative': '100-150 ppm',
          'flowering': '150-300 ppm',
        },
        'sources': [
          'Kelp meal',
          'Wood ash',
          'Greensand',
          'Sulfate of potash',
        ],
      },
      // Add more nutrients...
    };
  }

  Future<void> _loadHarvestTemplates() async {
    _harvestTemplates = {
      'indica_indoor': {
        'id': 'indica_indoor',
        'name': 'Indica Indoor Harvest Template',
        'type': PlantType.indica,
        'environment': 'indoor',
        'floweringTime': 56-70,
        'expectedYield': '400-600 g/m²',
        'curingTime': '7-14 days',
        'steps': [
          'Stop fertilization 1-2 weeks before harvest',
          'Flush plants with pH 6.0 water for 7-10 days',
          'Monitor trichomes for optimal maturity',
          'Harvest when 70-80% of trichomes are cloudy',
          'Cut plants at base, hang to dry',
          'Dry in 60-70°F, 50-60% humidity',
          'Trim buds and cure in jars',
        ],
      },
      'sativa_outdoor': {
        'id': 'sativa_outdoor',
        'name': 'Sativa Outdoor Harvest Template',
        'type': PlantType.sativa,
        'environment': 'outdoor',
        'floweringTime': '63-84',
        'expectedYield': '200-400 g/m²',
        'curingTime': '10-21 days',
        'steps': [
          'Monitor weather forecast',
          'Stop fertilization 2-3 weeks before harvest',
          'Protect from rain during final weeks',
          'Harvest when plants show peak maturity',
          'Dry in well-ventilated area',
          'Cure for extended period due to outdoor conditions',
        ],
      },
      // Add more templates...
    };
  }

  // ==================== PEST & DISEASE IDENTIFICATION ====================

  Future<List<PestIdentificationResult>> identifyPestDisease(File imageFile, {String? roomId}) async {
    try {
      _logger.i('Starting pest/disease identification');

      // Use AI service for image analysis
      final analysisResult = await _aiService.analyzeImage(
        imageFile,
        type: AnalysisType.pest,
      );

      final results = <PestIdentificationResult>[];

      if (analysisResult != null) {
        // Process AI analysis results
        for (final issue in analysisResult.issues) {
          final pestData = _findPestData(issue.type);
          if (pestData != null) {
            results.add(_createPestResult(pestData, analysisResult.confidence));
          }
        }
      }

      // Fallback to local database matching
      if (results.isEmpty) {
        final localMatches = _matchWithLocalDatabase(imageFile);
        results.addAll(localMatches);
      }

      return results;
    } catch (e) {
      _logger.e('Failed to identify pest/disease: $e');
      return [];
    }
  }

  Map<String, dynamic>? _findPestData(String pestType) {
    for (final pestData in _pestDatabase.values) {
      if (pestData['name'].toString().toLowerCase().contains(pestType.toLowerCase()) ||
          pestData['type'].toString().toLowerCase().contains(pestType.toLowerCase())) {
        return pestData;
      }
    }
    return null;
  }

  PestIdentificationResult _createPestResult(Map<String, dynamic> pestData, double confidence) {
    return PestIdentificationResult(
      id: pestData['id'],
      name: pestData['name'],
      type: pestData['type'],
      category: pestData['category'],
      description: pestData['description'],
      symptoms: List<String>.from(pestData['symptoms'] ?? []),
      solutions: List<String>.from(pestData['solutions'] ?? []),
      prevention: List<String>.from(pestData['prevention'] ?? []),
      severity: pestData['severity'],
      lifecycle: pestData['lifecycle'],
      confidence: confidence,
      optimalConditions: Map<String, dynamic>.from(pestData['optimalConditions'] ?? {}),
      timestamp: DateTime.now(),
    );
  }

  Future<List<PestIdentificationResult>> _matchWithLocalDatabase(File imageFile) async {
    // TODO: Implement local image matching
    // This would use pattern recognition or color analysis
    return [];
  }

  Future<List<PestIdentificationResult>> searchPestDatabase(String query) async {
    try {
      final results = <PestIdentificationResult>[];
      final lowerQuery = query.toLowerCase();

      for (final pestData in _pestDatabase.values) {
        final name = pestData['name'].toString().toLowerCase();
        final description = pestData['description'].toString().toLowerCase();
        final symptoms = List<String>.from(pestData['symptoms'] ?? [])
            .map((s) => s.toLowerCase());

        if (name.contains(lowerQuery) ||
            description.contains(lowerQuery) ||
            symptoms.any((s) => s.contains(lowerQuery))) {
          results.add(_createPestResult(pestData, 1.0));
        }
      }

      return results;
    } catch (e) {
      _logger.e('Failed to search pest database: $e');
      return [];
    }
  }

  Future<List<String>> getTreatmentRecommendations(String pestId) async {
    try {
      final pestData = _pestDatabase[pestId];
      if (pestData != null) {
        return List<String>.from(pestData['solutions'] ?? []);
      }
      return [];
    } catch (e) {
      _logger.e('Failed to get treatment recommendations: $e');
      return [];
    }
  }

  // ==================== NUTRIENT CALCULATOR ====================

  Future<NutrientCalculationResult> calculateNutrients({
    required String strainId,
    required int daysInVegetative,
    required int daysInFlowering,
    required int plantCount,
    required double growArea,
    String medium = 'soil',
  }) async {
    try {
      // Get strain-specific requirements
      final strainRequirements = await _getStrainNutrientRequirements(strainId);

      // Calculate base requirements
      final vegetativeRequirements = _calculatePhaseRequirements(
        daysInVegetative,
        growArea,
        medium,
        strainRequirements,
      );

      final floweringRequirements = _calculatePhaseRequirements(
        daysInFlowering,
        growArea,
        medium,
        strainRequirements,
      );

      // Combine requirements
      final totalRequirements = NutrientCalculationResult(
        nitrogen: vegetativeRequirements.nitrogen + floweringRequirements.nitrogen,
        phosphorus: vegetativeRequirements.phosphorus + floweringRequirements.phosphorus,
        potassium: vegetativeRequirements.potassium + floweringRequirements.potassium,
        calcium: vegetativeRequirements.calcium + floweringRequirements.calcium,
        magnesium: vegetativeRequirements.magnesium + floweringRequirements.magnesium,
        sulfur: vegetativeRequirements.sulfur + floweringRequirements.sulfur,
        micro: vegetativeRequirements.micro + floweringRequirements.micro,
        vegetative: vegetativeRequirements,
        flowering: floweringRequirements,
        total: NutrientPhaseRequirements(
          nitrogen: vegetativeRequirements.nitrogen + floweringRequirements.nitrogen,
          phosphorus: vegetativeRequirements.phosphorus + floweringRequirements.phosphorus,
          potassium: vegetativeRequirements.potassium + floweringRequirements.kpotassium,
          calcium: vegetativeRequirements.calcium + floweringRequirements.calcium,
          magnesium: vegetativeRequirements.magnesium + floweringRequirements.magnesium,
          sulfur: vegetativeRequirements.sulfur + floweringRequirements.sulfur,
          micro: vegetativeRequirements.micro + floweringRequirements.micro,
        ),
      );

      // Adjust for medium type
      return _adjustForMedium(totalRequirements, medium);
    } catch (e) {
      _logger.e('Failed to calculate nutrients: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> _getStrainNutrientRequirements(String strainId) async {
    // Get strain-specific nutrient requirements from API or database
    try {
      final strain = await _apiService.getStrainById(strainId);
      if (strain != null) {
        return strain.characteristics.toJson();
      }
    } catch (e) {
      _logger.e('Failed to get strain nutrient requirements: $e');
    }

    // Return default requirements
    return {
      'nitrogenDemand': 'medium',
      'phosphorusDemand': 'medium',
      'potassiumDemand': 'high',
    };
  }

  NutrientPhaseRequirements _calculatePhaseRequirements(
    int days,
    double growArea,
    String medium,
    Map<String, dynamic> strainRequirements,
  ) {
    final nitrogenPPM = 150.0; // Base ppm
    final phosphorusPPM = 50.0;
    final potassiumPPM = 100.0;

    return NutrientPhaseRequirements(
      nitrogen: (nitrogenPPM * growArea * days / 7) * 0.1, // Convert to grams
      phosphorus: (phosphorusPPM * growArea * days / 7) * 0.1,
      potassium: (potassiumPPM * growArea * days / 7) * 0.1,
      calcium: 50.0 * days / 7, // grams
      magnesium: 25.0 * days / 7, // grams
      sulfur: 20.0 * days / 7, // grams
      micro: 10.0 * days / 7, // grams
    );
  }

  NutrientCalculationResult _adjustForMedium(NutrientCalculationResult requirements, String medium) {
    // Adjust based on medium efficiency
    double efficiencyFactor = 1.0;

    switch (medium.toLowerCase()) {
      case 'soil':
        efficiencyFactor = 1.0;
        break;
      case 'hydroponic':
        efficiencyFactor = 0.8; // Higher efficiency, lower amounts needed
        break;
      case 'coco':
        efficiencyFactor = 0.9;
        break;
      case 'aeroponic':
        efficiencyFactor = 0.7;
        break;
    }

    return NutrientCalculationResult(
      nitrogen: requirements.nitrogen * efficiencyFactor,
      phosphorus: requirements.phosphorus * efficiencyFactor,
      potassium: requirements.kpotassium * efficiencyFactor,
      calcium: requirements.calcium * efficiencyFactor,
      magnesium: requirements.magnesium * efficiencyFactor,
      sulfur: requirements.sulfur * efficiencyFactor,
      micro: requirements.micro * efficiencyFactor,
      vegetative: requirements.vegetative,
      flowering: requirements.flowering,
      total: requirements.total,
    );
  }

  Future<List<NutrientSchedule>> createNutrientSchedule(NutrientCalculationResult requirements) async {
    try {
      final schedules = <NutrientSchedule>[];

      // Create weekly schedule
      final weekCount = 4; // Approximate weeks for typical grow

      for (int week = 0; week < weekCount; week++) {
        final weeklyNutrients = NutrientPhaseRequirements(
          nitrogen: requirements.vegetative.nitrogen / weekCount,
          phosphorus: requirements.vegetative.phosphorus / weekCount,
          potassium: requirements.vegetative.kpotassium / weekCount,
          calcium: requirements.vegetative.calcium / weekCount,
          magnesium: requirements.vegetative.magnesium / weekCount,
          sulfur: requirements.vegetative.sulfur / weekCount,
          micro: requirements.vegetative.micro / weekCount,
        );

        schedules.add(NutrientSchedule(
          week: week + 1,
          nutrients: weeklyNutrients,
          applicationMethod: 'hydroponic_drip',
          frequency: 'weekly',
          notes: 'Week ${week + 1} of vegetative stage',
        ));
      }

      return schedules;
    } catch (e) {
      _logger.e('Failed to create nutrient schedule: $e');
      return [];
    }
  }

  // ==================== HARVEST TRACKER ====================

  Future<HarvestRecord> recordHarvest({
    required String plantId,
    required String roomId,
    required double wetWeight,
    String? dryWeight,
    Map<String, dynamic>? testingResults,
    List<File>? images,
    String notes = '',
  }) async {
    try {
      // Create harvest record
      final record = HarvestRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        plantId: plantId,
        roomId: roomId,
        wetWeight: wetWeight,
        dryWeight: dryWeight ?? wetWeight * 0.25, // Estimate 25% dry to wet ratio
        thcContent: testingResults?['thcContent'],
        cbdContent: testingResults?['cbdContent'],
        quality: _assessQuality(wetWeight, dryWeight, testingResults),
        images: images?.map((file) => file.path).toList() ?? [],
        notes: notes,
        harvestedAt: DateTime.now(),
        testingResults: testingResults,
      );

      // Save to API
      final apiRecord = await _apiService.createHarvestRecord(record);

      // Update plant status
      if (apiRecord != null) {
        // Update plant to harvested status in local database
        await _updatePlantHarvested(plantId);
      }

      return record;
    } catch (e) {
      _logger.e('Failed to record harvest: $e');
      throw e;
    }
  }

  QualityGrade _assessQuality(double wetWeight, double? dryWeight, Map<String, dynamic>? testingResults) {
    final dryToWetRatio = dryWeight != null ? dryWeight / wetWeight : 0.25;

    if (testingResults != null) {
      final thcContent = testingResults['thcContent'] as double? ?? 0.0;
      final cbdContent = testingResults['cbdContent'] as double? ?? 0.0;

      if (thcContent > 25) {
        return QualityGrade.premium;
      } else if (thcContent > 20) {
        return QualityGrade.a;
      } else if (thcContent > 15) {
        return QualityGrade.b;
      } else {
        return QualityGrade.c;
      }
    }

    // Default assessment based on ratio
    if (dryToWetRatio > 0.25) {
      return QualityGrade.a;
    } else if (dryToWetRatio > 0.20) {
      return QualityGrade.b;
    } else {
      return QualityGrade.c;
    }
  }

  Future<void> _updatePlantHarvested(String plantId) async {
    try {
      // TODO: Update plant status in local database
      _logger.i('Marking plant as harvested: $plantId');
    } catch (e) {
      _logger.e('Failed to update plant harvested status: $e');
    }
  }

  Future<List<HarvestRecord>> getHarvestHistory({String? roomId, DateTime? startDate, DateTime? endDate}) async {
    try {
      return await _apiService.getHarvestRecords(roomId: roomId);
    } catch (e) {
      _logger.e('Failed to get harvest history: $e');
      return [];
    }
  }

  Future<HarvestAnalytics> getHarvestAnalytics({String? roomId}) async {
    try {
      final records = await getHarvestHistory(roomId: roomId);

      if (records.isEmpty) {
        return HarvestAnalytics.empty();
      }

      final totalWetWeight = records.fold(0.0, (sum, record) => sum + record.wetWeight);
      final totalDryWeight = records.fold(0.0, (sum, record) => sum + record.dryWeight);
      final averageYield = records.isEmpty ? 0.0 : totalDryWeight / records.length;
      final totalTHC = records
          .where((r) => r.thcContent != null)
          .fold(0.0, (sum, r) => sum + r.thcContent!);

      return HarvestAnalytics(
        totalHarvests: records.length,
        totalWetWeight: totalWetWeight,
        totalDryWeight: totalDryWeight,
        averageYield: averageYield,
        totalTHC: totalTHC,
        averageTHC: totalTHC / records.length,
        dryToWetRatio: totalWetWeight > 0 ? totalDryWeight / totalWetWeight : 0.0,
        harvestDates: records.map((r) => r.harvestedAt).toList(),
        qualityDistribution: _calculateQualityDistribution(records),
      );
    } catch (e) {
      _logger.e('Failed to get harvest analytics: $e');
      return HarvestAnalytics.empty();
    }
  }

  Map<QualityGrade, int> _calculateQualityDistribution(List<HarvestRecord> records) {
    final distribution = <QualityGrade, int>{};

    for (final record in records) {
      final count = distribution[record.quality] ?? 0;
      distribution[record.quality] = count + 1;
    }

    return distribution;
  }

  // ==================== INVENTORY MANAGEMENT ====================

  Future<InventoryItem?> createInventoryItem({
    required String name,
    required String category,
    required String supplier,
    required double currentStock,
    required String unit,
    required double unitPrice,
    double minStockLevel = 0.0,
    double maxStockLevel = 1000.0,
    String? sku,
    DateTime? expiryDate,
    Map<String, dynamic>? properties,
  }) async {
    try {
      final item = InventoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        category: category,
        supplier: supplier,
        currentStock: currentStock,
        unit: unit,
        minStockLevel: minStockLevel,
        maxStockLevel: maxStockLevel,
        unitPrice: unitPrice,
        sku: sku,
        expiryDate: expiryDate,
        properties: properties,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to API
      final apiItem = await _apiService.createInventoryItem(item);

      return apiItem ?? item;
    } catch (e) {
      _logger.e('Failed to create inventory item: $e');
      return null;
    }
  }

  Future<List<InventoryItem>> getInventoryItems() async {
    try {
      return await _apiService.getInventoryItems();
    } catch (e) {
      _logger.e('Failed to get inventory items: $e');
      return [];
    }
  }

  Future<List<InventoryItem>> getLowStockItems() async {
    try {
      return await _apiService.getLowStockItems();
    } catch (e) {
      _logger.e('Failed to get low stock items: $e');
      return [];
    }
  }

  Future<void> updateInventoryStock(String itemId, double newStock) async {
    try {
      final items = await getInventoryItems();
      final item = items.firstWhere((item) => item.id == itemId);

      final updatedItem = item.copyWith(
        currentStock: newStock,
        updatedAt: DateTime.now(),
      );

      await _apiService.updateInventoryItem(updatedItem);
    } catch (e) {
      _logger.e('Failed to update inventory stock: $e');
    }
  }

  Future<InventoryAnalytics> getInventoryAnalytics() async {
    try {
      final items = await getInventoryItems();

      if (items.isEmpty) {
        return InventoryAnalytics.empty();
      }

      final totalValue = items.fold(0.0, (sum, item) => sum + (item.currentStock * item.unitPrice));
      final totalItems = items.fold(0, (sum, item) => sum + item.currentStock);

      final lowStockItems = items.where((item) => item.isLowStock).length;
      final criticalStockItems = items
          .where((item) => item.stockStatus <= 0.1)
          .length;

      return InventoryAnalytics(
        totalItems: totalItems,
        totalValue: totalValue,
        lowStockItems: lowStockItems,
        criticalStockItems: criticalStockItems,
        categoryBreakdown: _calculateCategoryBreakdown(items),
        supplierBreakdown: _calculateSupplierBreakdown(items),
        mostValuableItems: _getMostValuableItems(items),
        expiringItems: _getExpiringItems(items),
      );
    } catch (e) {
      _logger.e('Failed to get inventory analytics: $e');
      return InventoryAnalytics.empty();
    }
  }

  Map<String, double> _calculateCategoryBreakdown(List<InventoryItem> items) {
    final breakdown = <String, double>{};

    for (final item in items) {
      final category = item.category;
      final value = item.currentStock * item.unitPrice;
      breakdown[category] = (breakdown[category] ?? 0.0) + value;
    }

    return breakdown;
  }

  Map<String, double> _calculateSupplierBreakdown(List<InventoryItem> items) {
    final breakdown = <String, double>{};

    for (final item in items) {
      final supplier = item.supplier;
      final value = item.currentStock * item.unitPrice;
      breakdown[supplier] = (breakdown[supplier] ?? 0.0) + value;
    }

    return breakdown;
  }

  List<InventoryItem> _getMostValuableItems(List<InventoryItem> items) {
      return items
        .where((item) => item.currentStock > 0)
        .toList()
        ..sort((a, b) => (b.currentStock * b.unitPrice).compareTo(a.currentStock * a.unitPrice))
        ..take(10);
  }

  List<InventoryItem> _getExpiringItems(List<InventoryItem> items) {
      final now = DateTime.now();
      return items
        .where((item) =>
          item.expiryDate != null &&
          item.expiryDate!.isBefore(now.add(const Duration(days: 30)))
        .toList()
        ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!))
        ..take(10);
  }

  // ==================== CLEANUP ====================

  void dispose() {
    _pestDatabase.clear();
    _nutrientDatabase.clear();
    _harvestTemplates.clear();
    _isInitialized = false;
  }
}

// ==================== SUPPORTING CLASSES ====================

class PestIdentificationResult {
  final String id;
  final String name;
  final String type;
  final String category;
  final String description;
  final List<String> symptoms;
  final List<String> solutions;
  final List<String> prevention;
  final String severity;
  final String lifecycle;
  final double confidence;
  final Map<String, dynamic> optimalConditions;
  final DateTime timestamp;

  PestIdentificationResult({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.description,
    required this.symptoms,
    required this.solutions,
    required this.prevention,
    required this.severity,
    required this.lifecycle,
    required this.confidence,
    required this.optimalConditions,
    required this.timestamp,
  });
}

class NutrientCalculationResult {
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double calcium;
  final double magnesium;
  final double sulfur;
  final double micro;
  final NutrientPhaseRequirements vegetative;
  final NutrientPhaseRequirements flowering;
  final NutrientPhaseRequirements total;

  NutrientCalculationResult({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.calcium,
    required this.magnesium,
    required this.sulfur,
    required this.micro,
    required this.vegetative,
    required this.flowering,
    required this.total,
  });
}

class NutrientPhaseRequirements {
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double calcium;
  final double magnesium;
  final double sulfur;
  final double micro;

  NutrientPhaseRequirements({
    required this.nitrogen,
    required this.phosphorus,
    required this.kpotassium,
    required this.calcium,
    required this.magnesium,
    required this.sulfur,
    required this.micro,
  });
}

class NutrientSchedule {
  final int week;
  final NutrientPhaseRequirements nutrients;
  final String applicationMethod;
  final String frequency;
  final String notes;

  NutrientSchedule({
    required this.week,
    required this.nutrients,
    required this.applicationMethod,
    this.frequency = 'weekly',
    this.notes = '',
  });
}

class HarvestAnalytics {
  final int totalHarvests;
  final double totalWetWeight;
  final double totalDryWeight;
  final double averageYield;
  final double totalTHC;
  final double averageTHC;
  final double dryToWetRatio;
  final List<DateTime> harvestDates;
  final Map<QualityGrade, int> qualityDistribution;

  HarvestAnalytics({
    required this.totalHarvests,
    required this.totalWetWeight,
    required this.totalDryWeight,
    required this.averageYield,
    required this.totalTHC,
    required this.averageTHC,
    required this.dryToWetRatio,
    required this.harvestDates,
    required this.qualityDistribution,
  });

  HarvestAnalytics.empty()
      : totalHarvests = 0,
        totalWetWeight = 0.0,
        totalDryWeight = 0.0,
        averageYield = 0.0,
        totalTHC = 0.0,
        averageTHC = 0.0,
        dryToWetRatio = 0.0,
        harvestDates = [],
        qualityDistribution = {};
}

class InventoryAnalytics {
  final int totalItems;
  final double totalValue;
  final int lowStockItems;
  final int criticalStockItems;
  final Map<String, double> categoryBreakdown;
  final Map<String, double> supplierBreakdown;
  final List<InventoryItem> mostValuableItems;
  final List<InventoryItem> expiringItems;

  InventoryAnalytics.empty()
      : totalItems = 0,
        totalValue = 0.0,
        lowStockItems = 0,
        criticalStockItems = 0,
        categoryBreakdown: {},
        supplierBreakdown: {},
        mostValuableItems: [],
        expiringItems: [];
}