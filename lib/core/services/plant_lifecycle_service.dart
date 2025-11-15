import 'dart:async';
import 'dart:math';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import '../database/database_service.dart';
import '../models/plant_lifecycle.dart';
import '../models/strain_data.dart';

/// Comprehensive plant lifecycle management service
class PlantLifecycleService {
  static final PlantLifecycleService _instance = PlantLifecycleService._internal();
  factory PlantLifecycleService() => _instance;
  PlantLifecycleService._internal();

  final Logger _logger = Logger();
  late DatabaseService _databaseService;
  late StreamController<List<PlantLifecycle>> _plantsController;
  late StreamController<Map<String, dynamic>> _analyticsController;

  /// Initialize the plant lifecycle service
  Future<void> initialize() async {
    try {
      _databaseService = await DatabaseService.getInstance();
      _plantsController = StreamController<List<PlantLifecycle>>.broadcast();
      _analyticsController = StreamController<Map<String, dynamic>>.broadcast();

      _logger.i('Plant lifecycle service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize plant lifecycle service: $e');
      rethrow;
    }
  }

  /// Stream of all active plants
  Stream<List<PlantLifecycle>> get activePlantsStream => _plantsController.stream;

  /// Stream of analytics data
  Stream<Map<String, dynamic>> get analyticsStream => _analyticsController.stream;

  /// Create a new plant lifecycle record
  Future<PlantLifecycle> createPlant({
    required String userId,
    required String roomId,
    required String strainId,
    required String plantName,
    String? plantPhoto,
    DateTime? plantedDate,
    Map<String, dynamic>? environmentalPreferences,
  }) async {
    try {
      final now = DateTime.now();
      final plantId = _generateId();

      // Get strain information for growth template
      final strain = await _getStrainProfile(strainId);
      final expectedHarvestDate = _calculateExpectedHarvestDate(plantedDate ?? now, strain);

      final plant = PlantLifecycle(
        id: plantId,
        userId: userId,
        roomId: roomId,
        strainId: strainId,
        plantName: plantName,
        plantPhoto: plantPhoto,
        plantedDate: plantedDate ?? now,
        expectedHarvestDate: expectedHarvestDate,
        currentStage: GrowthStage.germination,
        healthStatus: PlantHealth.excellent,
        status: PlantStatus.active,
        environmentalPreferences: environmentalPreferences ?? _getDefaultEnvironmentalPreferences(strain),
        createdAt: now,
        updatedAt: now,
      );

      // Save to database
      await _databaseService.repositories.plantLifecycleRepository.create(plant);

      // Create initial growth phase record
      await _createGrowthPhaseRecord(plantId, GrowthStage.germination, plantedDate ?? now);

      // Update analytics
      _updateAnalytics();

      // Notify listeners
      _refreshPlantsStream();

      _logger.i('Created new plant: ${plant.name} with ID: $plantId');
      return plant;
    } catch (e) {
      _logger.e('Failed to create plant: $e');
      rethrow;
    }
  }

  /// Get plant by ID
  Future<PlantLifecycle?> getPlantById(String plantId) async {
    try {
      return await _databaseService.repositories.plantLifecycleRepository.getById(plantId);
    } catch (e) {
      _logger.e('Failed to get plant by ID: $e');
      return null;
    }
  }

  /// Get all plants for a user
  Future<List<PlantLifecycle>> getUserPlants(String userId, {PlantStatus? status}) async {
    try {
      return await _databaseService.repositories.plantLifecycleRepository.getUserPlants(
        userId,
        status: status,
      );
    } catch (e) {
      _logger.e('Failed to get user plants: $e');
      return [];
    }
  }

  /// Get plants in a specific room
  Future<List<PlantLifecycle>> getRoomPlants(String roomId, {bool activeOnly = true}) async {
    try {
      return await _databaseService.repositories.plantLifecycleRepository.getRoomPlants(
        roomId,
        activeOnly: activeOnly,
      );
    } catch (e) {
      _logger.e('Failed to get room plants: $e');
      return [];
    }
  }

  /// Update plant growth stage
  Future<void> updateGrowthStage(String plantId, GrowthStage newStage, {String? notes}) async {
    try {
      final plant = await getPlantById(plantId);
      if (plant == null) throw Exception('Plant not found');

      // End previous growth phase
      await _endGrowthPhase(plantId);

      // Start new growth phase
      await _createGrowthPhaseRecord(plantId, newStage, DateTime.now(), notes: notes);

      // Update plant
      final updatedPlant = plant.copyWith(
        currentStage: newStage,
        updatedAt: DateTime.now(),
      );

      await _databaseService.repositories.plantLifecycleRepository.update(updatedPlant);

      // Update expected harvest date if needed
      if (newStage == GrowthStage.vegetative) {
        final newExpectedDate = _calculateExpectedHarvestDate(plant.plantedDate, await _getStrainProfile(plant.strainId));
        await _databaseService.repositories.plantLifecycleRepository.update(
          updatedPlant.copyWith(expectedHarvestDate: newExpectedDate),
        );
      }

      _updateAnalytics();
      _refreshPlantsStream();

      _logger.i('Updated plant $plantId to stage: $newStage');
    } catch (e) {
      _logger.e('Failed to update growth stage: $e');
      rethrow;
    }
  }

  /// Record plant health check
  Future<void> recordHealthCheck({
    required String plantId,
    required PlantHealth healthStatus,
    required double healthScore,
    List<String> issues = const [],
    List<String> recommendations = const [],
    Map<String, dynamic>? sensorData,
    List<String> images = const [],
    String notes = '',
  }) async {
    try {
      final healthRecord = PlantHealthRecord(
        id: _generateId(),
        plantId: plantId,
        healthStatus: healthStatus,
        healthScore: healthScore,
        issues: issues,
        recommendations: recommendations,
        sensorData: sensorData ?? {},
        images: images,
        notes: notes,
        recordedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _databaseService.repositories.plantHealthRecordRepository.create(healthRecord);

      // Update plant health status
      final plant = await getPlantById(plantId);
      if (plant != null) {
        final updatedPlant = plant.copyWith(
          healthStatus: healthStatus,
          updatedAt: DateTime.now(),
        );
        await _databaseService.repositories.plantLifecycleRepository.update(updatedPlant);
        _refreshPlantsStream();
      }

      _updateAnalytics();
      _logger.i('Recorded health check for plant $plantId');
    } catch (e) {
      _logger.e('Failed to record health check: $e');
      rethrow;
    }
  }

  /// Add plant measurement
  Future<void> addMeasurement({
    required String plantId,
    required String measurementType,
    required double value,
    required String unit,
    Map<String, dynamic>? environmentalContext,
    String? notes,
    List<String> images = const [],
  }) async {
    try {
      final measurement = PlantMeasurement(
        id: _generateId(),
        plantId: plantId,
        measurementType: measurementType,
        value: value,
        unit: unit,
        environmentalContext: environmentalContext,
        notes: notes,
        images: images,
        measuredAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _databaseService.repositories.plantMeasurementRepository.create(measurement);
      _updateAnalytics();
      _logger.i('Added measurement for plant $plantId: $measurementType = $value $unit');
    } catch (e) {
      _logger.e('Failed to add measurement: $e');
      rethrow;
    }
  }

  /// Add timeline event
  Future<void> addTimelineEvent({
    required String plantId,
    required String eventType,
    required String title,
    required String description,
    Map<String, dynamic>? details,
    List<String> images = const [],
    DateTime? eventDate,
  }) async {
    try {
      final timelineEvent = PlantTimelineEvent(
        id: _generateId(),
        plantId: plantId,
        eventType: eventType,
        title: title,
        description: description,
        details: details,
        images: images,
        eventDate: eventDate ?? DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _databaseService.repositories.plantTimelineEventRepository.create(timelineEvent);
      _logger.i('Added timeline event for plant $plantId: $title');
    } catch (e) {
      _logger.e('Failed to add timeline event: $e');
      rethrow;
    }
  }

  /// Get plant timeline
  Future<List<PlantTimelineEvent>> getPlantTimeline(String plantId, {int limit = 50}) async {
    try {
      return await _databaseService.repositories.plantTimelineEventRepository.getPlantTimeline(
        plantId,
        limit: limit,
      );
    } catch (e) {
      _logger.e('Failed to get plant timeline: $e');
      return [];
    }
  }

  /// Get plant measurements
  Future<List<PlantMeasurement>> getPlantMeasurements(
    String plantId, {
    String? measurementType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _databaseService.repositories.plantMeasurementRepository.getPlantMeasurements(
        plantId,
        measurementType: measurementType,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _logger.e('Failed to get plant measurements: $e');
      return [];
    }
  }

  /// Get health history
  Future<List<PlantHealthRecord>> getHealthHistory(String plantId, {int limit = 100}) async {
    try {
      return await _databaseService.repositories.plantHealthRecordRepository.getPlantHealthHistory(
        plantId,
        limit: limit,
      );
    } catch (e) {
      _logger.e('Failed to get health history: $e');
      return [];
    }
  }

  /// Get growth analytics for a plant
  Future<Map<String, dynamic>> getGrowthAnalytics(String plantId) async {
    try {
      final plant = await getPlantById(plantId);
      if (plant == null) return {};

      final measurements = await getPlantMeasurements(plantId);
      final healthHistory = await getHealthHistory(plantId);
      final timelineEvents = await getPlantTimeline(plantId);

      // Analyze growth rate
      final heightMeasurements = measurements.where((m) => m.measurementType == 'height').toList();
      final growthRate = _calculateGrowthRate(heightMeasurements);

      // Health trend analysis
      final healthTrend = _analyzeHealthTrend(healthHistory);

      // Stage progression analysis
      final stageProgression = await _getStageProgression(plantId);

      return {
        'plant': plant.toJson(),
        'growth_rate': growthRate,
        'health_trend': healthTrend,
        'stage_progression': stageProgression,
        'total_measurements': measurements.length,
        'total_health_checks': healthHistory.length,
        'total_events': timelineEvents.length,
        'current_metrics': _getCurrentMetrics(measurements),
        'projected_yield': _calculateProjectedYield(plant, measurements),
        'growth_efficiency': _calculateGrowthEfficiency(plant, healthHistory),
      };
    } catch (e) {
      _logger.e('Failed to get growth analytics: $e');
      return {};
    }
  }

  /// Harvest plant
  Future<void> harvestPlant(String plantId, {String? notes, List<String>? harvestImages}) async {
    try {
      final plant = await getPlantById(plantId);
      if (plant == null) throw Exception('Plant not found');

      final updatedPlant = plant.copyWith(
        currentStage: GrowthStage.harvest,
        actualHarvestDate: DateTime.now(),
        status: PlantStatus.harvested,
        isActive: false,
        updatedAt: DateTime.now(),
      );

      await _databaseService.repositories.plantLifecycleRepository.update(updatedPlant);

      // Add harvest event to timeline
      await addTimelineEvent(
        plantId: plantId,
        eventType: 'harvest',
        title: 'Plant Harvested',
        description: 'Plant successfully harvested',
        notes: notes,
        images: harvestImages ?? [],
      );

      _refreshPlantsStream();
      _updateAnalytics();

      _logger.i('Harvested plant $plantId');
    } catch (e) {
      _logger.e('Failed to harvest plant: $e');
      rethrow;
    }
  }

  /// Archive plant
  Future<void> archivePlant(String plantId) async {
    try {
      final plant = await getPlantById(plantId);
      if (plant == null) throw Exception('Plant not found');

      final updatedPlant = plant.copyWith(
        status: PlantStatus.archived,
        isActive: false,
        updatedAt: DateTime.now(),
      );

      await _databaseService.repositories.plantLifecycleRepository.update(updatedPlant);
      _refreshPlantsStream();
      _updateAnalytics();

      _logger.i('Archived plant $plantId');
    } catch (e) {
      _logger.e('Failed to archive plant: $e');
      rethrow;
    }
  }

  /// Get room analytics
  Future<Map<String, dynamic>> getRoomAnalytics(String roomId) async {
    try {
      final plants = await getRoomPlants(roomId);
      final activePlants = plants.where((p) => p.isActive).toList();

      if (activePlants.isEmpty) {
        return {
          'total_plants': 0,
          'active_plants': 0,
          'growth_stages': <String, int>{},
          'health_distribution': <String, int>{},
          'average_age': 0.0,
          'plants_ready_for_harvest': 0,
        };
      }

      final stageDistribution = <String, int>{};
      final healthDistribution = <String, int>{};

      for (final plant in activePlants) {
        stageDistribution[plant.currentStage.name] = (stageDistribution[plant.currentStage.name] ?? 0) + 1;
        healthDistribution[plant.healthStatus.name] = (healthDistribution[plant.healthStatus.name] ?? 0) + 1;
      }

      final averageAge = activePlants.map((p) => p.ageInDays).reduce((a, b) => a + b) / activePlants.length;
      final readyForHarvest = activePlants.where((p) => p.currentStage == GrowthStage.flowering && (p.daysUntilHarvest != null && p.daysUntilHarvest! <= 7)).length;

      return {
        'total_plants': plants.length,
        'active_plants': activePlants.length,
        'growth_stages': stageDistribution,
        'health_distribution': healthDistribution,
        'average_age': averageAge,
        'plants_ready_for_harvest': readyForHarvest,
        'strains_represented': activePlants.map((p) => p.strainId).toSet().length,
        'next_harvest_dates': _getUpcomingHarvestDates(activePlants),
      };
    } catch (e) {
      _logger.e('Failed to get room analytics: $e');
      return {};
    }
  }

  // Private helper methods

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  Future<StrainProfile> _getStrainProfile(String strainId) async {
    try {
      final strain = await _databaseService.repositories.strainRepository.getById(strainId);
      return strain ?? _getDefaultStrainProfile();
    } catch (e) {
      _logger.w('Failed to get strain profile, using default: $e');
      return _getDefaultStrainProfile();
    }
  }

  StrainProfile _getDefaultStrainProfile() {
    return StrainProfile(
      id: 'default',
      name: 'Hybrid',
      type: 'Hybrid',
      characteristics: ['Balanced growth', 'Medium yield'],
      idealConditions: {
        'temperature': {'min': 20.0, 'max': 28.0},
        'humidity': {'min': 40.0, 'max': 60.0},
        'ph': {'min': 6.0, 'max': 7.0},
      },
      commonIssues: ['Nutrient burn', 'Overwatering'],
      recommendations: ['Monitor pH regularly', 'Maintain consistent watering'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  DateTime? _calculateExpectedHarvestDate(DateTime plantedDate, StrainProfile strain) {
    // Default growth periods based on strain type
    int totalDays;
    switch (strain.type.toLowerCase()) {
      case 'sativa':
        totalDays = 90; // 12-14 weeks
        break;
      case 'indica':
        totalDays = 63; // 8-10 weeks
        break;
      case 'hybrid':
        totalDays = 77; // 9-11 weeks
        break;
      default:
        totalDays = 77;
    }

    return plantedDate.add(Duration(days: totalDays));
  }

  Map<String, dynamic> _getDefaultEnvironmentalPreferences(StrainProfile strain) {
    return {
      'temperature': strain.idealConditions['temperature'] ?? {'min': 20.0, 'max': 28.0},
      'humidity': strain.idealConditions['humidity'] ?? {'min': 40.0, 'max': 60.0},
      'ph': strain.idealConditions['ph'] ?? {'min': 6.0, 'max': 7.0},
      'lighting': {
        'vegetative_hours': 18,
        'flowering_hours': 12,
        'intensity': 'medium',
      },
      'watering': {
        'frequency': 'moderate',
        'amount': 'medium',
      },
    };
  }

  Future<void> _createGrowthPhaseRecord(String plantId, GrowthStage stage, DateTime startDate, {String? notes}) async {
    final phaseRecord = GrowthPhaseRecord(
      id: _generateId(),
      plantId: plantId,
      stage: stage,
      startDate: startDate,
      notes: notes != null ? [notes] : [],
      createdAt: DateTime.now(),
    );

    await _databaseService.repositories.growthPhaseRecordRepository.create(phaseRecord);
  }

  Future<void> _endGrowthPhase(String plantId) async {
    final activePhase = await _databaseService.repositories.growthPhaseRecordRepository.getActivePhase(plantId);
    if (activePhase != null) {
      final updatedPhase = activePhase.copyWith(endDate: DateTime.now());
      await _databaseService.repositories.growthPhaseRecordRepository.update(updatedPhase);
    }
  }

  double _calculateGrowthRate(List<PlantMeasurement> heightMeasurements) {
    if (heightMeasurements.length < 2) return 0.0;

    final sorted = List<PlantMeasurement>.from(heightMeasurements)
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final first = sorted.first;
    final last = sorted.last;

    final daysDiff = last.measuredAt.difference(first.measuredAt).inDays;
    if (daysDiff == 0) return 0.0;

    final heightDiff = last.value - first.value;
    return heightDiff / daysDiff; // cm per day
  }

  Map<String, dynamic> _analyzeHealthTrend(List<PlantHealthRecord> healthHistory) {
    if (healthHistory.isEmpty) {
      return {'trend': 'unknown', 'improvement_rate': 0.0};
    }

    final sorted = List<PlantHealthRecord>.from(healthHistory)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    if (sorted.length < 2) {
      return {'trend': 'stable', 'improvement_rate': 0.0};
    }

    final recent = sorted.takeLast(5).map((r) => r.healthScore).reduce((a, b) => a + b) / sorted.takeLast(5).length;
    final older = sorted.take(5).map((r) => r.healthScore).reduce((a, b) => a + b) / 5;

    final improvementRate = ((recent - older) / older) * 100;
    String trend;
    if (improvementRate > 10) {
      trend = 'improving';
    } else if (improvementRate < -10) {
      trend = 'declining';
    } else {
      trend = 'stable';
    }

    return {
      'trend': trend,
      'improvement_rate': improvementRate,
      'current_score': sorted.last.healthScore,
      'average_score': sorted.map((r) => r.healthScore).reduce((a, b) => a + b) / sorted.length,
    };
  }

  Future<List<GrowthPhaseRecord>> _getStageProgression(String plantId) async {
    return await _databaseService.repositories.growthPhaseRecordRepository.getPlantPhases(plantId);
  }

  Map<String, dynamic> _getCurrentMetrics(List<PlantMeasurement> measurements) {
    if (measurements.isEmpty) return {};

    final latestByType = <String, PlantMeasurement>{};
    for (final measurement in measurements) {
      if (!latestByType.containsKey(measurement.measurementType) ||
          measurement.measuredAt.isAfter(latestByType[measurement.measurementType]!.measuredAt)) {
        latestByType[measurement.measurementType] = measurement;
      }
    }

    return latestByType.map((key, value) => MapEntry(key, value.toJson()));
  }

  Map<String, dynamic> _calculateProjectedYield(PlantLifecycle plant, List<PlantMeasurement> measurements) {
    // Simplified yield calculation based on growth metrics
    final heightMeasurements = measurements.where((m) => m.measurementType == 'height').toList();
    final finalHeight = heightMeasurements.isNotEmpty ? heightMeasurements.last.value : 0.0;

    // Base yield calculation (this would be more sophisticated in production)
    double baseYield = 50.0; // grams
    double heightMultiplier = finalHeight / 100.0; // per 100cm
    double strainMultiplier = 1.0; // Would be based on strain characteristics
    double healthMultiplier = plant.healthScore;

    final projectedYield = baseYield * heightMultiplier * strainMultiplier * healthMultiplier;

    return {
      'projected_yield_grams': projectedYield,
      'confidence_level': 'medium', // Based on data completeness
      'factors': {
        'final_height': finalHeight,
        'health_score': plant.healthScore,
        'growth_stage': plant.currentStage.name,
      },
    };
  }

  double _calculateGrowthEfficiency(PlantLifecycle plant, List<PlantHealthRecord> healthHistory) {
    if (healthHistory.isEmpty) return 0.0;

    final avgHealthScore = healthHistory.map((r) => r.healthScore).reduce((a, b) => a + b) / healthHistory.length;
    final expectedAge = _getExpectedAgeForStage(plant.currentStage);
    final actualAge = plant.ageInDays;
    final ageEfficiency = expectedAge > 0 ? (expectedAge / actualAge).clamp(0.0, 1.0) : 1.0;

    return (avgHealthScore + ageEfficiency) / 2;
  }

  int _getExpectedAgeForStage(GrowthStage stage) {
    switch (stage) {
      case GrowthStage.germination:
        return 7;
      case GrowthStage.seedling:
        return 21;
      case GrowthStage.vegetative:
        return 77;
      case GrowthStage.flowering:
        return 140;
      case GrowthStage.harvest:
        return 143;
      case GrowthStage.curing:
        return 157;
      case GrowthStage.completed:
        return 157;
    }
  }

  List<Map<String, dynamic>> _getUpcomingHarvestDates(List<PlantLifecycle> plants) {
    final floweringPlants = plants.where((p) => p.currentStage == GrowthStage.flowering);
    return floweringPlants
        .where((p) => p.expectedHarvestDate != null)
        .map((p) => {
          'plant_id': p.id,
          'plant_name': p.plantName,
          'expected_harvest_date': p.expectedHarvestDate!.toIso8601String(),
          'days_until_harvest': p.daysUntilHarvest,
        })
        .toList()
      ..sort((a, b) => a['days_until_harvest'].compareTo(b['days_until_harvest']));
  }

  void _refreshPlantsStream() async {
    try {
      final plants = await getUserPlants('current_user'); // Would get actual user ID
      _plantsController.add(plants);
    } catch (e) {
      _logger.e('Failed to refresh plants stream: $e');
    }
  }

  void _updateAnalytics() async {
    try {
      final analytics = {
        'timestamp': DateTime.now().toIso8601String(),
        'total_plants': await _getTotalPlantCount(),
        'active_plants': await _getActivePlantCount(),
        'plants_in_flowering': await _getPlantsInStage(GrowthStage.flowering),
        'plants_ready_for_harvest': await _getPlantsReadyForHarvest(),
        'average_health_score': await _getAverageHealthScore(),
      };
      _analyticsController.add(analytics);
    } catch (e) {
      _logger.e('Failed to update analytics: $e');
    }
  }

  Future<int> _getTotalPlantCount() async {
    // Implementation would depend on database structure
    return 0;
  }

  Future<int> _getActivePlantCount() async {
    return 0;
  }

  Future<int> _getPlantsInStage(GrowthStage stage) async {
    return 0;
  }

  Future<int> _getPlantsReadyForHarvest() async {
    return 0;
  }

  Future<double> _getAverageHealthScore() async {
    return 0.0;
  }

  /// Dispose resources
  void dispose() {
    _plantsController.close();
    _analyticsController.close();
  }
}